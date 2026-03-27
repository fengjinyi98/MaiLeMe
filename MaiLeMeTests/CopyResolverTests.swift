import XCTest
@testable import MaiLeMe

/// 验证文案解析器能根据场景、品类与行为标签选择最合适的候选，并避免误命中兜底结果。
final class CopyResolverTests: XCTestCase {
    /// 构建一个最小可控的测试文案库，确保测试只关注 resolver 打分逻辑，不依赖外部资源文件细节。
    /// - Returns: 注入测试内存存储后的 `CopyResolver` 实例。
    private func makeResolver() -> CopyResolver {
        let library = CopyLibrary(entries: [
            RoastCopyEntry(
                id: "decision_saved_title_generic_001",
                module: .decision,
                slot: .title,
                scene: ["decision_saved"],
                tone: .neutral,
                intensity: .medium,
                stability: .rotating,
                template: "先稳住，别急着庆祝。",
                variables: [],
                categoryInclude: [],
                categoryExclude: [],
                behaviorInclude: [],
                behaviorExclude: [],
                weight: 100
            ),
            RoastCopyEntry(
                id: "decision_saved_title_office_001",
                module: .decision,
                slot: .title,
                scene: ["decision_saved"],
                tone: .warm,
                intensity: .medium,
                stability: .rotating,
                template: "{{itemName}} 先别下单，这波克制更像高手。",
                variables: ["itemName"],
                categoryInclude: [.office],
                categoryExclude: [],
                behaviorInclude: [.efficiencyFantasy, .selfImprovement],
                behaviorExclude: [],
                weight: 120
            ),
            RoastCopyEntry(
                id: "decision_fallback_title_001",
                module: .decision,
                slot: .title,
                scene: ["fallback_title"],
                tone: .neutral,
                intensity: .low,
                stability: .stable,
                template: "先冷静。",
                variables: [],
                categoryInclude: [],
                categoryExclude: [],
                behaviorInclude: [],
                behaviorExclude: [],
                weight: 1
            )
        ])
        let defaults = UserDefaults(suiteName: "CopyResolverTests")!
        defaults.removePersistentDomain(forName: "CopyResolverTests")
        let memoryStore = CopyMemoryStore(defaults: defaults)
        return CopyResolver(library: library, memoryStore: memoryStore)
    }

    /// 当上下文同时命中场景、一级品类与行为标签时，解析器应优先选中更贴合的文案，而不是泛化候选或兜底候选。
    func test_resolver_prefers_category_and_behavior_matched_entries() throws {
        let resolver = makeResolver()
        let context = CopyContext(
            module: .decision,
            scene: "decision_saved",
            slot: .title,
            itemID: UUID(uuidString: "11111111-1111-1111-1111-111111111111"),
            itemName: "Apple Mac mini M4",
            primaryCategory: .office,
            secondaryCategory: .desktopComputer,
            behaviorTags: [.efficiencyFantasy, .selfImprovement],
            intensityCap: .medium,
            allowRandom: true
        )

        let resolved = try resolver.resolveSingle(context)
        XCTAssertEqual(resolved.id, "decision_saved_title_office_001")
        XCTAssertEqual(resolved.text, "Apple Mac mini M4 先别下单，这波克制更像高手。")
        XCTAssertEqual(resolved.isFallback, false)
    }
}
