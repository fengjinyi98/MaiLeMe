import Foundation

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
