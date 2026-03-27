import Foundation

/// 文案解析失败错误：用于区分“候选为空”这类确定性失败，方便测试与调用方处理。
enum CopyResolutionError: LocalizedError, Equatable {
    /// 当前上下文下没有任何可用候选。
    case noCandidates

    var errorDescription: String? {
        switch self {
        case .noCandidates:
            return "当前上下文下没有可解析的文案候选。"
        }
    }
}

/// 文案解析器：根据上下文从文案库中打分选出最佳候选，并在返回前完成模板渲染与记忆写入。
final class CopyResolver {
    /// 已加载的文案库。
    private let library: CopyLibrary
    /// 文案记忆层，用于反重复打分。
    private let memoryStore: CopyMemoryStore

    /// 创建解析器实例。
    /// - Parameters:
    ///   - library: `CopyLibrary`，当前可用的结构化文案资产集合。
    ///   - memoryStore: `CopyMemoryStore`，用于记录最近命中的文案。
    init(library: CopyLibrary, memoryStore: CopyMemoryStore) {
        self.library = library
        self.memoryStore = memoryStore
    }

    /// 解析单条最终文案。
    /// - Parameter context: `CopyContext`，包含场景、品类、行为标签与模板变量等全部决策信息。
    /// - Returns: `ResolvedCopy`，已完成候选筛选、模板渲染和兜底标记的最终文案。
    /// - Throws: `CopyResolutionError.noCandidates`，当没有任何可用候选时抛出。
    func resolveSingle(_ context: CopyContext) throws -> ResolvedCopy {
        let candidates = library.entries.filter { entry in
            entry.module == context.module
                && entry.slot == context.slot
                && isAllowedByIntensity(entry, context: context)
                && isAllowedByRandomPolicy(entry, context: context)
                && isAllowedByExclusionRules(entry, context: context)
        }

        guard !candidates.isEmpty else {
            throw CopyResolutionError.noCandidates
        }

        let recentCopyIDs = Set(memoryStore.recentCopyIDs(module: context.module))
        let bestEntry = candidates
            .map { entry in
                (entry: entry, score: score(entry, context: context, recentCopyIDs: recentCopyIDs))
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                if lhs.entry.weight != rhs.entry.weight {
                    return lhs.entry.weight > rhs.entry.weight
                }
                return lhs.entry.id < rhs.entry.id
            }
            .first?
            .entry

        guard let bestEntry else {
            throw CopyResolutionError.noCandidates
        }

        let renderedText = render(bestEntry.template, with: context.variables)
        let result = ResolvedCopy(
            id: bestEntry.id,
            text: renderedText,
            tone: bestEntry.tone,
            intensity: bestEntry.intensity,
            isFallback: isFallbackEntry(bestEntry)
        )

        memoryStore.record(
            copyID: bestEntry.id,
            module: context.module,
            scene: context.scene,
            slot: context.slot,
            itemID: context.itemID,
            tone: bestEntry.tone,
            intensity: bestEntry.intensity
        )

        return result
    }

    /// 计算单条候选的综合分数。
    /// - Parameters:
    ///   - entry: `RoastCopyEntry`，待评分的文案条目。
    ///   - context: `CopyContext`，解析上下文。
    ///   - recentCopyIDs: `Set<String>`，当前模块最近命中过的文案 ID。
    /// - Returns: `Int`，分数越高越优先。
    private func score(
        _ entry: RoastCopyEntry,
        context: CopyContext,
        recentCopyIDs: Set<String>
    ) -> Int {
        var total = entry.weight

        // 场景是第一优先级：精确命中应显著领先；fallback 可在无精确场景时兜底；无关场景则明显降权。
        if entry.scene.contains(context.scene) {
            total += 1_000
        } else if isFallbackEntry(entry) {
            total += 150
        } else {
            total -= 250
        }

        // 一级品类与行为标签采用“软约束加分”策略：命中越多越优先，但不命中也允许退回泛化候选。
        if !entry.categoryInclude.isEmpty {
            total += entry.categoryInclude.contains(context.primaryCategory) ? 180 : -90
        }

        let matchedBehaviors = entry.behaviorInclude.filter { context.behaviorTags.contains($0) }
        if !entry.behaviorInclude.isEmpty {
            total += matchedBehaviors.count * 90
            if matchedBehaviors.count == entry.behaviorInclude.count {
                total += 40
            } else {
                total -= (entry.behaviorInclude.count - matchedBehaviors.count) * 45
            }
        }

        // 候选强度只要不超过 cap 就可参与；越接近 cap 的文案通常越贴合当前刺激级别。
        total += intensityAffinityScore(for: entry.intensity, cap: context.intensityCap)

        switch entry.stability {
        case .stable:
            total += 30
        case .semiStable:
            total += 10
        case .rotating:
            // rotating 文案若刚命中过，需要大幅降权，避免连续重复刷到同一句。
            total += recentCopyIDs.contains(entry.id) ? -220 : 15
        case .random:
            total += context.allowRandom ? 0 : -1_000
        }

        return total
    }

    /// 判断文案是否满足强度上限要求。
    /// - Parameters:
    ///   - entry: `RoastCopyEntry`，待校验候选。
    ///   - context: `CopyContext`，当前解析上下文。
    /// - Returns: `Bool`，`true` 表示该候选强度可接受。
    private func isAllowedByIntensity(_ entry: RoastCopyEntry, context: CopyContext) -> Bool {
        intensityRank(of: entry.intensity) <= intensityRank(of: context.intensityCap)
    }

    /// 判断文案是否符合随机策略开关。
    /// - Parameters:
    ///   - entry: `RoastCopyEntry`，待校验候选。
    ///   - context: `CopyContext`，当前解析上下文。
    /// - Returns: `Bool`，`true` 表示该候选未被随机策略禁用。
    private func isAllowedByRandomPolicy(_ entry: RoastCopyEntry, context: CopyContext) -> Bool {
        context.allowRandom || entry.stability != .random
    }

    /// 判断文案是否被显式排除规则拦截。
    /// - Parameters:
    ///   - entry: `RoastCopyEntry`，待校验候选。
    ///   - context: `CopyContext`，当前解析上下文。
    /// - Returns: `Bool`，`true` 表示没有命中任何硬性排除条件。
    private func isAllowedByExclusionRules(_ entry: RoastCopyEntry, context: CopyContext) -> Bool {
        guard !entry.categoryExclude.contains(context.primaryCategory) else {
            return false
        }

        let behaviorExclusionHit = !Set(entry.behaviorExclude).isDisjoint(with: context.behaviorTags)
        return !behaviorExclusionHit
    }

    /// 计算强度与上限之间的贴合度得分。
    /// - Parameters:
    ///   - intensity: `CopyIntensity`，候选文案强度。
    ///   - cap: `CopyIntensity`，当前场景允许的最高强度。
    /// - Returns: `Int`，越接近上限得分越高。
    private func intensityAffinityScore(for intensity: CopyIntensity, cap: CopyIntensity) -> Int {
        let distance = abs(intensityRank(of: cap) - intensityRank(of: intensity))
        return max(0, 30 - distance * 10)
    }

    /// 把强度枚举映射成可比较的整数等级。
    /// - Parameter intensity: `CopyIntensity`，待转换的强度值。
    /// - Returns: `Int`，从低到高依次为 0、1、2。
    private func intensityRank(of intensity: CopyIntensity) -> Int {
        switch intensity {
        case .low:
            return 0
        case .medium:
            return 1
        case .high:
            return 2
        }
    }

    /// 判断候选是否属于显式兜底文案。
    /// - Parameter entry: `RoastCopyEntry`，待判断候选。
    /// - Returns: `Bool`，`true` 表示其任一 scene 标识包含 `fallback`。
    private func isFallbackEntry(_ entry: RoastCopyEntry) -> Bool {
        entry.scene.contains { $0.localizedCaseInsensitiveContains("fallback") }
    }

    /// 渲染模板字符串中的占位符。
    /// - Parameters:
    ///   - template: `String`，原始模板，使用 `{{variableName}}` 作为占位格式。
    ///   - variables: `[String: String]`，变量名到渲染值的映射。
    /// - Returns: `String`，渲染后的最终文本；未知变量会被替换为空字符串。
    private func render(_ template: String, with variables: [String: String]) -> String {
        let pattern = #"\{\{\s*([A-Za-z0-9_]+)\s*\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return template
        }

        let nsRange = NSRange(template.startIndex..<template.endIndex, in: template)
        let matches = regex.matches(in: template, range: nsRange)
        var rendered = template

        // 倒序替换可以避免前面替换后的索引偏移影响后续匹配范围。
        for match in matches.reversed() {
            guard match.numberOfRanges == 2,
                  let keyRange = Range(match.range(at: 1), in: template),
                  let wholeRange = Range(match.range(at: 0), in: rendered) else {
                continue
            }

            let key = String(template[keyRange])
            let replacement = variables[key] ?? ""
            rendered.replaceSubrange(wholeRange, with: replacement)
        }

        return rendered
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
