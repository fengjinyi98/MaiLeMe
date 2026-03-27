import Foundation

/// 单条文案资源校验问题：把“哪条配置错了、为什么错”结构化输出，便于测试与文档工具复用。
enum CopyAssetValidationIssue: Error, Equatable, CustomStringConvertible {
    /// 同一份文案库中出现重复 ID，会导致记忆层与埋点语义冲突。
    case duplicateID(String)
    /// 资源文件所属模块与条目内声明的模块不一致，说明文案被放错文件或复制时忘记改模块。
    case moduleMismatch(entryID: String, expected: CopyModule, actual: CopyModule)
    /// 某个模块文件被解码成功但没有任何文案，通常意味着资源发布不完整。
    case moduleHasNoEntries(CopyModule)
    /// scene 不能为空数组，否则 resolver 永远无法命中该条目。
    case emptySceneList(entryID: String)
    /// scene 中存在空字符串，说明资源录入时留下了脏值。
    case blankScene(entryID: String)
    /// 同一条目里重复声明 scene，会增加维护噪音且容易误导编辑者。
    case duplicateScene(entryID: String, scene: String)
    /// 模板正文不能为空，否则即使命中也无法展示给用户。
    case emptyTemplate(entryID: String)
    /// 变量声明中存在空字符串，说明编辑时留下了无意义占位。
    case blankVariable(entryID: String)
    /// 同一变量被重复声明，会让编辑器与校验结果产生歧义。
    case duplicateVariable(entryID: String, variable: String)
    /// 模板中真实使用的变量集合与声明集合不一致，会导致渲染时丢值或维护者误判。
    case variableMismatch(entryID: String, declared: [String], referenced: [String])
    /// 一级品类同时出现在 include / exclude 中，会让过滤语义自相矛盾。
    case categoryConflict(entryID: String, category: ItemPrimaryCategory)
    /// 行为标签同时出现在 include / exclude 中，会让过滤语义自相矛盾。
    case behaviorConflict(entryID: String, behavior: ItemBehaviorTag)
    /// 权重必须大于 0，否则排序和加权选择没有业务意义。
    case nonPositiveWeight(entryID: String, weight: Int)
    /// 某个运行时依赖的 module/slot/scene 组合在资源库中完全缺失，会导致兼容层静默退回 fallback。
    case missingRequiredCoverage(module: CopyModule, slot: CopySlot, scene: String)

    /// 问题描述：用于测试失败信息、调试输出与未来的编辑器提示。
    var description: String {
        switch self {
        case let .duplicateID(id):
            return "发现重复文案 ID：\(id)。"
        case let .moduleMismatch(entryID, expected, actual):
            return "条目 \(entryID) 的 module=\(actual.rawValue) 与资源文件期望模块 \(expected.rawValue) 不一致。"
        case let .moduleHasNoEntries(module):
            return "模块 \(module.rawValue) 没有任何文案条目。"
        case let .emptySceneList(entryID):
            return "条目 \(entryID) 的 scene 不能为空。"
        case let .blankScene(entryID):
            return "条目 \(entryID) 的 scene 中存在空字符串。"
        case let .duplicateScene(entryID, scene):
            return "条目 \(entryID) 重复声明了 scene：\(scene)。"
        case let .emptyTemplate(entryID):
            return "条目 \(entryID) 的 template 不能为空。"
        case let .blankVariable(entryID):
            return "条目 \(entryID) 的 variables 中存在空变量名。"
        case let .duplicateVariable(entryID, variable):
            return "条目 \(entryID) 重复声明了变量：\(variable)。"
        case let .variableMismatch(entryID, declared, referenced):
            return "条目 \(entryID) 的变量声明与模板引用不一致。declared=\(declared)，referenced=\(referenced)"
        case let .categoryConflict(entryID, category):
            return "条目 \(entryID) 的品类过滤冲突：\(category.rawValue) 同时出现在 include / exclude。"
        case let .behaviorConflict(entryID, behavior):
            return "条目 \(entryID) 的行为标签过滤冲突：\(behavior.rawValue) 同时出现在 include / exclude。"
        case let .nonPositiveWeight(entryID, weight):
            return "条目 \(entryID) 的 weight=\(weight)，必须大于 0。"
        case let .missingRequiredCoverage(module, slot, scene):
            return "资源库缺少必需覆盖：module=\(module.rawValue) slot=\(slot.rawValue) scene=\(scene)。"
        }
    }
}

/// 文案资源校验结果：集中暴露问题列表与有效性判断，便于测试、CLI 或编辑器复用。
struct CopyAssetValidationResult: Equatable {
    /// 所有校验问题；为空时表示通过。
    let issues: [CopyAssetValidationIssue]

    /// 当前资源是否完全合法。
    var isValid: Bool {
        issues.isEmpty
    }
}

/// 结构化文案资源校验器：负责在 resolver 运行前发现配置错误，避免线上才暴露“文案文件能解码但语义已坏”的问题。
struct CopyAssetValidator {
    /// 运行时强依赖的 scene/slot 矩阵：缺任意一项都会导致兼容层退回旧 fallback。
    private struct RequiredCoverage: Equatable {
        /// 文案模块。
        let module: CopyModule
        /// 文案槽位。
        let slot: CopySlot
        /// 需要存在的 scene。
        let scene: String
    }

    /// 变量占位符正则：匹配 `{{itemName}}`、`{{ idleDays }}` 这类模板变量。
    private static let variablePattern = #"\{\{\s*([A-Za-z0-9_]+)\s*\}\}"#
    /// 当前兼容层/核心流程所依赖的最小 scene/slot 覆盖矩阵。
    private static let requiredCoverageMatrix: [RequiredCoverage] = [
        .init(module: .notification, slot: .body, scene: "light_reminder"),
        .init(module: .notification, slot: .body, scene: "strong_reminder"),
        .init(module: .notification, slot: .body, scene: "cooldown_ready"),
        .init(module: .notification, slot: .body, scene: "cooldown_followup"),
        .init(module: .notification, slot: .body, scene: "rescue_followup"),
        .init(module: .decision, slot: .title, scene: "decision_saved"),
        .init(module: .decision, slot: .subtitle, scene: "decision_saved"),
        .init(module: .decision, slot: .actionTitle, scene: "decision_saved"),
        .init(module: .decision, slot: .roast, scene: "decision_saved"),
        .init(module: .decision, slot: .title, scene: "decision_purchased"),
        .init(module: .decision, slot: .subtitle, scene: "decision_purchased"),
        .init(module: .decision, slot: .actionTitle, scene: "decision_purchased"),
        .init(module: .decision, slot: .roast, scene: "decision_purchased"),
        .init(module: .checkin, slot: .title, scene: "first_use_immediate"),
        .init(module: .checkin, slot: .subtitle, scene: "first_use_immediate"),
        .init(module: .checkin, slot: .badge, scene: "first_use_immediate"),
        .init(module: .checkin, slot: .title, scene: "first_use_late"),
        .init(module: .checkin, slot: .subtitle, scene: "first_use_late"),
        .init(module: .checkin, slot: .badge, scene: "first_use_late"),
        .init(module: .checkin, slot: .title, scene: "first_use_normal"),
        .init(module: .checkin, slot: .subtitle, scene: "first_use_normal"),
        .init(module: .checkin, slot: .badge, scene: "first_use_normal"),
        .init(module: .checkin, slot: .title, scene: "revival_heavy"),
        .init(module: .checkin, slot: .subtitle, scene: "revival_heavy"),
        .init(module: .checkin, slot: .badge, scene: "revival_heavy"),
        .init(module: .checkin, slot: .title, scene: "revival_mid"),
        .init(module: .checkin, slot: .subtitle, scene: "revival_mid"),
        .init(module: .checkin, slot: .badge, scene: "revival_mid"),
        .init(module: .checkin, slot: .title, scene: "steady_high_usage"),
        .init(module: .checkin, slot: .subtitle, scene: "steady_high_usage"),
        .init(module: .checkin, slot: .badge, scene: "steady_high_usage"),
        .init(module: .checkin, slot: .title, scene: "checkin_default"),
        .init(module: .checkin, slot: .subtitle, scene: "checkin_default"),
        .init(module: .checkin, slot: .badge, scene: "checkin_default"),
        .init(module: .checkin, slot: .roast, scene: "first_use"),
        .init(module: .checkin, slot: .roast, scene: "big_moment"),
        .init(module: .checkin, slot: .roast, scene: "high_usage"),
        .init(module: .checkin, slot: .roast, scene: "default"),
        .init(module: .idleRescue, slot: .primary, scene: "primary_light"),
        .init(module: .idleRescue, slot: .primary, scene: "primary_warm"),
        .init(module: .idleRescue, slot: .primary, scene: "primary_mid"),
        .init(module: .idleRescue, slot: .primary, scene: "primary_heavy"),
        .init(module: .idleRescue, slot: .primary, scene: "primary_severe"),
        .init(module: .idleRescue, slot: .primary, scene: "primary_extreme"),
        .init(module: .idleRescue, slot: .secondary, scene: "secondary_never_used"),
        .init(module: .idleRescue, slot: .secondary, scene: "secondary_heavy"),
        .init(module: .idleRescue, slot: .secondary, scene: "secondary_default"),
        .init(module: .savedReview, slot: .title, scene: "headline_low"),
        .init(module: .savedReview, slot: .title, scene: "headline_mid"),
        .init(module: .savedReview, slot: .title, scene: "headline_high"),
        .init(module: .savedReview, slot: .title, scene: "headline_huge"),
        .init(module: .savedReview, slot: .body, scene: "body_short_cooldown"),
        .init(module: .savedReview, slot: .body, scene: "body_mid_cooldown"),
        .init(module: .savedReview, slot: .body, scene: "body_long_cooldown"),
        .init(module: .emptyState, slot: .body, scene: "dark_room_empty"),
        .init(module: .emptyState, slot: .body, scene: "extractor_empty"),
        .init(module: .share, slot: .body, scene: "decision_saved_outcome"),
        .init(module: .share, slot: .body, scene: "decision_purchased_outcome"),
        .init(module: .share, slot: .body, scene: "checkin_share_closing")
    ]

    /// 校验主 bundle 中的全部文案模块。
    /// - Parameter bundle: `Bundle`，默认使用主 bundle。
    /// - Returns: `CopyAssetValidationResult`，包含所有发现的问题。
    /// - Throws: 当资源文件缺失或 JSON 本身无法解码时，沿用 loader 抛错，方便快速定位资源发布问题。
    func validate(bundle: Bundle = .main) throws -> CopyAssetValidationResult {
        let loader = CopyLibraryLoader(bundle: bundle)
        let moduleEntries = try CopyModule.allCases.map { module in
            (module: module, entries: try loader.loadEntries(for: module))
        }
        return validate(
            moduleEntries: moduleEntries,
            requireAllModules: true,
            enforceRequiredCoverage: true
        )
    }

    /// 校验已经加载完成的整库文案。
    /// - Parameter library: `CopyLibrary`，待校验的文案库。
    /// - Returns: `CopyAssetValidationResult`，包含所有发现的问题。
    func validate(
        library: CopyLibrary,
        enforceRequiredCoverage: Bool = false
    ) -> CopyAssetValidationResult {
        let groupedEntries = Dictionary(grouping: library.entries, by: \.module)
            .map { (module: $0.key, entries: $0.value) }
            .sorted { $0.module.resourceFileName < $1.module.resourceFileName }
        return validate(
            moduleEntries: groupedEntries,
            requireAllModules: false,
            enforceRequiredCoverage: enforceRequiredCoverage
        )
    }

    /// 校验某个模块文件中的条目集合。
    /// - Parameters:
    ///   - entries: `[RoastCopyEntry]`，待校验的条目数组。
    ///   - expectedModule: `CopyModule?`，若传入则额外检查条目 module 是否与文件归属一致。
    /// - Returns: `CopyAssetValidationResult`，包含问题列表。
    func validate(
        entries: [RoastCopyEntry],
        expectedModule: CopyModule? = nil
    ) -> CopyAssetValidationResult {
        validateSingleCollection(entries, expectedModule: expectedModule)
    }

    /// 核心校验入口：用于同时保留“逐模块校验”与“跨模块去重”能力。
    /// - Parameter moduleEntries: `[(module: CopyModule, entries: [RoastCopyEntry])]`，每个模块对应的条目集合。
    /// - Returns: `CopyAssetValidationResult`，聚合后的全部问题。
    private func validate(
        moduleEntries: [(module: CopyModule, entries: [RoastCopyEntry])],
        requireAllModules: Bool,
        enforceRequiredCoverage: Bool
    ) -> CopyAssetValidationResult {
        var issues: [CopyAssetValidationIssue] = []

        for (module, entries) in moduleEntries {
            if requireAllModules && entries.isEmpty {
                issues.append(.moduleHasNoEntries(module))
            }
            issues.append(contentsOf: validateSingleCollection(entries, expectedModule: module).issues)
        }

        let allEntries = moduleEntries.flatMap(\.entries)
        let duplicatedIDs = Dictionary(grouping: allEntries, by: \.id)
            .filter { $0.value.count > 1 }
            .keys
            .sorted()

        issues.append(contentsOf: duplicatedIDs.map(CopyAssetValidationIssue.duplicateID))

        if enforceRequiredCoverage {
            issues.append(contentsOf: missingCoverageIssues(in: allEntries))
        }
        return CopyAssetValidationResult(issues: issues)
    }

    /// 校验单个条目集合中的字段合法性。
    /// - Parameters:
    ///   - entries: `[RoastCopyEntry]`，待校验的条目数组。
    ///   - expectedModule: `CopyModule?`，若存在则校验 module 一致性。
    /// - Returns: `CopyAssetValidationResult`，当前集合内的问题。
    private func validateSingleCollection(
        _ entries: [RoastCopyEntry],
        expectedModule: CopyModule?
    ) -> CopyAssetValidationResult {
        var issues: [CopyAssetValidationIssue] = []

        for entry in entries {
            if let expectedModule, entry.module != expectedModule {
                issues.append(
                    .moduleMismatch(
                        entryID: entry.id,
                        expected: expectedModule,
                        actual: entry.module
                    )
                )
            }

            if entry.scene.isEmpty {
                issues.append(.emptySceneList(entryID: entry.id))
            }

            var seenScenes = Set<String>()
            for rawScene in entry.scene {
                let scene = rawScene.trimmingCharacters(in: .whitespacesAndNewlines)
                if scene.isEmpty {
                    issues.append(.blankScene(entryID: entry.id))
                    continue
                }
                if !seenScenes.insert(scene).inserted {
                    issues.append(.duplicateScene(entryID: entry.id, scene: scene))
                }
            }

            if entry.template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.emptyTemplate(entryID: entry.id))
            }

            var seenVariables = Set<String>()
            let normalizedDeclaredVariables = entry.variables.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            for variable in normalizedDeclaredVariables {
                if variable.isEmpty {
                    issues.append(.blankVariable(entryID: entry.id))
                    continue
                }
                if !seenVariables.insert(variable).inserted {
                    issues.append(.duplicateVariable(entryID: entry.id, variable: variable))
                }
            }

            let referencedVariables = referencedVariables(in: entry.template)
            let declaredVariableSet = Set(normalizedDeclaredVariables.filter { !$0.isEmpty })
            let referencedVariableSet = Set(referencedVariables)
            if declaredVariableSet != referencedVariableSet {
                issues.append(
                    .variableMismatch(
                        entryID: entry.id,
                        declared: declaredVariableSet.sorted(),
                        referenced: referencedVariableSet.sorted()
                    )
                )
            }

            let categoryConflicts = Set(entry.categoryInclude).intersection(Set(entry.categoryExclude))
            issues.append(
                contentsOf: categoryConflicts
                    .sorted { $0.rawValue < $1.rawValue }
                    .map { .categoryConflict(entryID: entry.id, category: $0) }
            )

            let behaviorConflicts = Set(entry.behaviorInclude).intersection(Set(entry.behaviorExclude))
            issues.append(
                contentsOf: behaviorConflicts
                    .sorted { $0.rawValue < $1.rawValue }
                    .map { .behaviorConflict(entryID: entry.id, behavior: $0) }
            )

            if entry.weight <= 0 {
                issues.append(.nonPositiveWeight(entryID: entry.id, weight: entry.weight))
            }
        }

        return CopyAssetValidationResult(issues: issues)
    }

    /// 从模板中提取所有变量名。
    /// - Parameter template: `String`，包含 `{{variable}}` 占位符的模板。
    /// - Returns: `[String]`，按出现顺序抽取出的变量名。
    private func referencedVariables(in template: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: Self.variablePattern) else {
            assertionFailure("CopyAssetValidator 变量正则构造失败。")
            return []
        }

        let range = NSRange(template.startIndex..<template.endIndex, in: template)
        return expression.matches(in: template, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let variableRange = Range(match.range(at: 1), in: template) else {
                return nil
            }
            return String(template[variableRange])
        }
    }

    /// 计算运行时必需的 scene/slot 覆盖缺口。
    /// - Parameter entries: `[RoastCopyEntry]`，整库条目。
    /// - Returns: `[CopyAssetValidationIssue]`，所有缺失的必需覆盖项。
    private func missingCoverageIssues(in entries: [RoastCopyEntry]) -> [CopyAssetValidationIssue] {
        Self.requiredCoverageMatrix.compactMap { requirement in
            let hasCoverage = entries.contains { entry in
                entry.module == requirement.module &&
                entry.slot == requirement.slot &&
                entry.scene.contains(requirement.scene)
            }

            guard !hasCoverage else {
                return nil
            }

            return .missingRequiredCoverage(
                module: requirement.module,
                slot: requirement.slot,
                scene: requirement.scene
            )
        }
    }
}
