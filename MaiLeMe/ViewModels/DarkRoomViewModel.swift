//
//  DarkRoomViewModel.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import Foundation
import SwiftData

/// 冷静期终局决策类型。
enum DarkRoomDecisionOutcome {
    case saved
    case purchased
}

/// 决策仪式弹层风格。
enum DarkRoomCelebrationTone {
    case saved
    case purchased
}

/// 冷静期决策仪式弹层数据。
struct DarkRoomDecisionCelebrationPayload {
    let title: String
    let subtitle: String
    let roastLine: String
    let badge: String
    let iconSystemName: String
    let metricTitle: String
    let metricValue: String
    let actionTitle: String
    let tone: DarkRoomCelebrationTone
}

/// 小黑屋模块错误定义。
enum DarkRoomError: LocalizedError {
    case invalidName
    case invalidPrice
    case invalidCooldownDays
    case itemStatusNotWish
    case cooldownNotFinished
    case invalidTargetCost
    case invalidExpectedUseCount

    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "物品名称不能为空。"
        case .invalidPrice:
            return "价格不能为负数。"
        case .invalidCooldownDays:
            return "冷静期天数必须大于 0。"
        case .itemStatusNotWish:
            return "当前物品不在待购状态，无法执行该操作。"
        case .cooldownNotFinished:
            return "冷静期尚未结束，暂不允许做最终决策。"
        case .invalidTargetCost:
            return "目标单次成本必须大于 0。"
        case .invalidExpectedUseCount:
            return "预期使用次数必须大于 0。"
        }
    }
}

/// 小黑屋业务逻辑（冷静期创建与终局决策）。
@MainActor
final class DarkRoomViewModel {
    private let calendar: Calendar
    private let nowProvider: () -> Date

    init(
        calendar: Calendar = .current,
        nowProvider: @escaping () -> Date = { .now }
    ) {
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    /// 创建一条待购物品，默认进入冷静期。
    @discardableResult
    func createWishItem(
        name: String,
        wishPriceCents: Int,
        cooldownDays: Int,
        coverImageData: Data? = nil,
        context: ModelContext
    ) throws -> Item {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            throw DarkRoomError.invalidName
        }
        guard wishPriceCents >= 0 else {
            throw DarkRoomError.invalidPrice
        }
        guard cooldownDays > 0 else {
            throw DarkRoomError.invalidCooldownDays
        }

        let now = nowProvider()
        let cooldownEndAt = calendar.date(byAdding: .day, value: cooldownDays, to: now)
        let item = Item(
            name: normalizedName,
            createdAt: now,
            status: .wish,
            coverImageData: coverImageData,
            wishPriceCents: wishPriceCents,
            cooldownDays: cooldownDays,
            cooldownEndAt: cooldownEndAt
        )
        context.insert(item)
        return item
    }

    /// 计算剩余冷静天数（按自然日）。
    func remainingCooldownDays(for item: Item) -> Int {
        guard let cooldownEndAt = item.cooldownEndAt else {
            return 0
        }
        let todayStart = calendar.startOfDay(for: nowProvider())
        let endDayStart = calendar.startOfDay(for: cooldownEndAt)
        let rawDays = calendar.dateComponents([.day], from: todayStart, to: endDayStart).day ?? 0
        return max(0, rawDays)
    }

    /// 判断当前是否可以做冷静期终局决策。
    func canMakeDecision(for item: Item) -> Bool {
        guard item.status == .wish, let cooldownEndAt = item.cooldownEndAt else {
            return false
        }
        return nowProvider() >= cooldownEndAt
    }

    /// 生成冷静期终局决策成功后的仪式感文案。
    func makeDecisionCelebration(
        for item: Item,
        outcome: DarkRoomDecisionOutcome
    ) -> DarkRoomDecisionCelebrationPayload {
        switch outcome {
        case .saved:
            let savedCents = max(item.savedAmountCents, item.wishPriceCents)
            let copy = AppConstants.RoastCopy.decisionSavedBundle()
            return DarkRoomDecisionCelebrationPayload(
                title: copy.title,
                subtitle: copy.subtitle,
                roastLine: AppConstants.RoastCopy.decisionCelebrationRoastLine(isSaved: true),
                badge: "忍住没买",
                iconSystemName: "shield.checkered",
                metricTitle: "省下金额",
                metricValue: "¥\(centsToYuan(savedCents))",
                actionTitle: copy.actionTitle,
                tone: .saved
            )
        case .purchased:
            let purchaseCents = item.purchasePriceCents ?? item.wishPriceCents
            let copy = AppConstants.RoastCopy.decisionPurchasedBundle()
            return DarkRoomDecisionCelebrationPayload(
                title: copy.title,
                subtitle: copy.subtitle,
                roastLine: AppConstants.RoastCopy.decisionCelebrationRoastLine(isSaved: false),
                badge: "还是买了",
                iconSystemName: "cart.fill.badge.plus",
                metricTitle: "买入金额",
                metricValue: "¥\(centsToYuan(purchaseCents))",
                actionTitle: copy.actionTitle,
                tone: .purchased
            )
        }
    }

    /// 冷静期结束后，记录“忍住没买”。
    func markAsSaved(item: Item) throws {
        try validateWishAndCooldown(item: item, allowBeforeCooldown: false)

        item.decision = .saved
        item.decisionAt = nowProvider()
        item.status = .saved
        item.savedAmountCents = item.wishPriceCents

        // 该路径表示未购买，清空购买相关字段避免脏数据。
        item.purchaseAt = nil
        item.purchasePriceCents = nil
        item.purchasedDuringCooldown = false
        item.expectedUseCount = nil
        item.targetCostPerUseCents = nil
        item.usageCount = 0
        item.lastUsedAt = nil
    }

    /// 正常决策购买：仅允许冷静期结束后执行。
    func markAsPurchased(
        item: Item,
        purchasePriceCents: Int,
        targetCostPerUseCents: Int? = nil,
        expectedUseCount: Int? = nil,
        purchaseAt: Date? = nil
    ) throws {
        try markAsPurchased(
            item: item,
            purchasePriceCents: purchasePriceCents,
            targetCostPerUseCents: targetCostPerUseCents,
            expectedUseCount: expectedUseCount,
            purchaseAt: purchaseAt,
            allowBeforeCooldown: false
        )
    }

    /// 冷静期内提前购买：用于“冲动消费”场景。
    func markAsPurchasedDuringCooldown(
        item: Item,
        purchasePriceCents: Int,
        targetCostPerUseCents: Int? = nil,
        expectedUseCount: Int? = nil,
        purchaseAt: Date? = nil
    ) throws {
        try markAsPurchased(
            item: item,
            purchasePriceCents: purchasePriceCents,
            targetCostPerUseCents: targetCostPerUseCents,
            expectedUseCount: expectedUseCount,
            purchaseAt: purchaseAt,
            allowBeforeCooldown: true
        )
    }

    /// 购买流转核心逻辑：支持“正常决策”和“提前购买”两条路径。
    private func markAsPurchased(
        item: Item,
        purchasePriceCents: Int,
        targetCostPerUseCents: Int? = nil,
        expectedUseCount: Int? = nil,
        purchaseAt: Date? = nil,
        allowBeforeCooldown: Bool
    ) throws {
        guard purchasePriceCents >= 0 else {
            throw DarkRoomError.invalidPrice
        }
        if let targetCostPerUseCents, targetCostPerUseCents <= 0 {
            throw DarkRoomError.invalidTargetCost
        }
        if let expectedUseCount, expectedUseCount <= 0 {
            throw DarkRoomError.invalidExpectedUseCount
        }

        let isCooldownFinishedBeforeDecision = canMakeDecision(for: item)
        try validateWishAndCooldown(item: item, allowBeforeCooldown: allowBeforeCooldown)

        let finalTargetCost = resolvedTargetCost(
            purchasePriceCents: purchasePriceCents,
            targetCostPerUseCents: targetCostPerUseCents,
            expectedUseCount: expectedUseCount
        )

        item.decision = .purchased
        item.decisionAt = nowProvider()
        item.status = .purchased
        item.purchaseAt = purchaseAt ?? nowProvider()
        item.purchasePriceCents = purchasePriceCents
        item.purchasedDuringCooldown = !isCooldownFinishedBeforeDecision
        item.expectedUseCount = expectedUseCount
        item.targetCostPerUseCents = finalTargetCost
        item.savedAmountCents = 0
    }

    /// 根据用户输入计算最终目标单次成本。
    /// 优先级：手动输入 > 购买价格 / 预期使用次数 > nil。
    private func resolvedTargetCost(
        purchasePriceCents: Int,
        targetCostPerUseCents: Int?,
        expectedUseCount: Int?
    ) -> Int? {
        if let targetCostPerUseCents {
            return max(1, targetCostPerUseCents)
        }
        guard let expectedUseCount, expectedUseCount > 0 else {
            return nil
        }
        let cost = purchasePriceCents / expectedUseCount
        return max(1, cost)
    }

    /// 内部校验：仅允许待购状态；默认要求冷静期结束。
    private func validateWishAndCooldown(item: Item, allowBeforeCooldown: Bool) throws {
        guard item.status == .wish else {
            throw DarkRoomError.itemStatusNotWish
        }
        if !allowBeforeCooldown, !canMakeDecision(for: item) {
            throw DarkRoomError.cooldownNotFinished
        }
    }

    /// 将“分”转换为“元”文本。
    private func centsToYuan(_ cents: Int) -> String {
        String(format: "%.2f", Double(cents) / 100.0)
    }
}
