import Foundation

/// 场景解释器：把打卡侧的原始使用信号映射成文案系统可消费的字符串场景 ID。
struct CopyScenarioInterpreter {
    /// 根据闲置天数、累计使用次数与是否首次使用，推导当前应命中的打卡场景。
    /// - Parameters:
    ///   - idleDays: `Int`，距上次使用的闲置天数。
    ///   - usageCount: `Int`，累计使用次数。
    ///   - isFirstUse: `Bool`，当前是否属于首次使用。
    /// - Returns: `String`，供文案资源 `scene` 字段直接匹配的场景标识。
    /// - Note: 当前实现严格遵循 Task 6 给定的最小规则集，暂不引入额外推断分支。
    func checkinScene(idleDays: Int, usageCount: Int, isFirstUse: Bool) -> String {
        if isFirstUse && idleDays == 0 { return "first_use_immediate" }
        if isFirstUse && idleDays >= 30 { return "first_use_late" }
        // 首次使用但尚未拖到一个月时，需要与现有资源中的 `first_use_normal` 场景对齐。
        if isFirstUse && (1...29).contains(idleDays) { return "first_use_normal" }
        if idleDays >= 30 { return "revival_heavy" }
        if idleDays >= 7 { return "revival_mid" }
        if usageCount >= 10 { return "steady_high_usage" }
        return "checkin_default"
    }
}
