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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            UsageRecord.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Schema 不兼容时删除旧数据库并重建（开发阶段）
            let storeURL = modelConfiguration.url
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("无法创建 ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await NotificationManager.shared.prepareForLaunch()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
