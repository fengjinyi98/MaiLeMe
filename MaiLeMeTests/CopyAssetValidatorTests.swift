import XCTest
@testable import MaiLeMe

/// 验证结构化文案资源校验器能及时拦住模块错放、变量错配与过滤规则冲突。
final class CopyAssetValidatorTests: XCTestCase {
    /// 构造测试用文案条目，避免每个用例重复拼装完整模型。
    /// - Parameters:
    ///   - id: `String`，条目唯一标识。
    ///   - module: `CopyModule`，文案模块。
    ///   - slot: `CopySlot`，文案槽位。
    ///   - scene: `[String]`，命中场景。
    ///   - template: `String`，模板文本。
    ///   - variables: `[String]`，声明变量。
    ///   - categoryInclude: `[ItemPrimaryCategory]`，一级品类白名单。
    ///   - categoryExclude: `[ItemPrimaryCategory]`，一级品类黑名单。
    ///   - behaviorInclude: `[ItemBehaviorTag]`，行为标签白名单。
    ///   - behaviorExclude: `[ItemBehaviorTag]`，行为标签黑名单。
    ///   - weight: `Int`，候选权重。
    /// - Returns: `RoastCopyEntry`，用于注入校验器的测试数据。
    private func makeEntry(
        id: String,
        module: CopyModule = .notification,
        slot: CopySlot = .body,
        scene: [String] = ["light_reminder"],
        template: String = "{{itemName}} 已经 {{idleDays}} 天没用了。",
        variables: [String] = ["itemName", "idleDays"],
        categoryInclude: [ItemPrimaryCategory] = [],
        categoryExclude: [ItemPrimaryCategory] = [],
        behaviorInclude: [ItemBehaviorTag] = [],
        behaviorExclude: [ItemBehaviorTag] = [],
        weight: Int = 100
    ) -> RoastCopyEntry {
        RoastCopyEntry(
            id: id,
            module: module,
            slot: slot,
            scene: scene,
            tone: .dry,
            intensity: .medium,
            stability: .stable,
            template: template,
            variables: variables,
            categoryInclude: categoryInclude,
            categoryExclude: categoryExclude,
            behaviorInclude: behaviorInclude,
            behaviorExclude: behaviorExclude,
            weight: weight
        )
    }

    /// 主 bundle 中现有文案资源应整体通过校验，证明当前 JSON 文件与 resolver 契约一致。
    func test_validator_accepts_current_bundle_assets() throws {
        let result = try CopyAssetValidator().validate(bundle: .main)

        XCTAssertTrue(result.isValid, "当前资源不应存在校验问题：\(result.issues)")
        XCTAssertTrue(result.issues.isEmpty)
    }

    /// 同一份文案库中若出现重复 ID，校验器应直接报错，防止记忆层把两条文案当成同一条。
    func test_validator_rejects_duplicate_ids_across_library() {
        let duplicateA = makeEntry(id: "duplicate_id")
        let duplicateB = makeEntry(
            id: "duplicate_id",
            module: .share,
            scene: ["decision_saved_outcome"],
            template: "冷静期成功忍住没买，直接省下一笔。",
            variables: []
        )

        let result = CopyAssetValidator().validate(
            library: CopyLibrary(entries: [duplicateA, duplicateB])
        )

        XCTAssertEqual(result.issues, [.duplicateID("duplicate_id")])
    }

    /// 若条目被放进错误模块文件，校验器应能指出“文件归属”和“条目声明”不一致。
    func test_validator_rejects_module_mismatch_for_module_file() {
        let misplacedEntry = makeEntry(
            id: "share_entry_in_notification_file",
            module: .share,
            scene: ["decision_saved_outcome"],
            template: "冷静期成功忍住没买，直接省下一笔。",
            variables: []
        )

        let result = CopyAssetValidator().validate(
            entries: [misplacedEntry],
            expectedModule: .notification
        )

        XCTAssertEqual(
            result.issues,
            [
                .moduleMismatch(
                    entryID: "share_entry_in_notification_file",
                    expected: .notification,
                    actual: .share
                )
            ]
        )
    }

    /// 模板变量声明与真实占位符不一致时，校验器应拦截，避免运行期才发现变量没被替换。
    func test_validator_rejects_variable_mismatch_and_filter_conflicts() {
        let invalidEntry = makeEntry(
            id: "invalid_variable_and_filters",
            template: "{{itemName}} 买来是为了提升效率。",
            variables: ["itemName", "idleDays"],
            categoryInclude: [.office],
            categoryExclude: [.office],
            behaviorInclude: [.efficiencyFantasy],
            behaviorExclude: [.efficiencyFantasy],
            weight: 0
        )

        let result = CopyAssetValidator().validate(entries: [invalidEntry], expectedModule: .notification)

        XCTAssertEqual(
            result.issues,
            [
                .variableMismatch(
                    entryID: "invalid_variable_and_filters",
                    declared: ["idleDays", "itemName"],
                    referenced: ["itemName"]
                ),
                .categoryConflict(entryID: "invalid_variable_and_filters", category: .office),
                .behaviorConflict(entryID: "invalid_variable_and_filters", behavior: .efficiencyFantasy),
                .nonPositiveWeight(entryID: "invalid_variable_and_filters", weight: 0)
            ]
        )
    }

    /// 若删除运行时强依赖的 scene/slot 覆盖，校验器应明确报出缺口，而不是默默允许 fallback 顶上。
    func test_validator_reports_missing_required_scene_slot_coverage() throws {
        let library = try CopyLibraryLoader(bundle: .main).load()
        let prunedLibrary = CopyLibrary(
            entries: library.entries.filter { entry in
                !(entry.module == .share &&
                  entry.slot == .body &&
                  entry.scene.contains("checkin_share_closing"))
            }
        )

        let result = CopyAssetValidator().validate(
            library: prunedLibrary,
            enforceRequiredCoverage: true
        )

        XCTAssertTrue(
            result.issues.contains(
                .missingRequiredCoverage(
                    module: .share,
                    slot: .body,
                    scene: "checkin_share_closing"
                )
            )
        )
    }

    /// 空模块、空 scene、空模板与重复变量都应被标记，防止编辑器保存出“能解码但永远命不中”的资源。
    func test_validator_rejects_blank_metadata_in_single_collection() {
        let invalidEntry = makeEntry(
            id: "blank_metadata",
            scene: ["", "light_reminder", "light_reminder"],
            template: "   ",
            variables: ["itemName", "", "itemName"]
        )

        let result = CopyAssetValidator().validate(
            entries: [invalidEntry],
            expectedModule: .notification
        )

        XCTAssertEqual(
            result.issues,
            [
                .blankScene(entryID: "blank_metadata"),
                .duplicateScene(entryID: "blank_metadata", scene: "light_reminder"),
                .emptyTemplate(entryID: "blank_metadata"),
                .blankVariable(entryID: "blank_metadata"),
                .duplicateVariable(entryID: "blank_metadata", variable: "itemName"),
                .variableMismatch(
                    entryID: "blank_metadata",
                    declared: ["itemName"],
                    referenced: []
                )
            ]
        )
    }
}
