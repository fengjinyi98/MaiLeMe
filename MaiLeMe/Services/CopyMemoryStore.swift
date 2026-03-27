import Foundation

/// 文案记忆层：把最近命中的文案历史写入 `UserDefaults`，供 resolver 做轻量反重复打分。
final class CopyMemoryStore {
    /// 单条历史记录：保留最小必要上下文，既能按模块回看近期文案，也为后续扩展更细粒度策略留出空间。
    private struct Record: Codable, Sendable {
        /// 文案唯一 ID。
        let copyID: String
        /// 所属模块。
        let module: CopyModule
        /// 解析时的业务场景。
        let scene: String
        /// 文案槽位。
        let slot: CopySlot
        /// 关联条目 ID；空值说明当前文案不绑定具体条目。
        let itemID: UUID?
        /// 文案语气。
        let tone: CopyTone
        /// 文案强度。
        let intensity: CopyIntensity
        /// 写入时间戳，用于保持最近记录顺序。
        let createdAt: Date
    }

    /// 底层偏好存储；测试可注入独立 suite，避免污染真实数据。
    private let defaults: UserDefaults
    /// 最近历史的持久化键。
    private let recentKey = "copy.memory.recent"
    /// 最多保留的历史条数，避免偏好体积无限增长。
    private let maximumRecordCount = 50

    /// 创建记忆层实例。
    /// - Parameter defaults: `UserDefaults`，默认使用标准偏好；测试可传入独立 suite。
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 记录一次文案命中，并把历史裁剪到最近 50 条。
    /// - Parameters:
    ///   - copyID: `String`，命中的文案 ID。
    ///   - module: `CopyModule`，文案所属模块。
    ///   - scene: `String`，本次解析时的业务场景。
    ///   - slot: `CopySlot`，文案槽位。
    ///   - itemID: `UUID?`，关联条目 ID。
    ///   - tone: `CopyTone`，命中的语气标签。
    ///   - intensity: `CopyIntensity`，命中的强度标签。
    func record(
        copyID: String,
        module: CopyModule,
        scene: String,
        slot: CopySlot,
        itemID: UUID?,
        tone: CopyTone,
        intensity: CopyIntensity
    ) {
        var records = loadRecords()
        let newRecord = Record(
            copyID: copyID,
            module: module,
            scene: scene,
            slot: slot,
            itemID: itemID,
            tone: tone,
            intensity: intensity,
            createdAt: Date()
        )

        // 对于同一调用点在一次视图生命周期内的重复重绘，若命中结果完全一致，就不再重复写入偏好；
        // 否则像空状态这类“纯展示型文案”会在每次 body 计算时触发同步磁盘/XPC 写入，拖慢主线程。
        if let latestRecord = records.first,
           latestRecord.copyID == newRecord.copyID,
           latestRecord.module == newRecord.module,
           latestRecord.scene == newRecord.scene,
           latestRecord.slot == newRecord.slot,
           latestRecord.itemID == newRecord.itemID,
           latestRecord.tone == newRecord.tone,
           latestRecord.intensity == newRecord.intensity {
            return
        }

        // 采用“最新在前”的滚动队列，读取时无需额外倒序即可直接按最近顺序返回。
        records.insert(newRecord, at: 0)
        if records.count > maximumRecordCount {
            records = Array(records.prefix(maximumRecordCount))
        }

        save(records)
    }

    /// 读取某个模块最近命中的文案 ID 列表，按时间倒序返回并去重。
    /// - Parameter module: `CopyModule`，需要查询的文案模块。
    /// - Returns: `[String]`，最近命中的文案 ID，最新命中排在最前。
    func recentCopyIDs(module: CopyModule) -> [String] {
        let records = loadRecords().filter { $0.module == module }
        var seenIDs = Set<String>()

        return records.compactMap { record in
            // 同一 ID 只保留最近一次，既能表达“近期出现过”，又能避免重复惩罚被重复写入放大。
            guard seenIDs.insert(record.copyID).inserted else {
                return nil
            }
            return record.copyID
        }
    }

    /// 从偏好中解码历史记录；若数据损坏则保守回退为空数组。
    /// - Returns: `[Record]`，当前已存储的历史记录。
    private func loadRecords() -> [Record] {
        guard let data = defaults.data(forKey: recentKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([Record].self, from: data)
        } catch {
            return []
        }
    }

    /// 持久化历史记录；编码失败时静默忽略，避免影响主流程的文案解析。
    /// - Parameter records: `[Record]`，需要写入的滚动历史。
    private func save(_ records: [Record]) {
        do {
            let data = try JSONEncoder().encode(records)
            defaults.set(data, forKey: recentKey)
        } catch {
            return
        }
    }
}
