import Foundation

/// 行为标签：描述用户购买动机与闲置风险的本地推断语义层。
enum ItemBehaviorTag: String, Codable, CaseIterable {
    /// 对效率提升的想象驱动购买。
    case efficiencyFantasy
    /// 自我提升型消费。
    case selfImprovement
    /// 审美冲动购买。
    case aestheticImpulse
    /// 一时兴起尝鲜。
    case impulseTry
    /// 囤货带来的安全感。
    case stockpileComfort
    /// 计划过满导致闲置。
    case planFull
    /// 低频刚需。
    case lowFrequencyNeed
    /// 高频消耗品。
    case highFrequencyConsumable
    /// 升级替换型消费。
    case upgradeReplace
    /// 收藏型消费。
    case collectible
    /// 社交种草带动购买。
    case socialSeeding
    /// 订阅续费。
    case subscriptionRenewal

    /// 兼容 Task 1 已暴露的 API：内部规则委托给 taxonomy 集中映射维护。
    var isDefaultForDigital: Bool {
        ItemPrimaryCategory.digital.defaultBehaviorTags.contains(self)
    }
}
