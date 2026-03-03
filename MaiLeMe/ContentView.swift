//
//  ContentView.swift
//  MaiLeMe
//
//  Created by fengjinyi on 2026/2/28.
//

import SwiftUI
import SwiftData

/// 应用主入口视图：使用双 Tab 承载小黑屋与榨干机主流程。
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.createdAt, order: .reverse) private var allItems: [Item]
    @StateObject private var navigationState = AppNavigationState()
    @AppStorage(AppConstants.UserDefaultsKeys.hasSeenOnboarding) private var hasSeenOnboarding = false
    @State private var hasRunStartupPipeline = false

    var body: some View {
        TabView(selection: $navigationState.selectedTab) {
            DarkRoomScreen()
                .tag(AppNavigationState.RootTab.darkRoom)
                .tabItem {
                    Label("冲动小黑屋", systemImage: "lock.square")
                }

            ExtractorScreen()
                .tag(AppNavigationState.RootTab.extractor)
                .tabItem {
                    Label("闲置榨干机", systemImage: "bolt.square")
                }

            SettingsScreen()
                .tag(AppNavigationState.RootTab.settings)
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
        .tint(AppTheme.Palette.accent)
        .environmentObject(navigationState)
        .fullScreenCover(isPresented: showOnboardingBinding) {
            OnboardingScreen {
                hasSeenOnboarding = true
            }
        }
        .task {
            guard !hasRunStartupPipeline else { return }
            hasRunStartupPipeline = true
            await NotificationManager.shared.prepareForLaunch()
            await DataMigrationManager.shared.runPendingMigrations(context: modelContext)
        }
        .task(id: widgetSyncToken) {
            WidgetSnapshotStore.shared.refreshRationalDefenseSnapshot(using: allItems)
        }
        .onOpenURL(perform: handleIncomingURL)
    }

    /// 引导弹层展示控制：仅首次启动自动展示，后续可在设置页重新触发。
    private var showOnboardingBinding: Binding<Bool> {
        Binding(
            get: { !hasSeenOnboarding },
            set: { isPresented in
                if !isPresented {
                    hasSeenOnboarding = true
                }
            }
        )
    }

    /// 小组件快照同步令牌：当关键字段变化时触发重新聚合写入。
    private var widgetSyncToken: String {
        allItems
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { item in
                let cooldown = item.cooldownEndAt?.timeIntervalSince1970 ?? 0
                let purchase = item.purchaseAt?.timeIntervalSince1970 ?? 0
                let lastUsed = item.lastUsedAt?.timeIntervalSince1970 ?? 0
                return "\(item.id.uuidString)|\(item.status.rawValue)|\(item.usageCount)|\(item.savedAmountCents)|\(cooldown)|\(purchase)|\(lastUsed)"
            }
            .joined(separator: ";")
    }

    /// 处理来自小组件的深链跳转。
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme?.lowercased() == AppConstants.Widget.deepLinkScheme else {
            return
        }
        guard let host = url.host?.lowercased() else {
            return
        }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        switch host {
        case AppConstants.Widget.darkRoomHost:
            let focusValue = components?
                .queryItems?
                .first(where: { $0.name == AppConstants.Widget.focusQueryName })?
                .value ?? AppNavigationState.DarkRoomFocus.all.rawValue
            let focus = AppNavigationState.DarkRoomFocus(rawValue: focusValue) ?? .all
            navigationState.routeToDarkRoomFocus(focus)

        case AppConstants.Widget.extractorHost:
            let entry = components?
                .queryItems?
                .first(where: { $0.name == AppConstants.Widget.extractorEntryQueryName })?
                .value ?? AppConstants.Widget.extractorEntryDetail
            if let itemIDString = components?
                .queryItems?
                .first(where: { $0.name == AppConstants.Widget.itemIDQueryName })?
                .value,
               let itemID = UUID(uuidString: itemIDString) {
                if entry == AppConstants.Widget.extractorEntryRescue {
                    navigationState.routeToIdleRescue(itemID: itemID)
                } else {
                    navigationState.routeToExtractorCheckin(itemID: itemID)
                }
            } else {
                navigationState.routeToExtractorHome()
            }

        default:
            return
        }
    }
}

#Preview {
    ContentView()
}
