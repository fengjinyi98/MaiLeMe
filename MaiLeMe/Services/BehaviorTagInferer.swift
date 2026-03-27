import Foundation

/// 行为标签推断器：根据分类结果为条目补齐消费动机标签，供后续文案与风险提示复用。
struct BehaviorTagInferer {
    /// 基于条目名称与品类信息推断行为标签集合。
    /// - Parameters:
    ///   - name: `String`，条目名称；当前版本暂未读取该值，仅为后续名称级规则扩展预留接口。
    ///   - primaryCategory: `ItemPrimaryCategory`，一级品类，用于二级品类未命中时的兜底推断。
    ///   - secondaryCategory: `ItemSecondaryCategory`，二级品类，优先级高于一级品类。
    /// - Returns: `[ItemBehaviorTag]`，按当前规则推断出的行为标签数组。
    /// - Note: 推断逻辑遵循“优先复用 taxonomy 默认标签、再按少数二级品类追加差异标签”的最小实现策略。
    func infer(
        name: String,
        primaryCategory: ItemPrimaryCategory,
        secondaryCategory: ItemSecondaryCategory
    ) -> [ItemBehaviorTag] {
        _ = name

        /// 将标签数组去重后返回，避免后续规则叠加时出现重复项。
        func deduplicated(_ tags: [ItemBehaviorTag]) -> [ItemBehaviorTag] {
            Array(NSOrderedSet(array: tags)) as? [ItemBehaviorTag] ?? tags
        }

        switch secondaryCategory {
        case .ssd:
            // SSD 直接复用数字类的默认标签，避免重复维护同一套升级/提效语义。
            return deduplicated(ItemPrimaryCategory.digital.defaultBehaviorTags)
        case .desktopComputer:
            // 台式主机在“数码默认标签”基础上额外强调“提升自己”的心理动机。
            return deduplicated(ItemPrimaryCategory.digital.defaultBehaviorTags + [.selfImprovement])
        case .catFood:
            return [.highFrequencyConsumable, .stockpileComfort]
        default:
            // 当二级品类不够明确时，回退到一级品类的较弱语义规则，保持结果可解释且保守。
            switch primaryCategory {
            case .beauty:
                return [.aestheticImpulse, .socialSeeding]
            case .subscription:
                return [.subscriptionRenewal]
            case .sports:
                return [.planFull, .selfImprovement]
            default:
                return []
            }
        }
    }
}
