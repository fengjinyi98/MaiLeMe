import XCTest
@testable import MaiLeMe

/// 验证文案解析器能根据场景、品类与行为标签选择最合适的候选，并避免误命中兜底结果。
final class CopyResolverTests: XCTestCase {
    /// 构建测试用条目，避免每个用例重复手写大段初始化代码。
    /// - Parameters:
    ///   - id: `String`，文案资源 ID。
    ///   - scene: `[String]`，条目支持的场景列表。
    ///   - tone: `CopyTone`，文案语气。
    ///   - intensity: `CopyIntensity`，文案强度。
    ///   - stability: `CopyStability`，文案稳定性。
    ///   - template: `String`，文案模板。
    ///   - variables: `[String]`，模板需要的变量名。
    ///   - categoryInclude: `[ItemPrimaryCategory]`，允许命中的一级品类。
    ///   - categoryExclude: `[ItemPrimaryCategory]`，禁止命中的一级品类。
    ///   - behaviorInclude: `[ItemBehaviorTag]`，要求命中的行为标签。
    ///   - behaviorExclude: `[ItemBehaviorTag]`，禁止命中的行为标签。
    ///   - weight: `Int`，基础权重。
    /// - Returns: `RoastCopyEntry`，可直接注入测试文案库的条目。
    private func makeEntry(
        id: String,
        scene: [String],
        tone: CopyTone = .neutral,
        intensity: CopyIntensity = .medium,
        stability: CopyStability = .rotating,
        template: String,
        variables: [String] = [],
        categoryInclude: [ItemPrimaryCategory] = [],
        categoryExclude: [ItemPrimaryCategory] = [],
        behaviorInclude: [ItemBehaviorTag] = [],
        behaviorExclude: [ItemBehaviorTag] = [],
        weight: Int = 100
    ) -> RoastCopyEntry {
        RoastCopyEntry(
            id: id,
            module: .decision,
            slot: .title,
            scene: scene,
            tone: tone,
            intensity: intensity,
            stability: stability,
            template: template,
            variables: variables,
            categoryInclude: categoryInclude,
            categoryExclude: categoryExclude,
            behaviorInclude: behaviorInclude,
            behaviorExclude: behaviorExclude,
            weight: weight
        )
    }

    /// 构建一个最小可控的测试文案库，并返回可预写 recent history 的记忆层。
    /// - Parameters:
    ///   - entries: `[RoastCopyEntry]`，测试用文案条目。
    ///   - suiteName: `String`，当前测试使用的独立 `UserDefaults` suite。
    /// - Returns: `(CopyResolver, CopyMemoryStore)`，用于断言选择结果与预写历史。
    private func makeResolver(
        entries: [RoastCopyEntry],
        suiteName: String
    ) -> (resolver: CopyResolver, memoryStore: CopyMemoryStore) {
        let library = CopyLibrary(entries: entries)
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let memoryStore = CopyMemoryStore(defaults: defaults)
        let resolver = CopyResolver(library: library, memoryStore: memoryStore)
        return (resolver, memoryStore)
    }

    /// 构建默认的决策场景上下文，避免测试对无关字段重复赋值。
    /// - Parameter scene: `String`，当前业务场景。
    /// - Returns: `CopyContext`，用于调用 resolver 的测试上下文。
    private func makeDecisionContext(scene: String) -> CopyContext {
        CopyContext(
            module: .decision,
            scene: scene,
            slot: .title,
            itemID: UUID(uuidString: "11111111-1111-1111-1111-111111111111"),
            itemName: "Apple Mac mini M4",
            primaryCategory: .office,
            secondaryCategory: .desktopComputer,
            behaviorTags: [.efficiencyFantasy, .selfImprovement],
            intensityCap: .medium,
            allowRandom: true
        )
    }

    /// 当上下文同时命中场景、一级品类与行为标签时，解析器应优先选中更贴合的文案，而不是泛化候选或兜底候选。
    func test_resolver_prefers_category_and_behavior_matched_entries() throws {
        let (resolver, _) = makeResolver(
            entries: [
                makeEntry(
                    id: "decision_saved_title_generic_001",
                    scene: ["decision_saved"],
                    template: "先稳住，别急着庆祝。"
                ),
                makeEntry(
                    id: "decision_saved_title_office_001",
                    scene: ["decision_saved"],
                    tone: .warm,
                    template: "{{itemName}} 先别下单，这波克制更像高手。",
                    variables: ["itemName"],
                    categoryInclude: [.office],
                    behaviorInclude: [.efficiencyFantasy, .selfImprovement],
                    weight: 120
                ),
                makeEntry(
                    id: "decision_fallback_title_001",
                    scene: ["fallback_title"],
                    intensity: .low,
                    stability: .stable,
                    template: "先冷静。",
                    weight: 1
                )
            ],
            suiteName: #function
        )
        let context = makeDecisionContext(scene: "decision_saved")

        let resolved = try resolver.resolveSingle(context)
        XCTAssertEqual(resolved.id, "decision_saved_title_office_001")
        XCTAssertEqual(resolved.text, "Apple Mac mini M4 先别下单，这波克制更像高手。")
        XCTAssertEqual(resolved.isFallback, false)
    }

    /// 首次使用且不是当天开箱、也还没拖到一个月时，解释器应命中与资源对齐的 `first_use_normal` 场景。
    func test_scenario_interpreter_returns_first_use_normal_for_first_use_between_day_one_and_twenty_nine() {
        let scene = CopyScenarioInterpreter().checkinScene(
            idleDays: 10,
            usageCount: 0,
            isFirstUse: true
        )

        XCTAssertEqual(scene, "first_use_normal")
    }

    /// 当 exact scene 缺失时，解析器应优先使用 bare `default` 候选，而不是回退到任意 unrelated 候选。
    func test_resolver_prefers_default_candidate_when_exact_scene_is_missing() throws {
        let (resolver, _) = makeResolver(
            entries: [
                makeEntry(
                    id: "decision_title_default_001",
                    scene: ["default"],
                    tone: .warm,
                    intensity: .low,
                    stability: .stable,
                    template: "先默认冷静一下。",
                    weight: 10
                ),
                makeEntry(
                    id: "decision_title_unrelated_001",
                    scene: ["legacy_scene"],
                    template: "和你现在的场景没关系，但分数故意很高。",
                    categoryInclude: [.office],
                    behaviorInclude: [.efficiencyFantasy, .selfImprovement],
                    weight: 500
                )
            ],
            suiteName: #function
        )

        let resolved = try resolver.resolveSingle(makeDecisionContext(scene: "decision_missing"))
        XCTAssertEqual(resolved.id, "decision_title_default_001")
        XCTAssertEqual(resolved.isFallback, true)
    }

    /// 当 exact scene 缺失且存在 `fallback*` 候选时，解析器应先锁定 fallback 层，而不是让 unrelated 高权重条目挤掉它。
    func test_resolver_prefers_fallback_candidate_when_exact_scene_is_missing() throws {
        let (resolver, _) = makeResolver(
            entries: [
                makeEntry(
                    id: "decision_fallback_title_001",
                    scene: ["fallback_title"],
                    tone: .warm,
                    intensity: .low,
                    stability: .stable,
                    template: "先别买，先喘口气。",
                    weight: 40
                ),
                makeEntry(
                    id: "decision_title_unrelated_002",
                    scene: ["legacy_scene"],
                    template: "这句其实不该在这里出现。",
                    categoryInclude: [.office],
                    behaviorInclude: [.efficiencyFantasy, .selfImprovement],
                    weight: 500
                )
            ],
            suiteName: #function
        )

        let resolved = try resolver.resolveSingle(makeDecisionContext(scene: "decision_missing"))
        XCTAssertEqual(resolved.id, "decision_fallback_title_001")
        XCTAssertEqual(resolved.isFallback, true)
    }

    /// rotating 文案若刚刚出现过，应优先切到另一句同层候选，避免连续两次刷到同一句。
    func test_resolver_rotates_away_from_recent_copy_id_when_alternative_exists() throws {
        let entries = [
            makeEntry(
                id: "decision_saved_title_recent_001",
                scene: ["decision_saved"],
                template: "刚刚用过的那一句。",
                weight: 120
            ),
            makeEntry(
                id: "decision_saved_title_fresh_001",
                scene: ["decision_saved"],
                template: "应该轮到这一句了。",
                weight: 120
            )
        ]
        let (resolver, memoryStore) = makeResolver(entries: entries, suiteName: #function)
        memoryStore.record(
            copyID: "decision_saved_title_recent_001",
            module: .decision,
            scene: "decision_saved",
            slot: .title,
            itemID: nil,
            tone: .neutral,
            intensity: .medium
        )

        let resolved = try resolver.resolveSingle(makeDecisionContext(scene: "decision_saved"))
        XCTAssertEqual(resolved.id, "decision_saved_title_fresh_001")
    }
}
