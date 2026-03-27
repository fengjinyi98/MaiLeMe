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
    case resale
}

/// 已购物品状态标签。
struct PurchasedStatusTag {
    let text: String
    let tone: PurchasedStatusTone
}

/// 资产健康度快照：用于统一驱动列表、看板与详情页展示。
struct ItemHealthSnapshot {
    /// 综合健康度（0.0 ~ 1.0）。
    let overallScore: Double
    /// 资产效率分：买入价分摊到日均后的效率感知。
    let assetEfficiencyScore: Double
    /// 使用活跃分：近 30 天活跃天数映射分值。
    let activityScore: Double
    /// 闲置风险分：连续闲置越久，分值越低。
    let idleRiskScore: Double
    /// 近 30 天活跃天数。
    let activeDaysIn30: Int
    /// 连续闲置天数。
    let idleDays: Int
    /// 日均持有成本（分/天）。
    let dailyHoldingCostCents: Int
}

/// 打卡成功仪式感文案。
struct CheckinCelebrationPayload {
    let title: String
    let subtitle: String
    let badge: String
    let roastLine: String
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

    /// 统一资产健康度：用于替代“仅靠目标单次成本”的单一回本进度。
    /// 口径：
    /// 1) 资产效率：买入价 / 持有天数（分/天）映射到 0~1；
    /// 2) 使用活跃：近 30 天活跃天数映射到 0~1；
    /// 3) 闲置风险：连续闲置天数映射到 0~1。
    /// 三项加权后得到综合健康度。
    func healthSnapshot(for item: Item) -> ItemHealthSnapshot? {
        guard item.status == .purchased else {
            return nil
        }

        let idle = idleDays(for: item) ?? 0
        let activeDays = activeDaysInLast30Days(for: item)
        guard let dailyCost = dailyHoldingCostCents(for: item) else {
            return nil
        }

        let assetScore = assetEfficiencyScore(dailyCostCents: dailyCost)
        let activityScore = min(max(Double(activeDays) / 12.0, 0), 1)
        let idleScore = idleRiskScore(idleDays: idle)
        let overall = min(
            max(
                (assetScore * 0.34) + (activityScore * 0.33) + (idleScore * 0.33),
                0
            ),
            1
        )

        return ItemHealthSnapshot(
            overallScore: overall,
            assetEfficiencyScore: assetScore,
            activityScore: activityScore,
            idleRiskScore: idleScore,
            activeDaysIn30: activeDays,
            idleDays: idle,
            dailyHoldingCostCents: dailyCost
        )
    }

    /// 获取综合健康度（0.0 ~ 1.0）。
    func healthScore(for item: Item) -> Double {
        healthSnapshot(for: item)?.overallScore ?? 0
    }

    /// 近 30 天活跃天数：按“自然日去重”统计，避免同一天多次打卡放大活跃度。
    func activeDaysInLast30Days(for item: Item) -> Int {
        guard item.status == .purchased else {
            return 0
        }

        let today = calendar.startOfDay(for: nowProvider())
        guard let windowStart = calendar.date(byAdding: .day, value: -29, to: today) else {
            return 0
        }

        var dayBuckets = Set<Date>()
        for record in item.usageRecords {
            let day = calendar.startOfDay(for: record.usedAt)
            if day >= windowStart && day <= today {
                dayBuckets.insert(day)
            }
        }

        // 兼容历史聚合数据：若旧数据仅维护了 usageCount / lastUsedAt，则兜底记为 1 天活跃。
        if dayBuckets.isEmpty, item.usageCount > 0, let lastUsedAt = item.lastUsedAt {
            let lastUsedDay = calendar.startOfDay(for: lastUsedAt)
            if lastUsedDay >= windowStart && lastUsedDay <= today {
                dayBuckets.insert(lastUsedDay)
            }
        }

        return dayBuckets.count
    }

    /// 日均持有成本（分/天）：买入价越高、持有天数越少时，该值越高。
    func dailyHoldingCostCents(for item: Item) -> Int? {
        guard item.status == .purchased else {
            return nil
        }

        let purchasePrice = max(item.purchasePriceCents ?? item.wishPriceCents, 1)
        let holdingDays = max(holdingDaysSincePurchase(for: item), 1)
        return max(1, purchasePrice / holdingDays)
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
            return PurchasedStatusTag(text: "待开张", tone: .fresh)
        }

        let idle = idleDays(for: item) ?? 0
        if idle >= 60 {
            return PurchasedStatusTag(text: "建议转卖", tone: .resale)
        } else if idle >= 30 {
            return PurchasedStatusTag(text: "重度吃灰", tone: .heavyIdle)
        } else if idle >= 14 {
            return PurchasedStatusTag(text: "中度吃灰", tone: .midIdle)
        } else if idle >= 7 {
            return PurchasedStatusTag(text: "轻度吃灰", tone: .lightIdle)
        }

        let activeDays = activeDaysInLast30Days(for: item)
        if activeDays >= 12 {
            return PurchasedStatusTag(text: "高活跃", tone: .active)
        }
        return PurchasedStatusTag(text: "稳步使用", tone: .active)
    }

    /// 生成打卡成功反馈文案：根据“首次使用/回坑/持续使用”自动切换语气。
    func makeCheckinCelebration(
        for item: Item,
        previousUsageCount: Int,
        previousIdleDays: Int?,
        usedAt: Date
    ) -> CheckinCelebrationPayload {
        let currentUsageCount = previousUsageCount + 1
        let itemName = item.displayName
        let primaryCategory = item.primaryCategory
        let secondaryCategory = item.secondaryCategory
        let behaviorTags = item.behaviorTags

        if previousUsageCount == 0 {
            let daysToFirstUse = firstUseDelayDays(for: item, usedAt: usedAt)
            if daysToFirstUse <= 1 {
                let fallback = AppConstants.RoastCopy.checkinFirstUseImmediateBundle()
                let copy = AppConstants.RoastCopy.checkinBundle(
                    scene: "first_use_immediate",
                    fallback: fallback,
                    itemName: itemName,
                    itemID: item.id,
                    primaryCategory: primaryCategory,
                    secondaryCategory: secondaryCategory,
                    behaviorTags: behaviorTags
                )
                let roastFallback = AppConstants.RoastCopy.checkinCelebrationRoastLine(
                    usageCount: currentUsageCount,
                    isBigMoment: true
                )
                return CheckinCelebrationPayload(
                    title: copy.title,
                    subtitle: copy.subtitle,
                    badge: copy.badge,
                    roastLine: AppConstants.RoastCopy.checkinCelebrationRoastLine(
                        scene: checkinRoastScene(
                            usageCount: currentUsageCount,
                            isBigMoment: true
                        ),
                        fallback: roastFallback,
                        itemName: itemName,
                        itemID: item.id,
                        primaryCategory: primaryCategory,
                        secondaryCategory: secondaryCategory,
                        behaviorTags: behaviorTags
                    ),
                    isBigMoment: true
                )
            } else if daysToFirstUse >= 30 {
                let fallback = AppConstants.RoastCopy.checkinFirstUseLateBundle(daysToFirstUse: daysToFirstUse)
                let copy = AppConstants.RoastCopy.checkinBundle(
                    scene: "first_use_late",
                    fallback: fallback,
                    itemName: itemName,
                    itemID: item.id,
                    primaryCategory: primaryCategory,
                    secondaryCategory: secondaryCategory,
                    behaviorTags: behaviorTags,
                    variables: ["daysToFirstUse": "\(daysToFirstUse)"]
                )
                let roastFallback = AppConstants.RoastCopy.checkinCelebrationRoastLine(
                    usageCount: currentUsageCount,
                    isBigMoment: true
                )
                return CheckinCelebrationPayload(
                    title: copy.title,
                    subtitle: copy.subtitle,
                    badge: copy.badge,
                    roastLine: AppConstants.RoastCopy.checkinCelebrationRoastLine(
                        scene: checkinRoastScene(
                            usageCount: currentUsageCount,
                            isBigMoment: true
                        ),
                        fallback: roastFallback,
                        itemName: itemName,
                        itemID: item.id,
                        primaryCategory: primaryCategory,
                        secondaryCategory: secondaryCategory,
                        behaviorTags: behaviorTags,
                        variables: ["daysToFirstUse": "\(daysToFirstUse)"]
                    ),
                    isBigMoment: true
                )
            } else {
                let fallback = AppConstants.RoastCopy.checkinFirstUseNormalBundle()
                let copy = AppConstants.RoastCopy.checkinBundle(
                    scene: "first_use_normal",
                    fallback: fallback,
                    itemName: itemName,
                    itemID: item.id,
                    primaryCategory: primaryCategory,
                    secondaryCategory: secondaryCategory,
                    behaviorTags: behaviorTags
                )
                let roastFallback = AppConstants.RoastCopy.checkinCelebrationRoastLine(
                    usageCount: currentUsageCount,
                    isBigMoment: false
                )
                return CheckinCelebrationPayload(
                    title: copy.title,
                    subtitle: copy.subtitle,
                    badge: copy.badge,
                    roastLine: AppConstants.RoastCopy.checkinCelebrationRoastLine(
                        scene: checkinRoastScene(
                            usageCount: currentUsageCount,
                            isBigMoment: false
                        ),
                        fallback: roastFallback,
                        itemName: itemName,
                        itemID: item.id,
                        primaryCategory: primaryCategory,
                        secondaryCategory: secondaryCategory,
                        behaviorTags: behaviorTags
                    ),
                    isBigMoment: false
                )
            }
        }

        let idle = previousIdleDays ?? 0
        if idle >= 30 {
            let fallback = AppConstants.RoastCopy.checkinRevivalHeavyBundle(idleDays: idle)
            let copy = AppConstants.RoastCopy.checkinBundle(
                scene: "revival_heavy",
                fallback: fallback,
                itemName: itemName,
                itemID: item.id,
                primaryCategory: primaryCategory,
                secondaryCategory: secondaryCategory,
                behaviorTags: behaviorTags,
                variables: ["idleDays": "\(idle)"]
            )
            let roastFallback = AppConstants.RoastCopy.checkinCelebrationRoastLine(
                usageCount: currentUsageCount,
                isBigMoment: true
            )
            return CheckinCelebrationPayload(
                title: copy.title,
                subtitle: copy.subtitle,
                badge: copy.badge,
                roastLine: AppConstants.RoastCopy.checkinCelebrationRoastLine(
                    scene: checkinRoastScene(
                        usageCount: currentUsageCount,
                        isBigMoment: true
                    ),
                    fallback: roastFallback,
                    itemName: itemName,
                    itemID: item.id,
                    primaryCategory: primaryCategory,
                    secondaryCategory: secondaryCategory,
                    behaviorTags: behaviorTags,
                    variables: ["idleDays": "\(idle)"]
                ),
                isBigMoment: true
            )
        } else if idle >= 14 {
            let fallback = AppConstants.RoastCopy.checkinRevivalMidBundle(idleDays: idle)
            let copy = AppConstants.RoastCopy.checkinBundle(
                scene: "revival_mid",
                fallback: fallback,
                itemName: itemName,
                itemID: item.id,
                primaryCategory: primaryCategory,
                secondaryCategory: secondaryCategory,
                behaviorTags: behaviorTags,
                variables: ["idleDays": "\(idle)"]
            )
            let roastFallback = AppConstants.RoastCopy.checkinCelebrationRoastLine(
                usageCount: currentUsageCount,
                isBigMoment: true
            )
            return CheckinCelebrationPayload(
                title: copy.title,
                subtitle: copy.subtitle,
                badge: copy.badge,
                roastLine: AppConstants.RoastCopy.checkinCelebrationRoastLine(
                    scene: checkinRoastScene(
                        usageCount: currentUsageCount,
                        isBigMoment: true
                    ),
                    fallback: roastFallback,
                    itemName: itemName,
                    itemID: item.id,
                    primaryCategory: primaryCategory,
                    secondaryCategory: secondaryCategory,
                    behaviorTags: behaviorTags,
                    variables: ["idleDays": "\(idle)"]
                ),
                isBigMoment: true
            )
        } else if currentUsageCount >= 10 {
            let fallback = AppConstants.RoastCopy.checkinSteadyBundle()
            let copy = AppConstants.RoastCopy.checkinBundle(
                scene: "steady_high_usage",
                fallback: fallback,
                itemName: itemName,
                itemID: item.id,
                primaryCategory: primaryCategory,
                secondaryCategory: secondaryCategory,
                behaviorTags: behaviorTags
            )
            let roastFallback = AppConstants.RoastCopy.checkinCelebrationRoastLine(
                usageCount: currentUsageCount,
                isBigMoment: false
            )
            return CheckinCelebrationPayload(
                title: copy.title,
                subtitle: copy.subtitle,
                badge: copy.badge,
                roastLine: AppConstants.RoastCopy.checkinCelebrationRoastLine(
                    scene: checkinRoastScene(
                        usageCount: currentUsageCount,
                        isBigMoment: false
                    ),
                    fallback: roastFallback,
                    itemName: itemName,
                    itemID: item.id,
                    primaryCategory: primaryCategory,
                    secondaryCategory: secondaryCategory,
                    behaviorTags: behaviorTags
                ),
                isBigMoment: false
            )
        } else {
            let fallback = AppConstants.RoastCopy.checkinNormalBundle()
            let copy = AppConstants.RoastCopy.checkinBundle(
                scene: "checkin_default",
                fallback: fallback,
                itemName: itemName,
                itemID: item.id,
                primaryCategory: primaryCategory,
                secondaryCategory: secondaryCategory,
                behaviorTags: behaviorTags
            )
            let roastFallback = AppConstants.RoastCopy.checkinCelebrationRoastLine(
                usageCount: currentUsageCount,
                isBigMoment: false
            )
            return CheckinCelebrationPayload(
                title: copy.title,
                subtitle: copy.subtitle,
                badge: copy.badge,
                roastLine: AppConstants.RoastCopy.checkinCelebrationRoastLine(
                    scene: checkinRoastScene(
                        usageCount: currentUsageCount,
                        isBigMoment: false
                    ),
                    fallback: roastFallback,
                    itemName: itemName,
                    itemID: item.id,
                    primaryCategory: primaryCategory,
                    secondaryCategory: secondaryCategory,
                    behaviorTags: behaviorTags
                ),
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

    /// 将打卡仪式页的 roast 槽位场景独立出来，避免直接复用 title/subtitle/badge 的业务场景。
    /// - Parameters:
    ///   - usageCount: `Int`，打卡后的累计使用次数。
    ///   - isBigMoment: `Bool`，当前是否属于强事件节点（如重度回坑）。
    /// - Returns: `String`，供 roast 槽位命中的专用 scene 标识。
    private func checkinRoastScene(usageCount: Int, isBigMoment: Bool) -> String {
        if usageCount == 1 {
            return "first_use"
        }
        if isBigMoment {
            return "big_moment"
        }
        if usageCount >= 30 {
            return "high_usage"
        }
        return "default"
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

    /// 从购买到今天的持有天数（至少 1 天）。
    private func holdingDaysSincePurchase(for item: Item) -> Int {
        let baseDate = item.purchaseAt ?? item.createdAt
        let baseStart = calendar.startOfDay(for: baseDate)
        let todayStart = calendar.startOfDay(for: nowProvider())
        let raw = calendar.dateComponents([.day], from: baseStart, to: todayStart).day ?? 0
        return max(1, raw + 1)
    }

    /// 资产效率映射：日均持有成本越低，效率分越高。
    /// 基准值使用 15 元/天（1500 分/天），可按后续真实数据再调整。
    private func assetEfficiencyScore(dailyCostCents: Int) -> Double {
        let baselineDailyCost = 1500.0
        let ratio = Double(dailyCostCents) / baselineDailyCost
        return min(max(1.0 / (1.0 + ratio), 0), 1)
    }

    /// 闲置风险映射：连续闲置越久，分值越低。
    private func idleRiskScore(idleDays: Int) -> Double {
        switch idleDays {
        case ..<3:
            return 1.0
        case 3..<7:
            return 0.82
        case 7..<14:
            return 0.62
        case 14..<30:
            return 0.38
        case 30..<60:
            return 0.18
        default:
            return 0.05
        }
    }
}
