import XCTest
@testable import MaiLeMe

/// 验证文案解析器能根据场景、品类与行为标签选择最合适的候选，并避免误命中兜底结果。
final class CopyResolverTests: XCTestCase {
    /// 解析 `CopyMemoryStore` 写入到标准偏好中的最近命中文案记录，便于集成测试验证核心流程是否真的走了 resolver。
    private struct RecentCopyMemoryRecord: Decodable {
        /// 文案唯一 ID。
        let copyID: String
        /// 文案所属模块。
        let module: CopyModule
        /// 文案命中时的场景。
        let scene: String
        /// 文案槽位。
        let slot: CopySlot
        /// 关联条目 ID；若核心流程没有把条目语义透传进去，这里通常会是 `nil`。
        let itemID: UUID?
    }

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

    /// 清空标准 `UserDefaults` 中的最近文案历史，避免不同集成测试相互污染。
    private func clearStandardCopyMemory() {
        UserDefaults.standard.removeObject(forKey: "copy.memory.recent")
    }

    /// 读取标准 `UserDefaults` 中由 `CopyMemoryStore` 写入的最近文案历史。
    /// - Returns: `[RecentCopyMemoryRecord]`，按写入顺序解码后的历史记录。
    /// - Throws: 当底层 JSON 结构异常时抛出错误，帮助定位兼容层写入问题。
    private func loadStandardCopyMemoryRecords() throws -> [RecentCopyMemoryRecord] {
        guard let data = UserDefaults.standard.data(forKey: "copy.memory.recent") else {
            return []
        }
        return try JSONDecoder().decode([RecentCopyMemoryRecord].self, from: data)
    }

    /// 构造一个带有办公/台式机分类与效率幻觉标签的已购条目，用于验证核心流程是否把条目语义透传给 resolver。
    /// - Parameters:
    ///   - id: `UUID`，条目主键。
    ///   - purchaseAt: `Date`，购买时间。
    /// - Returns: `Item`，用于决策/打卡文案集成测试的样本条目。
    private func makeOfficeDesktopPurchasedItem(
        id: UUID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        purchaseAt: Date = Date(timeIntervalSince1970: 1_741_000_000)
    ) -> Item {
        Item(
            id: id,
            name: "Apple Mac mini M4",
            createdAt: purchaseAt,
            status: .purchased,
            wishPriceCents: 399_999,
            primaryCategoryRawValue: ItemPrimaryCategory.office.rawValue,
            secondaryCategoryRawValue: ItemSecondaryCategory.desktopComputer.rawValue,
            categorySourceRawValue: CopyCategorySource.userSelected.rawValue,
            categoryConfidenceRawValue: CopyConfidence.high.rawValue,
            behaviorTagsRawValue: [
                ItemBehaviorTag.efficiencyFantasy.rawValue,
                ItemBehaviorTag.selfImprovement.rawValue
            ],
            behaviorTagSourceRawValue: CopyTagSource.userAdjusted.rawValue,
            purchaseAt: purchaseAt,
            purchasePriceCents: 399_999,
            usageCount: 0
        )
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

    /// 旧版 `AppConstants.RoastCopy` 兼容 API 接入新引擎后，应能返回由 resolver 解析出的决策文案组合。
    func test_legacy_roast_copy_api_returns_resolved_copy_from_engine() {
        UserDefaults.standard.removeObject(forKey: "copy.memory.recent")

        let bundle = AppConstants.RoastCopy.decisionSavedBundle(
            itemName: "Apple Mac mini M4",
            itemID: UUID(uuidString: "11111111-1111-1111-1111-111111111111"),
            primaryCategory: .office,
            secondaryCategory: .desktopComputer,
            behaviorTags: [.efficiencyFantasy, .selfImprovement]
        )

        XCTAssertEqual(bundle.title, "理性胜利，冲动当场下线")
        XCTAssertEqual(bundle.subtitle, "你把“想买”变成了“省下”，这波自控力可以发朋友圈。")
        XCTAssertEqual(bundle.actionTitle, "继续克制")

        let recentDecisionCopyIDs = Set(CopyMemoryStore().recentCopyIDs(module: .decision))
        XCTAssertTrue(recentDecisionCopyIDs.contains("decision_saved_title_001"))
        XCTAssertTrue(recentDecisionCopyIDs.contains("decision_saved_subtitle_001"))
        XCTAssertTrue(recentDecisionCopyIDs.contains("decision_saved_action_001"))
    }

    /// 决策仪式 payload 应把条目 ID 与语义上下文透传给 resolver，确保标题/副标题/按钮/点评都来自 item-scoped 的新引擎。
    @MainActor
    func test_decision_payload_uses_item_category_context() throws {
        clearStandardCopyMemory()
        let item = makeOfficeDesktopPurchasedItem()

        let payload = DarkRoomViewModel().makeDecisionCelebration(
            for: item,
            outcome: .purchased
        )

        XCTAssertFalse(payload.title.isEmpty)
        XCTAssertFalse(payload.subtitle.isEmpty)
        XCTAssertFalse(payload.actionTitle.isEmpty)
        XCTAssertFalse(payload.roastLine.isEmpty)

        let records = try loadStandardCopyMemoryRecords().filter { record in
            record.module == .decision && record.itemID == item.id
        }

        XCTAssertEqual(
            Set(records.map(\.slot)),
            Set<CopySlot>([.title, .subtitle, .actionTitle, .roast])
        )
        XCTAssertTrue(records.allSatisfy { $0.scene == "decision_purchased" })
    }

    /// 打卡仪式 payload 应按条目语义走 resolver；同时 roast 的 scene 需要与 title/subtitle/badge 分开解释，不能共用同一 scene。
    @MainActor
    func test_checkin_payload_uses_item_category_context_and_slot_specific_scenes() throws {
        clearStandardCopyMemory()
        let usedAt = Date(timeIntervalSince1970: 1_741_000_000)
        let item = makeOfficeDesktopPurchasedItem(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            purchaseAt: usedAt
        )

        let payload = ExtractorViewModel().makeCheckinCelebration(
            for: item,
            previousUsageCount: 0,
            previousIdleDays: 0,
            usedAt: usedAt
        )

        XCTAssertFalse(payload.title.isEmpty)
        XCTAssertFalse(payload.subtitle.isEmpty)
        XCTAssertFalse(payload.badge.isEmpty)
        XCTAssertFalse(payload.roastLine.isEmpty)
        XCTAssertTrue(payload.isBigMoment)

        let records = try loadStandardCopyMemoryRecords().filter { record in
            record.module == .checkin && record.itemID == item.id
        }
        let sceneBySlot = Dictionary(uniqueKeysWithValues: records.map { ($0.slot, $0.scene) })

        XCTAssertEqual(
            Set(records.map(\.slot)),
            Set<CopySlot>([.title, .subtitle, .badge, .roast])
        )
        XCTAssertEqual(sceneBySlot[.title], "first_use_immediate")
        XCTAssertEqual(sceneBySlot[.subtitle], "first_use_immediate")
        XCTAssertEqual(sceneBySlot[.badge], "first_use_immediate")
        XCTAssertEqual(sceneBySlot[.roast], "first_use")
    }

    /// 吃灰挽救页的主/副点评应把条目语义与槽位信息透传给 resolver，并分别命中 `.primary` / `.secondary`。
    @MainActor
    func test_idle_rescue_copy_uses_item_category_context_for_primary_and_secondary_slots() throws {
        clearStandardCopyMemory()
        let item = makeOfficeDesktopPurchasedItem(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            purchaseAt: Date(timeIntervalSince1970: 1_741_000_000)
        )
        item.lastUsedAt = Calendar.current.date(byAdding: .day, value: -40, to: Date())!
        item.usageCount = 3

        _ = AppConstants.RoastCopy.idleRescuePrimary(
            idleDays: 40,
            itemName: item.displayName,
            itemID: item.id,
            primaryCategory: item.primaryCategory,
            secondaryCategory: item.secondaryCategory,
            behaviorTags: item.behaviorTags
        )
        _ = AppConstants.RoastCopy.idleRescueSecondary(
            idleDays: 40,
            usageCount: item.usageCount,
            itemName: item.displayName,
            itemID: item.id,
            primaryCategory: item.primaryCategory,
            secondaryCategory: item.secondaryCategory,
            behaviorTags: item.behaviorTags
        )

        let records = try loadStandardCopyMemoryRecords().filter { record in
            record.module == .idleRescue && record.itemID == item.id
        }
        let sceneBySlot = Dictionary(uniqueKeysWithValues: records.map { ($0.slot, $0.scene) })

        XCTAssertEqual(Set(records.map(\.slot)), Set<CopySlot>([.primary, .secondary]))
        XCTAssertEqual(sceneBySlot[.primary], "primary_heavy")
        XCTAssertEqual(sceneBySlot[.secondary], "secondary_heavy")
    }

    /// 稳定续打路径应继续由“低空窗”触发，而不是悄悄变成“累计使用次数达到阈值”才触发。
    @MainActor
    func test_checkin_steady_path_still_uses_low_idle_rule() throws {
        clearStandardCopyMemory()
        let item = makeOfficeDesktopPurchasedItem(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            purchaseAt: Date(timeIntervalSince1970: 1_741_000_000)
        )
        item.usageCount = 2
        item.lastUsedAt = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        _ = ExtractorViewModel().makeCheckinCelebration(
            for: item,
            previousUsageCount: item.usageCount,
            previousIdleDays: 1,
            usedAt: Date()
        )

        let records = try loadStandardCopyMemoryRecords().filter { record in
            record.module == .checkin && record.itemID == item.id
        }
        let sceneBySlot = Dictionary(uniqueKeysWithValues: records.map { ($0.slot, $0.scene) })

        XCTAssertEqual(sceneBySlot[.title], "steady_high_usage")
        XCTAssertEqual(sceneBySlot[.subtitle], "steady_high_usage")
        XCTAssertEqual(sceneBySlot[.badge], "steady_high_usage")
        XCTAssertEqual(sceneBySlot[.roast], "default")
    }

    /// 通知调度链路应把条目语义与场景透传给 resolver，确保轻提醒/强提醒/冷静期提醒/处置追提醒都进入新引擎。
    @MainActor
    func test_notification_manager_uses_item_context_for_all_notification_scenes() async throws {
        clearStandardCopyMemory()

        let purchasedItem = makeOfficeDesktopPurchasedItem(
            id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            purchaseAt: Date()
        )
        let cooldownItem = Item(
            id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
            name: "Apple Mac mini M4",
            createdAt: Date(),
            status: .wish,
            wishPriceCents: 399_999,
            primaryCategoryRawValue: ItemPrimaryCategory.office.rawValue,
            secondaryCategoryRawValue: ItemSecondaryCategory.desktopComputer.rawValue,
            categorySourceRawValue: CopyCategorySource.userSelected.rawValue,
            categoryConfidenceRawValue: CopyConfidence.high.rawValue,
            behaviorTagsRawValue: [
                ItemBehaviorTag.efficiencyFantasy.rawValue,
                ItemBehaviorTag.selfImprovement.rawValue
            ],
            behaviorTagSourceRawValue: CopyTagSource.userAdjusted.rawValue,
            cooldownDays: 7,
            cooldownEndAt: Date().addingTimeInterval(60 * 60)
        )

        await NotificationManager.shared.scheduleIdleReminders(for: purchasedItem)
        await NotificationManager.shared.scheduleRescueReminder(for: purchasedItem, days: 7)
        await NotificationManager.shared.scheduleCooldownDecisionReminders(for: cooldownItem)

        let notificationRecords = try loadStandardCopyMemoryRecords().filter { record in
            record.module == .notification
        }
        let purchasedScenes = Set(notificationRecords.compactMap { record in
            record.itemID == purchasedItem.id ? record.scene : nil
        })
        let cooldownScenes = Set(notificationRecords.compactMap { record in
            record.itemID == cooldownItem.id ? record.scene : nil
        })

        XCTAssertEqual(
            purchasedScenes,
            Set(["light_reminder", "strong_reminder", "rescue_followup"])
        )
        XCTAssertEqual(
            cooldownScenes,
            Set(["cooldown_ready", "cooldown_followup"])
        )
        XCTAssertTrue(notificationRecords.allSatisfy { $0.slot == .body })
    }

    /// 省钱复盘、空状态与分享兼容 API 应保持纯文本生成，不应在视图重绘时额外写入文案记忆层。
    func test_saved_review_empty_state_and_share_apis_do_not_mutate_copy_memory() throws {
        clearStandardCopyMemory()

        let itemID = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
        let reviewHeadline = AppConstants.RoastCopy.savedReviewHeadline(
            savedCents: 60_000,
            itemID: itemID
        )
        let reviewBody = AppConstants.RoastCopy.savedReviewBody(
            cooldownDays: 10,
            itemID: itemID
        )
        let darkRoomEmptyCopy = AppConstants.RoastCopy.darkRoomEmpty()
        let extractorEmptyCopy = AppConstants.RoastCopy.extractorEmpty()
        let decisionShareCopy = AppConstants.RoastCopy.decisionShareText(
            itemName: "Apple Mac mini M4",
            isSaved: true,
            metricTitle: "省下金额",
            metricValue: "¥3999.99",
            roastLine: reviewHeadline,
            itemID: itemID,
            primaryCategory: .office,
            secondaryCategory: .desktopComputer,
            behaviorTags: [.efficiencyFantasy, .selfImprovement]
        )
        let checkinShareCopy = AppConstants.RoastCopy.checkinShareText(
            itemName: "Apple Mac mini M4",
            usageCount: 3,
            currentCostText: "¥1333.33",
            roastLine: "继续连击",
            itemID: itemID,
            primaryCategory: .office,
            secondaryCategory: .desktopComputer,
            behaviorTags: [.efficiencyFantasy, .selfImprovement]
        )

        XCTAssertEqual(reviewHeadline, "这波不是省钱，是把未来的焦虑提前清仓。")
        XCTAssertEqual(reviewBody, "挺过一周冲动窗口，你的钱包终于学会拒绝。")
        XCTAssertEqual(darkRoomEmptyCopy, "小黑屋现在是空的，说明你今天还挺稳。")
        XCTAssertEqual(extractorEmptyCopy, "榨干机还没开张，先把想买清单里的条目做完决策。")
        XCTAssertTrue(decisionShareCopy.contains("冷静期成功忍住没买，直接省下一笔。"))
        XCTAssertTrue(checkinShareCopy.contains("你也来试试，别让买过的东西继续吃灰。"))

        let records = try loadStandardCopyMemoryRecords()
        XCTAssertTrue(records.isEmpty)
    }
}
