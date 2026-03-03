//
//  DataMigrationManager.swift
//  MaiLeMe
//
//  Created by Codex on 2026/3/3.
//

import Foundation
import SwiftData

/// 数据迁移管理器：承载“版本化的数据修复逻辑”，确保升级后历史数据可用。
@MainActor
final class DataMigrationManager {
    static let shared = DataMigrationManager()

    /// 当前迁移版本号：每新增一批迁移步骤时递增。
    private let latestVersion = 2
    /// 本地持久化 key：记录已执行到的迁移版本。
    private let migrationVersionKey = AppConstants.UserDefaultsKeys.dataMigrationVersion
    private let defaults = UserDefaults.standard

    private init() {}

    /// 启动时执行待处理迁移。
    /// - Parameter context: SwiftData 上下文。
    func runPendingMigrations(context: ModelContext) async {
        var storedVersion = defaults.integer(forKey: migrationVersionKey)
        if storedVersion >= latestVersion {
            return
        }

        do {
            if storedVersion < 1 {
                try migrateToV1(context: context)
                storedVersion = 1
                defaults.set(storedVersion, forKey: migrationVersionKey)
            }

            if storedVersion < 2 {
                try migrateToV2(context: context)
                storedVersion = 2
                defaults.set(storedVersion, forKey: migrationVersionKey)
            }
        } catch {
            #if DEBUG
            print("数据迁移失败：\(error.localizedDescription)")
            #endif
        }
    }

    /// V1 迁移：修复历史数据中可能出现的非法数值（负数/空值越界）。
    private func migrateToV1(context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<Item>())
        let usageRecords = try context.fetch(FetchDescriptor<UsageRecord>())

        var hasChanges = false

        for item in items {
            if item.wishPriceCents < 0 {
                item.wishPriceCents = 0
                hasChanges = true
            }
            if let purchasePrice = item.purchasePriceCents, purchasePrice < 0 {
                item.purchasePriceCents = 0
                hasChanges = true
            }
            if item.usageCount < 0 {
                item.usageCount = 0
                hasChanges = true
            }
            if item.savedAmountCents < 0 {
                item.savedAmountCents = 0
                hasChanges = true
            }
            if let expectedUseCount = item.expectedUseCount, expectedUseCount < 1 {
                item.expectedUseCount = 1
                hasChanges = true
            }
            if let targetCost = item.targetCostPerUseCents, targetCost < 1 {
                item.targetCostPerUseCents = 1
                hasChanges = true
            }
        }

        for record in usageRecords {
            if let duration = record.durationMinutes, duration < 1 {
                record.durationMinutes = 1
                hasChanges = true
            }
        }

        if hasChanges {
            try context.save()
        }
    }

    /// V2 迁移：修复“状态与衍生字段不一致”的历史记录，确保看板统计准确。
    private func migrateToV2(context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<Item>())
        var hasChanges = false

        for item in items {
            // 已购买条目必须有购买时间与购买价格，避免回本与健康度计算异常。
            if item.status == .purchased {
                if item.purchaseAt == nil {
                    item.purchaseAt = item.createdAt
                    hasChanges = true
                }
                if item.purchasePriceCents == nil {
                    item.purchasePriceCents = max(0, item.wishPriceCents)
                    hasChanges = true
                }

                // 历史数据中 usageCount 可能小于记录条数，统一向上修正。
                let recordCount = item.usageRecords.count
                if recordCount > item.usageCount {
                    item.usageCount = recordCount
                    hasChanges = true
                }

                // 没有最近使用时间时，回填最近一条打卡时间。
                if item.lastUsedAt == nil {
                    let latestUsedAt = item.usageRecords
                        .map(\.usedAt)
                        .max()
                    if let latestUsedAt {
                        item.lastUsedAt = latestUsedAt
                        hasChanges = true
                    }
                }
            }
        }

        if hasChanges {
            try context.save()
        }
    }
}
