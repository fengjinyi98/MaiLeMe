//
//  Item.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import Foundation
import SwiftData

/// 物品生命周期状态。
enum ItemStatus: String, Codable, CaseIterable {
    /// 待购状态（处于小黑屋冷静期或等待最终决策）。
    case wish
    /// 已购买状态（进入榨干机，支持打卡与成本追踪）。
    case purchased
    /// 忍住没买状态（计入省钱统计）。
    case saved
    /// 归档状态（历史记录，不参与核心统计）。
    case archived
}

/// 冷静期到期后的终局决策。
enum CooldownDecision: String, Codable, CaseIterable {
    /// 忍住没买。
    case saved
    /// 破戒购买。
    case purchased
}

@Model
final class Item {
    /// 业务主键，使用唯一约束避免重复写入。
    @Attribute(.unique) var id: UUID
    /// 物品名称。
    var name: String
    /// 录入时间。
    var createdAt: Date
    /// 当前生命周期状态。
    var status: ItemStatus
    /// 物品封面缩略图（二进制）。使用外部存储避免模型记录膨胀。
    @Attribute(.externalStorage) var coverImageData: Data?

    /// 想买阶段价格，单位为“分”。
    var wishPriceCents: Int
    /// 冷静期天数（仅小黑屋场景需要）。
    var cooldownDays: Int?
    /// 冷静期结束时间。
    var cooldownEndAt: Date?
    /// 冷静期终局决策。
    var decision: CooldownDecision?
    /// 终局决策时间。
    var decisionAt: Date?

    /// 实际购买时间（进入榨干机后写入）。
    var purchaseAt: Date?
    /// 实际购买价格，单位为“分”。
    var purchasePriceCents: Int?
    /// 是否在冷静期未结束时“提前购买”。
    var purchasedDuringCooldown: Bool
    /// 预期使用次数（可选）。
    var expectedUseCount: Int?
    /// 目标单次成本，单位为“分”。
    var targetCostPerUseCents: Int?
    /// 使用打卡次数，初始值为 0。
    var usageCount: Int
    /// 最近一次使用时间。
    var lastUsedAt: Date?

    /// 本条目累计贡献的省钱金额，单位为“分”。
    var savedAmountCents: Int

    /// 使用记录关系，删除物品时级联删除打卡记录。
    @Relationship(deleteRule: .cascade, inverse: \UsageRecord.item)
    var usageRecords: [UsageRecord]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        status: ItemStatus = .wish,
        coverImageData: Data? = nil,
        wishPriceCents: Int,
        cooldownDays: Int? = nil,
        cooldownEndAt: Date? = nil,
        decision: CooldownDecision? = nil,
        decisionAt: Date? = nil,
        purchaseAt: Date? = nil,
        purchasePriceCents: Int? = nil,
        purchasedDuringCooldown: Bool = false,
        expectedUseCount: Int? = nil,
        targetCostPerUseCents: Int? = nil,
        usageCount: Int = 0,
        lastUsedAt: Date? = nil,
        savedAmountCents: Int = 0
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.status = status
        self.coverImageData = coverImageData

        self.wishPriceCents = max(0, wishPriceCents)
        self.cooldownDays = cooldownDays
        self.cooldownEndAt = cooldownEndAt
        self.decision = decision
        self.decisionAt = decisionAt

        self.purchaseAt = purchaseAt
        if let purchasePriceCents {
            self.purchasePriceCents = max(0, purchasePriceCents)
        } else {
            self.purchasePriceCents = nil
        }
        self.purchasedDuringCooldown = purchasedDuringCooldown
        if let expectedUseCount {
            self.expectedUseCount = max(1, expectedUseCount)
        } else {
            self.expectedUseCount = nil
        }
        if let targetCostPerUseCents {
            self.targetCostPerUseCents = max(1, targetCostPerUseCents)
        } else {
            self.targetCostPerUseCents = nil
        }
        self.usageCount = max(0, usageCount)
        self.lastUsedAt = lastUsedAt

        self.savedAmountCents = max(0, savedAmountCents)
        self.usageRecords = []
    }
}

// MARK: - 业务辅助计算
extension Item {
    /// 展示名称：清理历史数据中遗留的状态后缀，避免与状态标签重复。
    var displayName: String {
        var normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)

        let duplicatedStatusSuffixes = [
            "（可决策）",
            "(可决策)",
            "（待冷静）",
            "(待冷静)",
            "（刚买未用）",
            "(刚买未用)",
            "（轻度吃灰）",
            "(轻度吃灰)",
            "（中度吃灰）",
            "(中度吃灰)",
            "（重度吃灰）",
            "(重度吃灰)",
            "（持续使用中）",
            "(持续使用中)",
            "（忍住没买）",
            "(忍住没买)"
        ]

        for suffix in duplicatedStatusSuffixes where normalized.hasSuffix(suffix) {
            normalized = String(normalized.dropLast(suffix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return normalized.isEmpty ? name : normalized
    }

    /// 当前单次成本（单位：分）。
    /// 当未购买或从未使用时返回 `nil`，由展示层显示“未使用”。
    var currentCostPerUseCents: Int? {
        guard status == .purchased,
              let purchasePriceCents,
              usageCount > 0 else {
            return nil
        }
        return purchasePriceCents / usageCount
    }

    /// 是否已到冷静期结束时间。
    var isCooldownFinished: Bool {
        guard let cooldownEndAt else { return false }
        return Date.now >= cooldownEndAt
    }
}
