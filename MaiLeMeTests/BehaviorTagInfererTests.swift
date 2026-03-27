import XCTest
@testable import MaiLeMe

/// 验证行为标签推断器能根据一级/二级品类输出稳定的消费动机标签。
final class BehaviorTagInfererTests: XCTestCase {
    /// Mac mini 这类台式办公设备应体现效率幻想、自我提升与升级替换的复合动机。
    func test_behavior_inferer_assigns_expected_tags_for_mac_mini() {
        let tags = BehaviorTagInferer().infer(
            name: "Apple Mac mini M4",
            primaryCategory: .office,
            secondaryCategory: .desktopComputer
        )

        XCTAssertTrue(tags.contains(.efficiencyFantasy))
        XCTAssertTrue(tags.contains(.selfImprovement))
        XCTAssertTrue(tags.contains(.upgradeReplace))
    }
}
