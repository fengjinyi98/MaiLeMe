//
//  MaiLeMeApp.swift
//  MaiLeMe
//
//  Created by fengjinyi on 2026/2/28.
//

import SwiftUI
import SwiftData

@main
struct MaiLeMeApp: App {
    private let sharedModelContainer: ModelContainer
    @StateObject private var syncRuntimeState: SyncRuntimeState

    init() {
        let preferredCloudSync = UserDefaults.standard.object(forKey: CloudSyncPreferences.isEnabledKey) as? Bool
            ?? CloudSyncPreferences.defaultEnabled
        let build = Self.buildContainer(preferCloudSync: preferredCloudSync)
        sharedModelContainer = build.container
        _syncRuntimeState = StateObject(
            wrappedValue: SyncRuntimeState(
                preferredCloudSync: preferredCloudSync,
                effectiveMode: build.effectiveMode,
                launchMessage: build.launchMessage
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(syncRuntimeState)
        }
        .modelContainer(sharedModelContainer)
    }

    /// 启动容器构建结果。
    private struct ContainerBuildResult {
        let container: ModelContainer
        let effectiveMode: SyncEffectiveMode
        let launchMessage: String?
    }

    /// 构建 SwiftData 容器：优先 CloudKit，失败自动回退本地。
    private static func buildContainer(preferCloudSync: Bool) -> ContainerBuildResult {
        let schema = Schema([
            Item.self,
            UsageRecord.self,
        ])

        var launchMessages: [String] = []

        if preferCloudSync {
            if CloudSyncPreferences.isCloudKitBuildReady {
                do {
                    let cloudContainer = try makeCloudContainer(schema: schema)
                    return ContainerBuildResult(
                        container: cloudContainer,
                        effectiveMode: .cloudPrivate,
                        launchMessage: nil
                    )
                } catch {
                    // 云容器初始化失败时，不阻塞启动，转走本地存储。
                    launchMessages.append("iCloud 同步初始化失败，已回退本地存储：\(error.localizedDescription)")
                }
            } else {
                // 构建未声明可用时，直接跳过云容器，避免启动崩溃。
                launchMessages.append("当前构建未启用 CloudKit 同步开关，已使用本地存储。")
            }
        }

        do {
            let localContainer = try makeLocalContainer(schema: schema)
            return ContainerBuildResult(
                container: localContainer,
                effectiveMode: .localOnly,
                launchMessage: launchMessages.isEmpty ? nil : launchMessages.joined(separator: "\n")
            )
        } catch {
            launchMessages.append("本地数据库初始化失败，已回退临时内存存储：\(error.localizedDescription)")
        }

        do {
            let memoryContainer = try makeInMemoryContainer(schema: schema)
            return ContainerBuildResult(
                container: memoryContainer,
                effectiveMode: .localOnly,
                launchMessage: launchMessages.joined(separator: "\n")
            )
        } catch {
            // 理论上极少发生；若走到这里，说明运行环境异常，使用 fatalError 暴露问题。
            fatalError("无法创建任何可用的 ModelContainer：\(error)")
        }
    }

    /// 创建本地持久化容器。
    private static func makeLocalContainer(schema: Schema) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// 创建 CloudKit 私有库容器。
    private static func makeCloudContainer(schema: Schema) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// 创建内存容器（最后兜底，避免启动崩溃）。
    private static func makeInMemoryContainer(schema: Schema) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

}
