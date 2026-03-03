//
//  AppNavigationState.swift
//  MaiLeMe
//
//  Created by Codex on 2026/3/3.
//

import Foundation
import Combine

/// 应用级导航状态：用于跨 Tab 的定向跳转（例如从小黑屋直达榨干机打卡页）。
@MainActor
final class AppNavigationState: ObservableObject {
    /// 根级 Tab。
    enum RootTab: Hashable {
        case darkRoom
        case extractor
        case settings
    }

    /// 小黑屋筛选聚焦类型：用于从小组件等外部入口直接命中目标列表。
    enum DarkRoomFocus: String, Hashable {
        case all
        case ready
        case cooling
    }

    /// 当前选中的 Tab。
    @Published var selectedTab: RootTab = .darkRoom

    /// 待消费的榨干机详情跳转目标（物品 ID）。
    @Published var pendingExtractorItemID: UUID?
    /// 待消费的吃灰挽救跳转目标（物品 ID）。
    @Published var pendingIdleRescueItemID: UUID?
    /// 待消费的小黑屋筛选焦点。
    @Published var pendingDarkRoomFocus: DarkRoomFocus?

    /// 发起“切到榨干机并打开指定物品详情”的导航请求。
    func routeToExtractorCheckin(itemID: UUID) {
        selectedTab = .extractor
        pendingExtractorItemID = itemID
        pendingIdleRescueItemID = nil
    }

    /// 发起“切到榨干机并打开指定物品的吃灰挽救页”的导航请求。
    func routeToIdleRescue(itemID: UUID) {
        selectedTab = .extractor
        pendingIdleRescueItemID = itemID
        pendingExtractorItemID = nil
    }

    /// 发起“切到榨干机首页”的导航请求。
    func routeToExtractorHome() {
        selectedTab = .extractor
        pendingExtractorItemID = nil
        pendingIdleRescueItemID = nil
    }

    /// 发起“切到小黑屋并应用筛选焦点”的导航请求。
    func routeToDarkRoomFocus(_ focus: DarkRoomFocus) {
        selectedTab = .darkRoom
        pendingDarkRoomFocus = focus
    }
}
