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
    /// 一级品类原始值，用于 SwiftData 持久化。
    var primaryCategoryRawValue: String
    /// 二级品类原始值，用于 SwiftData 持久化。
    var secondaryCategoryRawValue: String
    /// 品类来源原始值，用于记录分类是自动识别还是用户确认。
    var categorySourceRawValue: String
    /// 品类置信度原始值，用于记录分类可信程度。
    var categoryConfidenceRawValue: String
    /// 行为标签原始值集合，用于 SwiftData 持久化。
    var behaviorTagsRawValue: [String]
    /// 行为标签来源原始值，用于区分推断与用户调整。
    var behaviorTagSourceRawValue: String
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
        primaryCategoryRawValue: String = ItemPrimaryCategory.other.rawValue,
        secondaryCategoryRawValue: String = ItemSecondaryCategory.other.rawValue,
        categorySourceRawValue: String = CopyCategorySource.autoDetected.rawValue,
        categoryConfidenceRawValue: String = CopyConfidence.low.rawValue,
        behaviorTagsRawValue: [String] = [],
        behaviorTagSourceRawValue: String = CopyTagSource.inferred.rawValue,
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
        self.primaryCategoryRawValue = primaryCategoryRawValue
        self.secondaryCategoryRawValue = secondaryCategoryRawValue
        self.categorySourceRawValue = categorySourceRawValue
        self.categoryConfidenceRawValue = categoryConfidenceRawValue
        self.behaviorTagsRawValue = behaviorTagsRawValue
        self.behaviorTagSourceRawValue = behaviorTagSourceRawValue
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
    /// 一级品类的业务语义包装；当历史值异常时回退到 `.other`。
    var primaryCategory: ItemPrimaryCategory {
        get { ItemPrimaryCategory(rawValue: primaryCategoryRawValue) ?? .other }
        set { primaryCategoryRawValue = newValue.rawValue }
    }

    /// 二级品类的业务语义包装；当历史值异常时回退到 `.other`。
    var secondaryCategory: ItemSecondaryCategory {
        get { ItemSecondaryCategory(rawValue: secondaryCategoryRawValue) ?? .other }
        set { secondaryCategoryRawValue = newValue.rawValue }
    }

    /// 品类来源的业务语义包装；异常值回退到自动识别，避免界面崩溃。
    var categorySource: CopyCategorySource {
        get { CopyCategorySource(rawValue: categorySourceRawValue) ?? .autoDetected }
        set { categorySourceRawValue = newValue.rawValue }
    }

    /// 品类置信度的业务语义包装；异常值按低置信度处理。
    var categoryConfidence: CopyConfidence {
        get { CopyConfidence(rawValue: categoryConfidenceRawValue) ?? .low }
        set { categoryConfidenceRawValue = newValue.rawValue }
    }

    /// 行为标签集合的业务语义包装；会忽略无法识别的历史脏值。
    var behaviorTags: [ItemBehaviorTag] {
        get { behaviorTagsRawValue.compactMap(ItemBehaviorTag.init(rawValue:)) }
        set { behaviorTagsRawValue = newValue.map(\.rawValue) }
    }

    /// 行为标签来源的业务语义包装；异常值默认回退到系统推断。
    var behaviorTagSource: CopyTagSource {
        get { CopyTagSource(rawValue: behaviorTagSourceRawValue) ?? .inferred }
        set { behaviorTagSourceRawValue = newValue.rawValue }
    }

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
