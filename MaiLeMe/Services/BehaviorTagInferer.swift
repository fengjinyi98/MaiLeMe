import Foundation

/// 行为标签推断器：根据分类结果为条目补齐消费动机标签，供后续文案与风险提示复用。
struct BehaviorTagInferer {
    /// 基于条目名称与品类信息推断行为标签集合。
    /// - Parameters:
    ///   - name: `String`，条目名称；当前规则主要依赖分类，保留该参数便于后续扩展名称级规则。
    ///   - primaryCategory: `ItemPrimaryCategory`，一级品类，用于二级品类未命中时的兜底推断。
    ///   - secondaryCategory: `ItemSecondaryCategory`，二级品类，优先级高于一级品类。
    /// - Returns: `[ItemBehaviorTag]`，按当前规则推断出的行为标签数组。
    /// - Note: 推断逻辑遵循“二级品类优先、一级品类兜底”的最小实现策略。
    func infer(
        name: String,
        primaryCategory: ItemPrimaryCategory,
        secondaryCategory: ItemSecondaryCategory
    ) -> [ItemBehaviorTag] {
        _ = name

        switch secondaryCategory {
        case .ssd:
            return [.efficiencyFantasy, .upgradeReplace]
        case .desktopComputer:
            return [.efficiencyFantasy, .selfImprovement, .upgradeReplace]
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
