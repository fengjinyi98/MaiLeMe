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

    /// 历史记录应只保留最近 50 条，避免偏好体积膨胀并保证“最近出现过”语义稳定。
    func test_memory_store_trims_history_to_latest_fifty_entries() {
        let store = CopyMemoryStore(defaults: UserDefaults(suiteName: suiteName)!)

        for index in 0..<60 {
            store.record(
                copyID: "decision_saved_title_\(index)",
                module: .decision,
                scene: "decision_saved",
                slot: .title,
                itemID: nil,
                tone: .neutral,
                intensity: .medium
            )
        }

        let recentIDs = store.recentCopyIDs(module: .decision)
        XCTAssertEqual(recentIDs.count, 50)
        XCTAssertEqual(recentIDs.first, "decision_saved_title_59")
        XCTAssertEqual(recentIDs.last, "decision_saved_title_10")
        XCTAssertFalse(recentIDs.contains("decision_saved_title_9"))
    }

    /// 连续记录完全相同的命中结果时，记忆层应忽略重复写入，避免视图重绘把主线程卡在偏好持久化上。
    func test_memory_store_skips_duplicate_latest_record() {
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = CopyMemoryStore(defaults: defaults)

        store.record(
            copyID: "empty_state_dark_room_001",
            module: .emptyState,
            scene: "dark_room_empty",
            slot: .body,
            itemID: nil,
            tone: .neutral,
            intensity: .low
        )
        store.record(
            copyID: "empty_state_dark_room_001",
            module: .emptyState,
            scene: "dark_room_empty",
            slot: .body,
            itemID: nil,
            tone: .neutral,
            intensity: .low
        )

        let rawData = defaults.data(forKey: "copy.memory.recent")
        let records = try? JSONDecoder().decode([DecodedRecord].self, from: rawData ?? Data())

        XCTAssertEqual(records?.count, 1)
        XCTAssertEqual(records?.first?.copyID, "empty_state_dark_room_001")
    }
}

/// 仅供测试读取 `CopyMemoryStore` 持久化结果的轻量镜像结构。
private struct DecodedRecord: Decodable {
    /// 文案唯一 ID。
    let copyID: String
}
