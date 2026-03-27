import Foundation

/// 文案所属模块：按业务入口划分资源集合，便于 loader 分文件装载与 resolver 后续筛选。
enum CopyModule: String, Codable, CaseIterable, Sendable {
    /// 通知相关文案。
    case notification
    /// 冷静期决策完成后的仪式文案。
    case decision
    /// 榨干机打卡文案。
    case checkin
    /// 吃灰挽救文案。
    case idleRescue
    /// 省钱复盘文案。
    case savedReview
    /// 空状态文案。
    case emptyState
    /// 分享文案片段。
    case share

    /// 对应的资源文件名：保持模块枚举与磁盘 JSON 文件的一致真相源，避免 loader 再维护第二份硬编码清单。
    var resourceFileName: String {
        switch self {
        case .notification:
            return "notifications"
        case .decision:
            return "decision"
        case .checkin:
            return "checkin"
        case .idleRescue:
            return "idle_rescue"
        case .savedReview:
            return "saved_review"
        case .emptyState:
            return "empty_state"
        case .share:
            return "share"
        }
    }
}

/// 文案在一个模块中的承载位置：用于 resolver 按 UI 槽位精确选词。
enum CopySlot: String, Codable, CaseIterable, Sendable {
    /// 主标题。
    case title
    /// 副标题。
    case subtitle
    /// 角标或状态标签。
    case badge
    /// 毒舌点评。
    case roast
    /// 主行动按钮标题。
    case actionTitle
    /// 通用正文。
    case body
    /// 主点评。
    case primary
    /// 辅助点评。
    case secondary
}

/// 文案语气标签：后续用于控制整体风格匹配与降级策略。
enum CopyTone: String, Codable, CaseIterable, Sendable {
    /// 辛辣、带一点攻击性的口吻。
    case sharp
    /// 冷面吐槽、不过度情绪化。
    case dry
    /// 稍微鼓励、保留善意的语气。
    case warm
    /// 中性兜底。
    case neutral
}

/// 文案强度等级：用于限制某些场景不要出现过重或过轻的话术。
enum CopyIntensity: String, Codable, CaseIterable, Sendable {
    /// 轻提醒。
    case low
    /// 中等力度。
    case medium
    /// 强刺激。
    case high
}

/// 文案稳定性：控制同一上下文下是固定、轮换还是允许更随机的输出。
enum CopyStability: String, Codable, CaseIterable, Sendable {
    /// 稳定输出，同场景尽量固定。
    case stable
    /// 半稳定，允许在较小集合中切换。
    case semiStable
    /// 轮换输出，避免重复。
    case rotating
    /// 完全随机。
    case random
}

/// 单条结构化文案资产：将原来分散在常量里的文案提升为可筛选、可加载、可演进的数据记录。
struct RoastCopyEntry: Codable, Identifiable, Equatable, Sendable {
    /// 资源主键，用于去重、埋点与反重复记忆。
    let id: String
    /// 所属业务模块。
    let module: CopyModule
    /// 文案投放槽位。
    let slot: CopySlot
    /// 命中的场景标签；允许一个条目覆盖多个相近场景。
    let scene: [String]
    /// 语气标签。
    let tone: CopyTone
    /// 强度标签。
    let intensity: CopyIntensity
    /// 稳定性标签。
    let stability: CopyStability
    /// 带变量占位符的原始模板。
    let template: String
    /// 模板需要的变量名列表，便于后续校验与渲染。
    let variables: [String]
    /// 允许命中的一级品类白名单。
    let categoryInclude: [ItemPrimaryCategory]
    /// 需要排除的一级品类黑名单。
    let categoryExclude: [ItemPrimaryCategory]
    /// 允许命中的行为标签白名单。
    let behaviorInclude: [ItemBehaviorTag]
    /// 需要排除的行为标签黑名单。
    let behaviorExclude: [ItemBehaviorTag]
    /// 候选权重；后续 resolver 可据此做加权排序或随机抽样。
    let weight: Int
}
