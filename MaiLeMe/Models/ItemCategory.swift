import Foundation

/// 品类来源：标识条目分类信息来自自动识别、用户手选还是兜底降级。
enum CopyCategorySource: String, Codable, CaseIterable {
    /// 由本地规则自动识别得到。
    case autoDetected
    /// 由用户手动选择确认。
    case userSelected
    /// 自动识别失败后回退到 other。
    case fallbackOther
}

/// 行为标签来源：区分是系统推断还是用户调整后的结果。
enum CopyTagSource: String, Codable, CaseIterable {
    /// 根据分类或规则自动推断。
    case inferred
    /// 用户在 UI 上手动调整过。
    case userAdjusted
}

/// 分类置信度：表示自动分类结果的可信程度，便于后续文案或 UI 提示复用。
enum CopyConfidence: String, Codable, CaseIterable {
    /// 高置信度，可直接用于较强提示。
    case high
    /// 中置信度，适合弱提示或待确认态。
    case medium
    /// 低置信度，通常需要保守兜底。
    case low
}

/// 一级品类：用于文案系统和条目语义识别的大类分桶。
enum ItemPrimaryCategory: String, Codable, CaseIterable {
    /// 数码设备与配件。
    case digital
    /// 办公设备与生产力硬件。
    case office
    /// 手机周边。
    case phoneAccessory
    /// 家用电器。
    case appliance
    /// 家居日用。
    case home
    /// 服饰穿搭。
    case clothing
    /// 美妆护肤。
    case beauty
    /// 母婴用品。
    case baby
    /// 运动户外。
    case sports
    /// 兴趣爱好。
    case hobby
    /// 食品饮料。
    case food
    /// 宠物用品。
    case pet
    /// 出行代步。
    case mobility
    /// 订阅会员。
    case subscription
    /// 其他未归类条目。
    case other
}

/// 二级品类：用于增强文案针对性的细分类型。
enum ItemSecondaryCategory: String, Codable, CaseIterable {
    /// 固态硬盘。
    case ssd
    /// 键盘。
    case keyboard
    /// 显示器。
    case monitor
    /// 台式电脑。
    case desktopComputer
    /// 咖啡机。
    case coffeeMachine
    /// 空气炸锅。
    case airFryer
    /// 口红。
    case lipstick
    /// 护肤品。
    case skincare
    /// 猫粮。
    case catFood
    /// 纸巾。
    case tissue
    /// 露营椅。
    case campingChair
    /// 软件会员。
    case softwareMembership
    /// 其他未细分条目。
    case other

    /// 将二级品类映射到对应的一级品类，供文案系统快速归桶。
    var primaryCategory: ItemPrimaryCategory {
        switch self {
        case .ssd, .keyboard, .monitor:
            return .digital
        case .desktopComputer:
            return .office
        case .coffeeMachine, .airFryer:
            return .appliance
        case .lipstick, .skincare:
            return .beauty
        case .catFood:
            return .pet
        case .tissue:
            return .home
        case .campingChair:
            return .sports
        case .softwareMembership:
            return .subscription
        case .other:
            return .other
        }
    }
}

/// 一级品类上的默认行为标签映射，集中维护 taxonomy 规则，避免散落在标签枚举里。
extension ItemPrimaryCategory {
    /// 返回该一级品类默认关联的行为标签集合，供文案与推断逻辑复用。
    var defaultBehaviorTags: [ItemBehaviorTag] {
        switch self {
        case .digital:
            return [.efficiencyFantasy, .upgradeReplace]
        default:
            return []
        }
    }
}
