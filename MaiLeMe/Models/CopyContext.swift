import Foundation

/// 文案解析上下文：承载 resolver 选择文案时所需的场景、条目语义与模板变量。
struct CopyContext: Equatable, Sendable {
    /// 目标模块。
    let module: CopyModule
    /// 当前业务场景标识。
    let scene: String
    /// 目标槽位。
    let slot: CopySlot
    /// 条目 ID；用于稳定选词与后续反重复记忆。
    let itemID: UUID?
    /// 条目名称；会自动注入模板变量，减少调用端重复传值。
    let itemName: String
    /// 一级品类。
    let primaryCategory: ItemPrimaryCategory
    /// 二级品类。
    let secondaryCategory: ItemSecondaryCategory
    /// 行为标签集合。
    let behaviorTags: [ItemBehaviorTag]
    /// 当前场景允许的最高强度。
    let intensityCap: CopyIntensity
    /// 是否允许命中随机型文案。
    let allowRandom: Bool
    /// 是否需要参与文案历史读写；纯展示型文案应关闭，避免在 `body` 重绘时产生持久化副作用。
    let usesMemory: Bool
    /// 模板渲染变量表。
    let variables: [String: String]

    /// 初始化文案上下文，并把通用字段自动注入模板变量，避免调用端重复维护同一份数据。
    /// - Parameters:
    ///   - module: 文案所属业务模块。
    ///   - scene: 当前业务场景标识。
    ///   - slot: 当前需要解析的槽位。
    ///   - itemID: 可选条目 ID，用于稳定选择与记忆。
    ///   - itemName: 条目名称；默认空字符串，适配空状态等无条目场景。
    ///   - primaryCategory: 一级品类；默认 `.other`，保证上下文可保守降级。
    ///   - secondaryCategory: 二级品类；默认 `.other`。
    ///   - behaviorTags: 行为标签集合。
    ///   - intensityCap: 当前场景允许的最高文案强度。
    ///   - allowRandom: 是否允许随机型文案参与候选。
    ///   - usesMemory: 是否需要参与最近文案历史读写；默认开启，纯展示型场景可显式关闭。
    ///   - variables: 额外模板变量；会与 itemName / itemID / scene 自动合并。
    init(
        module: CopyModule,
        scene: String,
        slot: CopySlot,
        itemID: UUID? = nil,
        itemName: String = "",
        primaryCategory: ItemPrimaryCategory = .other,
        secondaryCategory: ItemSecondaryCategory = .other,
        behaviorTags: [ItemBehaviorTag] = [],
        intensityCap: CopyIntensity = .high,
        allowRandom: Bool = true,
        usesMemory: Bool = true,
        variables: [String: String] = [:]
    ) {
        var mergedVariables = variables

        // 通用字段优先自动补齐，调用端仍可通过显式 variables 覆盖特殊值。
        if mergedVariables["scene"] == nil {
            mergedVariables["scene"] = scene
        }
        if !itemName.isEmpty, mergedVariables["itemName"] == nil {
            mergedVariables["itemName"] = itemName
        }
        if let itemID, mergedVariables["itemID"] == nil {
            mergedVariables["itemID"] = itemID.uuidString
        }

        self.module = module
        self.scene = scene
        self.slot = slot
        self.itemID = itemID
        self.itemName = itemName
        self.primaryCategory = primaryCategory
        self.secondaryCategory = secondaryCategory
        self.behaviorTags = behaviorTags
        self.intensityCap = intensityCap
        self.allowRandom = allowRandom
        self.usesMemory = usesMemory
        self.variables = mergedVariables
    }
}
