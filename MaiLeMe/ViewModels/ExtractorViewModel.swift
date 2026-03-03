//
//  ExtractorViewModel.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import Foundation
import SwiftData

/// 已购物品状态标签语义。
enum PurchasedStatusTone {
    case fresh
    case active
    case lightIdle
    case midIdle
    case heavyIdle
}

/// 已购物品状态标签。
struct PurchasedStatusTag {
    let text: String
    let tone: PurchasedStatusTone
}

/// 打卡成功仪式感文案。
struct CheckinCelebrationPayload {
    let title: String
    let subtitle: String
    let badge: String
    let isBigMoment: Bool
}

/// 榨干机模块错误定义。
enum ExtractorError: LocalizedError {
    case itemNotPurchased
    case invalidDurationMinutes

    var errorDescription: String? {
        switch self {
        case .itemNotPurchased:
            return "当前物品尚未进入已购买状态，不能打卡。"
        case .invalidDurationMinutes:
            return "使用时长必须大于 0 分钟。"
        }
    }
}

/// 榨干机业务逻辑（打卡、成本、吃灰统计）。
@MainActor
final class ExtractorViewModel {
    private let calendar: Calendar
    private let nowProvider: () -> Date

    init(
        calendar: Calendar = .current,
        nowProvider: @escaping () -> Date = { .now }
    ) {
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    /// 新增一次使用打卡，并同步更新物品聚合字段。
    @discardableResult
    func addUsageRecord(
        for item: Item,
        usedAt: Date? = nil,
        durationMinutes: Int? = nil,
        note: String? = nil,
        context: ModelContext
    ) throws -> UsageRecord {
        guard item.status == .purchased else {
            throw ExtractorError.itemNotPurchased
        }
        if let durationMinutes, durationMinutes <= 0 {
            throw ExtractorError.invalidDurationMinutes
        }

        let finalUsedAt = usedAt ?? nowProvider()
        let record = UsageRecord(
            usedAt: finalUsedAt,
            durationMinutes: durationMinutes,
            note: normalizedNote(note),
            item: item
        )
        context.insert(record)

        item.usageCount += 1
        if let lastUsedAt = item.lastUsedAt {
            item.lastUsedAt = max(lastUsedAt, finalUsedAt)
        } else if let purchaseAt = item.purchaseAt {
            item.lastUsedAt = max(purchaseAt, finalUsedAt)
        } else {
            item.lastUsedAt = finalUsedAt
        }
        return record
    }

    /// 获取当前单次成本（单位：分）。
    func currentCostPerUseCents(for item: Item) -> Int? {
        item.currentCostPerUseCents
    }

    /// 计算回本进度（0.0 ~ 1.0）。
    /// 规则：当当前单次成本 <= 目标成本时视为回本完成（1.0）。
    func paybackProgress(for item: Item) -> Double? {
        guard item.status == .purchased,
              let target = item.targetCostPerUseCents,
              target > 0,
              let current = item.currentCostPerUseCents,
              current > 0 else {
            return nil
        }

        if current <= target {
            return 1.0
        }
        let progress = Double(target) / Double(current)
        return min(max(progress, 0), 1)
    }

    /// 计算吃灰天数（按自然日）。
    /// 优先使用最近一次使用时间；若从未使用则回退到购买时间。
    func idleDays(for item: Item) -> Int? {
        guard item.status == .purchased else {
            return nil
        }
        guard let baseDate = item.lastUsedAt ?? item.purchaseAt else {
            return nil
        }

        let baseStart = calendar.startOfDay(for: baseDate)
        let todayStart = calendar.startOfDay(for: nowProvider())
        let rawDays = calendar.dateComponents([.day], from: baseStart, to: todayStart).day ?? 0
        return max(0, rawDays)
    }

    /// 选出吃灰最严重的前 N 个物品。
    func topIdleItems(from items: [Item], limit: Int = 3) -> [Item] {
        guard limit > 0 else {
            return []
        }

        return items
            .filter { $0.status == .purchased }
            .sorted { lhs, rhs in
                let lhsDays = idleDays(for: lhs) ?? -1
                let rhsDays = idleDays(for: rhs) ?? -1
                if lhsDays != rhsDays {
                    return lhsDays > rhsDays
                }
                return lhs.createdAt < rhs.createdAt
            }
            .prefix(limit)
            .map { $0 }
    }

    /// 统计“靠意念省下”的总金额（单位：分）。
    func totalSavedAmountCents(from items: [Item]) -> Int {
        items
            .filter { $0.status == .saved }
            .map(\.savedAmountCents)
            .reduce(0, +)
    }

    /// 计算已购物品的动态状态标签，避免把状态硬编码进标题。
    func purchasedStatusTag(for item: Item) -> PurchasedStatusTag {
        guard item.status == .purchased else {
            return PurchasedStatusTag(text: "未购买", tone: .fresh)
        }

        if item.usageCount == 0 {
            return PurchasedStatusTag(text: "刚买未用", tone: .fresh)
        }

        let idle = idleDays(for: item) ?? 0
        if idle >= 30 {
            return PurchasedStatusTag(text: "重度吃灰", tone: .heavyIdle)
        } else if idle >= 14 {
            return PurchasedStatusTag(text: "中度吃灰", tone: .midIdle)
        } else if idle >= 7 {
            return PurchasedStatusTag(text: "轻度吃灰", tone: .lightIdle)
        } else {
            return PurchasedStatusTag(text: "持续使用中", tone: .active)
        }
    }

    /// 生成打卡成功反馈文案：根据“首次使用/回坑/持续使用”自动切换语气。
    func makeCheckinCelebration(
        for item: Item,
        previousUsageCount: Int,
        previousIdleDays: Int?,
        usedAt: Date
    ) -> CheckinCelebrationPayload {
        if previousUsageCount == 0 {
            let daysToFirstUse = firstUseDelayDays(for: item, usedAt: usedAt)
            if daysToFirstUse <= 1 {
                return CheckinCelebrationPayload(
                    title: "上手即开张，这波很会买",
                    subtitle: "买完马上用，钱包看了都想给你点赞。",
                    badge: "首战即用",
                    isBigMoment: true
                )
            } else if daysToFirstUse >= 30 {
                return CheckinCelebrationPayload(
                    title: "吃灰一个月，终于被你救活",
                    subtitle: "拖了 \(daysToFirstUse) 天才开封，但今天这下算是把面子挣回来了。",
                    badge: "迟到首刷",
                    isBigMoment: true
                )
            } else {
                return CheckinCelebrationPayload(
                    title: "首次打卡到账",
                    subtitle: "比继续落灰强太多，今天这一用很争气。",
                    badge: "首次开封",
                    isBigMoment: false
                )
            }
        }

        let idle = previousIdleDays ?? 0
        if idle >= 30 {
            return CheckinCelebrationPayload(
                title: "重度吃灰逆转成功",
                subtitle: "沉寂 \(idle) 天后终于复活，资产没有白买。",
                badge: "回坑成功",
                isBigMoment: true
            )
        } else if idle >= 14 {
            return CheckinCelebrationPayload(
                title: "拖延症被你反杀",
                subtitle: "停摆 \(idle) 天后重启使用，这次继续连击别断。",
                badge: "复活连击",
                isBigMoment: true
            )
        } else if idle <= 1 {
            return CheckinCelebrationPayload(
                title: "节奏在线，成本在掉",
                subtitle: "你在稳定输出，单次成本正在被你按着打。",
                badge: "稳定输出",
                isBigMoment: false
            )
        } else {
            return CheckinCelebrationPayload(
                title: "今日打卡，继续回血",
                subtitle: "这波使用很关键，你又把冲动消费扳回一城。",
                badge: "今日 +1",
                isBigMoment: false
            )
        }
    }

    /// 清洗备注文本，避免只写空白字符。
    private func normalizedNote(_ note: String?) -> String? {
        guard let note else { return nil }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 计算“购买到首次使用”的间隔天数（按自然日）。
    private func firstUseDelayDays(for item: Item, usedAt: Date) -> Int {
        guard let purchaseAt = item.purchaseAt else {
            return 0
        }
        let purchaseStart = calendar.startOfDay(for: purchaseAt)
        let usedStart = calendar.startOfDay(for: usedAt)
        let value = calendar.dateComponents([.day], from: purchaseStart, to: usedStart).day ?? 0
        return max(0, value)
    }
}
