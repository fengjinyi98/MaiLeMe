//
//  UsageRecord.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import Foundation
import SwiftData

@Model
final class UsageRecord {
    /// 业务主键，使用唯一约束避免重复插入。
    @Attribute(.unique) var id: UUID
    /// 打卡时间。
    var usedAt: Date
    /// 本次使用时长（分钟，可选）。
    var durationMinutes: Int?
    /// 备注信息（可选）。
    var note: String?
    /// 所属物品。
    var item: Item?

    init(
        id: UUID = UUID(),
        usedAt: Date = .now,
        durationMinutes: Int? = nil,
        note: String? = nil,
        item: Item? = nil
    ) {
        self.id = id
        self.usedAt = usedAt
        if let durationMinutes {
            self.durationMinutes = max(1, durationMinutes)
        } else {
            self.durationMinutes = nil
        }
        self.note = note
        self.item = item
    }
}
