import XCTest
@testable import MaiLeMe

/// 验证条目品类语义模型的基础映射是否符合预期。
final class ItemCategoryClassifierTests: XCTestCase {
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

    /// 条目模型应能持久化分类元数据，并通过 typed wrapper 暴露业务语义。
    func test_item_persists_primary_secondary_category_and_behavior_tags() {
        let item = Item(
            name: "Mac mini",
            wishPriceCents: 399999,
            primaryCategoryRawValue: ItemPrimaryCategory.office.rawValue,
            secondaryCategoryRawValue: ItemSecondaryCategory.desktopComputer.rawValue,
            behaviorTagsRawValue: [
                ItemBehaviorTag.efficiencyFantasy.rawValue,
                ItemBehaviorTag.selfImprovement.rawValue
            ]
        )

        XCTAssertEqual(item.primaryCategory, .office)
        XCTAssertEqual(item.secondaryCategory, .desktopComputer)
        XCTAssertTrue(item.behaviorTags.contains(.efficiencyFantasy))
    }
}
