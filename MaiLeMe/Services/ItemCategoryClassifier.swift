import Foundation

/// 条目分类结果：封装一级品类、二级品类与本次命中的置信度，供表单默认值与文案系统复用。
struct ItemCategoryResolution {
    /// 一级品类：用于更粗粒度的语义归桶。
    let primary: ItemPrimaryCategory
    /// 二级品类：用于命中更具体的商品类型。
    let secondary: ItemSecondaryCategory
    /// 置信度：表示当前规则命中的可靠程度。
    let confidence: CopyConfidence
}

/// 条目品类分类器：基于商品名中的关键词做本地轻量规则匹配，不依赖网络或模型推理。
struct ItemCategoryClassifier {
    /// 根据商品名称推断条目品类。
    /// - Parameter name: `String`，用户输入或外部同步得到的商品名称。
    /// - Returns: `ItemCategoryResolution`，包含一级品类、二级品类与命中置信度。
    /// - Note: 当前仅实现 Task 3 所需的最小规则，优先覆盖 SSD 与台式主机场景，并尽量保持保守。
    func classify(name: String) -> ItemCategoryResolution {
        let normalizedName = name.lowercased()

        // 固态硬盘通常会携带“固态 / SSD / NVMe”等核心关键词，命中后直接归为数码存储配件。
        if normalizedName.contains("固态")
            || normalizedName.contains("ssd")
            || normalizedName.contains("nvme") {
            return .init(primary: .digital, secondary: .ssd, confidence: .high)
        }

        // 台式办公主机需要更具体的词组命中，避免“空调主机 / 游戏主机”等宽泛表达被误判成电脑。
        if normalizedName.contains("mac mini")
            || normalizedName.contains("电脑主机")
            || normalizedName.contains("台式主机") {
            return .init(primary: .office, secondary: .desktopComputer, confidence: .high)
        }

        // 其余暂未命中的名称保守回落到 other，避免错误强化文案。
        return .init(primary: .other, secondary: .other, confidence: .low)
    }
}
