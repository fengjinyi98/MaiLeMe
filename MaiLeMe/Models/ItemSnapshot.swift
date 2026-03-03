//
//  ItemSnapshot.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import Foundation
import SwiftData

/// 使用记录快照：用于删除后快速恢复。
@MainActor
struct UsageRecordSnapshot {
    let id: UUID
    let usedAt: Date
    let durationMinutes: Int?
    let note: String?

    init(record: UsageRecord) {
        self.id = record.id
        self.usedAt = record.usedAt
        self.durationMinutes = record.durationMinutes
        self.note = record.note
    }
}

/// 物品快照：用于“删除后撤销”。
@MainActor
struct ItemSnapshot {
    let id: UUID
    let name: String
    let createdAt: Date
    let status: ItemStatus
    let coverImageData: Data?

    let wishPriceCents: Int
    let cooldownDays: Int?
    let cooldownEndAt: Date?
    let decision: CooldownDecision?
    let decisionAt: Date?

    let purchaseAt: Date?
    let purchasePriceCents: Int?
    let purchasedDuringCooldown: Bool
    let expectedUseCount: Int?
    let targetCostPerUseCents: Int?
    let usageCount: Int
    let lastUsedAt: Date?
    let savedAmountCents: Int

    let usageRecords: [UsageRecordSnapshot]

    init(item: Item) {
        id = item.id
        name = item.name
        createdAt = item.createdAt
        status = item.status
        coverImageData = item.coverImageData

        wishPriceCents = item.wishPriceCents
        cooldownDays = item.cooldownDays
        cooldownEndAt = item.cooldownEndAt
        decision = item.decision
        decisionAt = item.decisionAt

        purchaseAt = item.purchaseAt
        purchasePriceCents = item.purchasePriceCents
        purchasedDuringCooldown = item.purchasedDuringCooldown
        expectedUseCount = item.expectedUseCount
        targetCostPerUseCents = item.targetCostPerUseCents
        usageCount = item.usageCount
        lastUsedAt = item.lastUsedAt
        savedAmountCents = item.savedAmountCents

        usageRecords = item.usageRecords.map(UsageRecordSnapshot.init)
    }

    /// 根据快照在本地存储中重建物品与使用记录。
    @discardableResult
    func restore(in context: ModelContext) -> Item {
        let restoredItem = Item(
            id: id,
            name: name,
            createdAt: createdAt,
            status: status,
            coverImageData: coverImageData,
            wishPriceCents: wishPriceCents,
            cooldownDays: cooldownDays,
            cooldownEndAt: cooldownEndAt,
            decision: decision,
            decisionAt: decisionAt,
            purchaseAt: purchaseAt,
            purchasePriceCents: purchasePriceCents,
            purchasedDuringCooldown: purchasedDuringCooldown,
            expectedUseCount: expectedUseCount,
            targetCostPerUseCents: targetCostPerUseCents,
            usageCount: usageCount,
            lastUsedAt: lastUsedAt,
            savedAmountCents: savedAmountCents
        )
        context.insert(restoredItem)

        for usageSnapshot in usageRecords.sorted(by: { $0.usedAt < $1.usedAt }) {
            let record = UsageRecord(
                id: usageSnapshot.id,
                usedAt: usageSnapshot.usedAt,
                durationMinutes: usageSnapshot.durationMinutes,
                note: usageSnapshot.note,
                item: restoredItem
            )
            context.insert(record)
        }
        return restoredItem
    }
}
