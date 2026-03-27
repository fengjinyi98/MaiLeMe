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
            behaviorTagsRawValue: expectedBehaviorTagsRawValue
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
        XCTAssertEqual(persistedItem.behaviorTagsRawValue, expectedBehaviorTagsRawValue)
        XCTAssertEqual(persistedItem.primaryCategory, .office)
        XCTAssertEqual(persistedItem.secondaryCategory, .desktopComputer)
        XCTAssertEqual(
            Set(persistedItem.behaviorTags),
            Set<ItemBehaviorTag>([.efficiencyFantasy, .selfImprovement])
        )
    }
}
