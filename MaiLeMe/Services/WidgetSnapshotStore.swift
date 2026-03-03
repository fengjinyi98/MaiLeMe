//
//  WidgetSnapshotStore.swift
//  MaiLeMe
//
//  Created by Codex on 2026/3/4.
//

import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

/// 小组件「理性防线总览」快照。
/// 说明：Widget 不直接读 SwiftData，改为消费 App 侧写入的聚合快照，降低耦合和崩溃风险。
struct RationalDefenseWidgetSnapshot: Codable {
    /// 快照生成时间。
    let generatedAt: Date
    /// 可决策条目数量。
    let readyCount: Int
    /// 待冷静条目数量。
    let coolingCount: Int
    /// 小黑屋总条目数量。
    let totalWishCount: Int
    /// 累计省下金额（分）。
    let totalSavedAmountCents: Int
    /// 吃灰最严重物品名称（可选）。
    let topIdleItemName: String?
    /// 吃灰最严重物品 ID（可选，用于深链直达）。
    let topIdleItemID: String?
    /// 吃灰最严重物品的闲置天数（可选）。
    let topIdleDays: Int?
}

/// 小组件快照仓库：负责聚合、持久化与时间线刷新。
@MainActor
final class WidgetSnapshotStore {
    static let shared = WidgetSnapshotStore()

    private let calendar = Calendar.current
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {}

    /// 根据当前条目数据刷新「理性防线总览」快照并触发小组件刷新。
    func refreshRationalDefenseSnapshot(using items: [Item], referenceDate: Date = .now) {
        let snapshot = buildRationalDefenseSnapshot(from: items, referenceDate: referenceDate)
        persist(snapshot: snapshot)
        reloadRationalDefenseWidget()
    }

    /// 读取当前快照（用于 App 内调试和排错）。
    func loadRationalDefenseSnapshot() -> RationalDefenseWidgetSnapshot? {
        guard let data = sharedUserDefaults.data(forKey: AppConstants.Widget.snapshotDefaultsKey) else {
            return nil
        }
        return try? decoder.decode(RationalDefenseWidgetSnapshot.self, from: data)
    }

    /// 聚合小黑屋/省钱/吃灰核心指标。
    private func buildRationalDefenseSnapshot(from items: [Item], referenceDate: Date) -> RationalDefenseWidgetSnapshot {
        let wishItems = items.filter { $0.status == .wish }
        let readyCount = wishItems.filter(\.isCooldownFinished).count
        let coolingCount = max(0, wishItems.count - readyCount)
        let totalSavedAmountCents = items
            .filter { $0.status == .saved }
            .map(\.savedAmountCents)
            .reduce(0, +)

        let topIdle = items
            .filter { $0.status == .purchased }
            .compactMap { item -> (id: String, name: String, idleDays: Int)? in
                guard let baseDate = item.lastUsedAt ?? item.purchaseAt else {
                    return nil
                }
                let idleDays = idleDaysBetween(start: baseDate, end: referenceDate)
                return (item.id.uuidString, item.displayName, idleDays)
            }
            .max { lhs, rhs in
                lhs.idleDays < rhs.idleDays
            }

        return RationalDefenseWidgetSnapshot(
            generatedAt: referenceDate,
            readyCount: readyCount,
            coolingCount: coolingCount,
            totalWishCount: wishItems.count,
            totalSavedAmountCents: max(totalSavedAmountCents, 0),
            topIdleItemName: topIdle?.name,
            topIdleItemID: topIdle?.id,
            topIdleDays: topIdle?.idleDays
        )
    }

    /// 计算自然日间隔，避免小时级误差导致的天数波动。
    private func idleDaysBetween(start: Date, end: Date) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let value = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        return max(0, value)
    }

    /// 写入共享 UserDefaults（App Group）。
    private func persist(snapshot: RationalDefenseWidgetSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        sharedUserDefaults.set(data, forKey: AppConstants.Widget.snapshotDefaultsKey)
    }

    /// 刷新已接入的小组件时间线。
    private func reloadRationalDefenseWidget() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: AppConstants.Widget.rationalDefenseKind)
        WidgetCenter.shared.reloadTimelines(ofKind: AppConstants.Widget.todayActionKind)
        WidgetCenter.shared.reloadTimelines(ofKind: AppConstants.Widget.idleAlertKind)
        #endif
    }

    /// 共享 Defaults：优先 App Group，兜底标准 Defaults（便于本地调试）。
    private var sharedUserDefaults: UserDefaults {
        if let suite = UserDefaults(suiteName: AppConstants.Widget.appGroupIdentifier) {
            return suite
        }
        return .standard
    }
}
