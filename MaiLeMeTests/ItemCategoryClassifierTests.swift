import XCTest
import SwiftData
@testable import MaiLeMe

/// 验证条目品类语义模型的基础映射是否符合预期。
final class ItemCategoryClassifierTests: XCTestCase {
    /// 创建仅驻留内存的 SwiftData 容器，确保测试能真实覆盖持久化写入与重新读取流程。
    /// - Returns: 用于单元测试的内存 `ModelContainer`。
    /// - Throws: 当 Schema 或容器初始化失败时抛出底层 SwiftData 错误。
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            Item.self,
            UsageRecord.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// 基础 taxonomy 应维护稳定的一二级品类归属与默认行为标签关系。
    func test_taxonomy_relationships_and_digital_default_tags_remain_consistent() {
        XCTAssertEqual(ItemSecondaryCategory.ssd.primaryCategory, .digital)
        XCTAssertEqual(ItemSecondaryCategory.softwareMembership.primaryCategory, .subscription)
        XCTAssertEqual(
            Set(ItemPrimaryCategory.digital.defaultBehaviorTags),
            Set<ItemBehaviorTag>([.efficiencyFantasy, .upgradeReplace])
        )
        XCTAssertTrue(ItemBehaviorTag.efficiencyFantasy.isDefaultForDigital)
        XCTAssertFalse(ItemBehaviorTag.selfImprovement.isDefaultForDigital)
    }

    /// 条目模型应能经由 SwiftData round-trip 持久化分类元数据，并在重新读取后保留 raw value 与 typed wrapper 语义。
    func test_item_persists_primary_secondary_category_and_behavior_tags() throws {
        let container = try makeInMemoryContainer()
        let itemID = UUID()
        let expectedBehaviorTagsRawValue = [
            ItemBehaviorTag.efficiencyFantasy.rawValue,
            ItemBehaviorTag.selfImprovement.rawValue
        ]
        let writeContext = ModelContext(container)
        let item = Item(
            id: itemID,
            name: "Mac mini",
            wishPriceCents: 399999,
            primaryCategoryRawValue: ItemPrimaryCategory.office.rawValue,
            secondaryCategoryRawValue: ItemSecondaryCategory.desktopComputer.rawValue,
            categorySourceRawValue: CopyCategorySource.userSelected.rawValue,
            categoryConfidenceRawValue: CopyConfidence.high.rawValue,
            behaviorTagsRawValue: expectedBehaviorTagsRawValue,
            behaviorTagSourceRawValue: CopyTagSource.userAdjusted.rawValue
        )

        writeContext.insert(item)
        try writeContext.save()

        // 使用新的上下文重新抓取，避免同一对象实例让测试误判为“已持久化”。
        let readContext = ModelContext(container)
        let descriptor = FetchDescriptor<Item>(
            predicate: #Predicate<Item> { persistedItem in
                persistedItem.id == itemID
            }
        )
        guard let persistedItem = try readContext.fetch(descriptor).first else {
            XCTFail("保存后的条目未能从 SwiftData 容器重新取回。")
            return
        }

        XCTAssertEqual(
            persistedItem.primaryCategoryRawValue,
            ItemPrimaryCategory.office.rawValue
        )
        XCTAssertEqual(
            persistedItem.secondaryCategoryRawValue,
            ItemSecondaryCategory.desktopComputer.rawValue
        )
        XCTAssertEqual(
            persistedItem.categorySourceRawValue,
            CopyCategorySource.userSelected.rawValue
        )
        XCTAssertEqual(
            persistedItem.categoryConfidenceRawValue,
            CopyConfidence.high.rawValue
        )
        XCTAssertEqual(persistedItem.behaviorTagsRawValue, expectedBehaviorTagsRawValue)
        XCTAssertEqual(
            persistedItem.behaviorTagSourceRawValue,
            CopyTagSource.userAdjusted.rawValue
        )
        XCTAssertEqual(persistedItem.primaryCategory, .office)
        XCTAssertEqual(persistedItem.secondaryCategory, .desktopComputer)
        XCTAssertEqual(persistedItem.categorySource, .userSelected)
        XCTAssertEqual(persistedItem.categoryConfidence, .high)
        XCTAssertEqual(
            Set(persistedItem.behaviorTags),
            Set<ItemBehaviorTag>([.efficiencyFantasy, .selfImprovement])
        )
        XCTAssertEqual(persistedItem.behaviorTagSource, .userAdjusted)
    }

    /// 未处理条目不应伪装成已经完成自动识别；同时历史脏值应回退到保守语义。
    func test_item_defaults_to_unresolved_sources_and_falls_back_for_invalid_raw_values() {
        let unresolvedItem = Item(
            name: "待分类条目",
            wishPriceCents: 1999
        )

        XCTAssertEqual(unresolvedItem.categorySource, .unresolved)
        XCTAssertEqual(unresolvedItem.behaviorTagSource, .unresolved)
        XCTAssertEqual(unresolvedItem.categoryConfidence, .low)

        let invalidRawValueItem = Item(
            name: "历史脏数据",
            wishPriceCents: 2999,
            primaryCategoryRawValue: "invalid-primary",
            secondaryCategoryRawValue: "invalid-secondary",
            categorySourceRawValue: "invalid-category-source",
            categoryConfidenceRawValue: "invalid-confidence",
            behaviorTagsRawValue: [
                ItemBehaviorTag.efficiencyFantasy.rawValue,
                "invalid-tag"
            ],
            behaviorTagSourceRawValue: "invalid-tag-source"
        )

        XCTAssertEqual(invalidRawValueItem.primaryCategory, .other)
        XCTAssertEqual(invalidRawValueItem.secondaryCategory, .other)
        XCTAssertEqual(invalidRawValueItem.categorySource, .unresolved)
        XCTAssertEqual(invalidRawValueItem.categoryConfidence, .low)
        XCTAssertEqual(
            invalidRawValueItem.behaviorTags,
            [.efficiencyFantasy]
        )
        XCTAssertEqual(invalidRawValueItem.behaviorTagSource, .unresolved)
    }

    /// 二级品类一旦明确，就应把一级品类收敛到 taxonomy 映射；只有 secondary 为 `.other` 时允许显式一级品类独立存在。
    func test_item_keeps_primary_secondary_categories_consistent() {
        let normalizedByInitializerItem = Item(
            name: "机械键盘",
            wishPriceCents: 89999,
            primaryCategoryRawValue: ItemPrimaryCategory.home.rawValue,
            secondaryCategoryRawValue: ItemSecondaryCategory.keyboard.rawValue
        )

        XCTAssertEqual(normalizedByInitializerItem.secondaryCategory, .keyboard)
        XCTAssertEqual(normalizedByInitializerItem.primaryCategory, .digital)

        let explicitPrimaryItem = Item(
            name: "未知订阅",
            wishPriceCents: 1999,
            primaryCategoryRawValue: ItemPrimaryCategory.subscription.rawValue,
            secondaryCategoryRawValue: ItemSecondaryCategory.other.rawValue
        )

        XCTAssertEqual(explicitPrimaryItem.secondaryCategory, .other)
        XCTAssertEqual(explicitPrimaryItem.primaryCategory, .subscription)

        explicitPrimaryItem.secondaryCategory = .coffeeMachine
        XCTAssertEqual(explicitPrimaryItem.secondaryCategory, .coffeeMachine)
        XCTAssertEqual(explicitPrimaryItem.primaryCategory, .appliance)

        explicitPrimaryItem.primaryCategory = .beauty
        XCTAssertEqual(explicitPrimaryItem.primaryCategory, .appliance)
    }

    /// 分类器应能根据真实商品名识别出固态硬盘与 Mac mini 这类高置信度条目。
    func test_classifier_identifies_ssd_and_mac_mini() {
        let classifier = ItemCategoryClassifier()

        let ssdResolution = classifier.classify(name: "三星 PM9A1 512G 固态硬盘")
        XCTAssertEqual(ssdResolution.primary, .digital)
        XCTAssertEqual(ssdResolution.secondary, .ssd)
        XCTAssertEqual(ssdResolution.confidence, .high)

        let desktopResolution = classifier.classify(name: "Apple Mac mini M4")
        XCTAssertEqual(desktopResolution.primary, .office)
        XCTAssertEqual(desktopResolution.secondary, .desktopComputer)
        XCTAssertEqual(desktopResolution.confidence, .high)
    }
}
