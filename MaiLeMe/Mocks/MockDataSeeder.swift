//
//  MockDataSeeder.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import Foundation
import SwiftData

/// Mock 数据注入器：用于真机调试时快速构建可视化场景数据。
@MainActor
enum MockDataSeeder {
    /// 清空全部本地数据（Item + UsageRecord）。
    static func clearAll(context: ModelContext) throws {
        let usageRecords = try context.fetch(FetchDescriptor<UsageRecord>())
        for record in usageRecords {
            context.delete(record)
        }

        let items = try context.fetch(FetchDescriptor<Item>())
        for item in items {
            context.delete(item)
        }
    }

    /// 重置后注入完整 Mock 数据。
    /// 返回值为“已购买”物品，便于调用方联动通知调度。
    @discardableResult
    static func resetAndSeed(context: ModelContext) throws -> [Item] {
        try clearAll(context: context)

        let calendar = Calendar.current
        let now = Date.now

        func daysAgo(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: now) ?? now
        }

        func daysLater(from date: Date, days: Int) -> Date {
            calendar.date(byAdding: .day, value: days, to: date) ?? date
        }

        // 待购：冷静期中
        let wishCooling = Item(
            name: "机械键盘",
            createdAt: daysAgo(1),
            status: .wish,
            wishPriceCents: 69900,
            cooldownDays: 7,
            cooldownEndAt: daysLater(from: daysAgo(1), days: 6)
        )
        context.insert(wishCooling)

        // 待购：已到期，可决策
        let wishReady = Item(
            name: "空气炸锅",
            createdAt: daysAgo(10),
            status: .wish,
            wishPriceCents: 49900,
            cooldownDays: 7,
            cooldownEndAt: daysAgo(2)
        )
        context.insert(wishReady)

        // 已忍住
        let savedItem = Item(
            name: "潮鞋（忍住没买）",
            createdAt: daysAgo(20),
            status: .saved,
            wishPriceCents: 129900,
            cooldownDays: 7,
            cooldownEndAt: daysAgo(13),
            decision: .saved,
            decisionAt: daysAgo(13),
            savedAmountCents: 129900
        )
        context.insert(savedItem)

        // 已购买：重度吃灰
        let kindle = Item(
            name: "Kindle（重度吃灰）",
            createdAt: daysAgo(120),
            status: .purchased,
            wishPriceCents: 99800,
            decision: .purchased,
            decisionAt: daysAgo(119),
            purchaseAt: daysAgo(118),
            purchasePriceCents: 99800,
            expectedUseCount: 180,
            targetCostPerUseCents: 5000
        )
        context.insert(kindle)
        attachUsage(daysAgoOffsets: [110, 90, 60, 45], notePrefix: "阅读", for: kindle, context: context, now: now, calendar: calendar)

        // 已购买：中度吃灰
        let coffeeMachine = Item(
            name: "咖啡机（中度吃灰）",
            createdAt: daysAgo(40),
            status: .purchased,
            wishPriceCents: 159900,
            decision: .purchased,
            decisionAt: daysAgo(39),
            purchaseAt: daysAgo(38),
            purchasePriceCents: 159900,
            expectedUseCount: 180,
            targetCostPerUseCents: 1200
        )
        context.insert(coffeeMachine)
        attachUsage(daysAgoOffsets: [30, 21, 15, 8], notePrefix: "冲咖啡", for: coffeeMachine, context: context, now: now, calendar: calendar)

        // 已购买：刚买未用（用于验证“未使用”状态）
        let yogaMat = Item(
            name: "瑜伽垫（刚买未用）",
            createdAt: daysAgo(3),
            status: .purchased,
            wishPriceCents: 19900,
            decision: .purchased,
            decisionAt: daysAgo(3),
            purchaseAt: daysAgo(2),
            purchasePriceCents: 19900,
            purchasedDuringCooldown: true,
            expectedUseCount: 70,
            targetCostPerUseCents: 300
        )
        context.insert(yogaMat)

        return [kindle, coffeeMachine, yogaMat]
    }

    /// 为指定物品批量注入使用记录，并同步聚合字段。
    private static func attachUsage(
        daysAgoOffsets: [Int],
        notePrefix: String,
        for item: Item,
        context: ModelContext,
        now: Date,
        calendar: Calendar
    ) {
        let usageDates: [Date] = daysAgoOffsets.compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: now)
        }

        for (index, usedAt) in usageDates.enumerated() {
            let record = UsageRecord(
                usedAt: usedAt,
                durationMinutes: 20 + (index * 10),
                note: "\(notePrefix) #\(index + 1)",
                item: item
            )
            context.insert(record)
        }

        item.usageCount = usageDates.count
        item.lastUsedAt = usageDates.max()
    }
}
