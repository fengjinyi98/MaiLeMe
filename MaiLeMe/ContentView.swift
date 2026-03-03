//
//  ContentView.swift
//  MaiLeMe
//
//  Created by fengjinyi on 2026/2/28.
//

import SwiftUI

/// 应用主入口视图：使用双 Tab 承载小黑屋与榨干机主流程。
struct ContentView: View {
    @StateObject private var navigationState = AppNavigationState()

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
        }
        .tint(AppTheme.Palette.accent)
        .environmentObject(navigationState)
    }
}

#Preview {
    ContentView()
}
