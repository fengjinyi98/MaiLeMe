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
    }

    /// 当前选中的 Tab。
    @Published var selectedTab: RootTab = .darkRoom

    /// 待消费的榨干机详情跳转目标（物品 ID）。
    @Published var pendingExtractorItemID: UUID?

    /// 发起“切到榨干机并打开指定物品详情”的导航请求。
    func routeToExtractorCheckin(itemID: UUID) {
        selectedTab = .extractor
        pendingExtractorItemID = itemID
    }
}
