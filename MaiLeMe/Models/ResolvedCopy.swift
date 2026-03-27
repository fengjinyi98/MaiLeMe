import Foundation

/// 已完成候选筛选与模板渲染的最终文案结果，供 UI 或通知层直接消费。
struct ResolvedCopy: Equatable, Sendable {
    /// 命中的文案资产 ID。
    let id: String
    /// 渲染后的最终文本。
    let text: String
    /// 命中文案的语气标签。
    let tone: CopyTone
    /// 命中文案的强度标签。
    let intensity: CopyIntensity
    /// 是否来自兜底文案。
    let isFallback: Bool

    /// 初始化最终文案结果。
    /// - Parameters:
    ///   - id: 文案资产 ID。
    ///   - text: 渲染后的最终文本。
    ///   - tone: 命中的语气标签。
    ///   - intensity: 命中的强度标签。
    ///   - isFallback: 是否来自兜底候选。
    init(
        id: String,
        text: String,
        tone: CopyTone,
        intensity: CopyIntensity,
        isFallback: Bool
    ) {
        self.id = id
        self.text = text
        self.tone = tone
        self.intensity = intensity
        self.isFallback = isFallback
    }
}
