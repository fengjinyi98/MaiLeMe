import XCTest
@testable import MaiLeMe

/// 验证文案记忆层会记录最近命中的文案 ID，供 rotating 模式做反重复惩罚。
final class CopyMemoryStoreTests: XCTestCase {
    /// 每个测试都使用独立 suite，避免与其他测试或本机已有偏好数据互相污染。
    private let suiteName = "CopyMemoryStoreTests"

    /// 清理测试 suite，确保断言只受当前测试写入的数据影响。
    override func setUp() {
        super.setUp()
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    /// 清理测试 suite，避免残留数据影响后续测试。
    override func tearDown() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    /// 当某条文案刚刚被记录后，记忆层应能按模块返回该 ID，供 resolver 后续做反重复评分。
    func test_memory_store_prevents_recent_copy_id_from_reappearing_in_rotating_mode() {
        let store = CopyMemoryStore(defaults: UserDefaults(suiteName: suiteName)!)
        store.record(
            copyID: "decision_saved_title_001",
            module: .decision,
            scene: "decision_saved",
            slot: .title,
            itemID: nil,
            tone: .sharp,
            intensity: .medium
        )

        XCTAssertTrue(store.recentCopyIDs(module: .decision).contains("decision_saved_title_001"))
    }
}
