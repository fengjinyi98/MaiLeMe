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
        categorySourceRawValue: String = CopyCategorySource.unresolved.rawValue,
        categoryConfidenceRawValue: String = CopyConfidence.low.rawValue,
        behaviorTagsRawValue: [String] = [],
        behaviorTagSourceRawValue: String = CopyTagSource.unresolved.rawValue,
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

        // 当二级品类已明确时，初始化阶段优先以 taxonomy 映射收敛一级品类，避免落库后出现互相矛盾的数据。
        let normalizedCategoryRawValues = Item.normalizedCategoryRawValues(
            primaryCategoryRawValue: primaryCategoryRawValue,
            secondaryCategoryRawValue: secondaryCategoryRawValue
        )
        self.wishPriceCents = max(0, wishPriceCents)
        self.primaryCategoryRawValue = normalizedCategoryRawValues.primary
        self.secondaryCategoryRawValue = normalizedCategoryRawValues.secondary
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
    /// 统一收敛主次品类原始值，避免持久化层保存彼此矛盾的 taxonomy 关系。
    /// - Parameters:
    ///   - primaryCategoryRawValue: 一级品类原始值，可能来自用户输入或历史数据。
    ///   - secondaryCategoryRawValue: 二级品类原始值，若已明确则拥有更高优先级。
    /// - Returns: 已收敛的一二级品类原始值元组。
    private static func normalizedCategoryRawValues(
        primaryCategoryRawValue: String,
        secondaryCategoryRawValue: String
    ) -> (primary: String, secondary: String) {
        let normalizedSecondaryCategory = ItemSecondaryCategory(rawValue: secondaryCategoryRawValue) ?? .other

        // 二级品类一旦明确，就始终以其映射的一级品类为准，避免业务层出现不一致状态。
        if normalizedSecondaryCategory != .other {
            return (
                normalizedSecondaryCategory.primaryCategory.rawValue,
                normalizedSecondaryCategory.rawValue
            )
        }

        // 当二级品类未知时，允许一级品类保留显式值；非法值则保守回退到 `.other`。
        let normalizedPrimaryCategory = ItemPrimaryCategory(rawValue: primaryCategoryRawValue) ?? .other
        return (
            normalizedPrimaryCategory.rawValue,
            normalizedSecondaryCategory.rawValue
        )
    }

    /// 一级品类的业务语义包装；当历史值异常时回退到 `.other`。
    var primaryCategory: ItemPrimaryCategory {
        get { ItemPrimaryCategory(rawValue: primaryCategoryRawValue) ?? .other }
        set {
            let currentSecondaryCategory = ItemSecondaryCategory(rawValue: secondaryCategoryRawValue) ?? .other

            // 当二级品类已经明确时，一级品类只能服从二级品类的 taxonomy 映射，避免 setter 重新制造不一致状态。
            guard currentSecondaryCategory == .other else {
                primaryCategoryRawValue = currentSecondaryCategory.primaryCategory.rawValue
                return
            }

            primaryCategoryRawValue = newValue.rawValue
        }
    }

    /// 二级品类的业务语义包装；当历史值异常时回退到 `.other`。
    var secondaryCategory: ItemSecondaryCategory {
        get { ItemSecondaryCategory(rawValue: secondaryCategoryRawValue) ?? .other }
        set {
            secondaryCategoryRawValue = newValue.rawValue

            // 只有在二级品类明确时才收敛一级品类；`.other` 代表未知，保留显式一级品类更符合业务语义。
            guard newValue != .other else { return }
            primaryCategoryRawValue = newValue.primaryCategory.rawValue
        }
    }

    /// 品类来源的业务语义包装；异常值回退到未处理态，避免把未知状态误报为已自动识别。
    var categorySource: CopyCategorySource {
        get { CopyCategorySource(rawValue: categorySourceRawValue) ?? .unresolved }
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

    /// 行为标签来源的业务语义包装；异常值默认回退到未处理态，避免误导上层流程。
    var behaviorTagSource: CopyTagSource {
        get { CopyTagSource(rawValue: behaviorTagSourceRawValue) ?? .unresolved }
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
