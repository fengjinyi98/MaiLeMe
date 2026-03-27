//
//  MockNotificationFactory.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import Foundation

/// Mock 通知场景：用于真机快速验证通知权限与弹出效果。
@MainActor
enum MockNotificationFactory {
    /// 发送一条 3 秒后触发的基础调试通知。
    static func sendQuickDemo() async {
        await NotificationManager.shared.scheduleDebugNotification(
            title: "Mock 通知",
            body: "3 秒后收到这条，说明通知链路正常。",
            after: 3
        )
    }

    /// 发送一条“真实样式”验证通知。
    /// 用法：点击后立即切到后台或锁屏，约 10 秒后观察系统通知图标是否为 App 图标。
    static func sendBackgroundIconDemo() async {
        await NotificationManager.shared.scheduleDebugNotification(
            title: "图标验证通知",
            body: "如果你在后台收到这条，左侧图标应为买了么 App 图标。",
            after: 10
        )
    }

    /// 发送连续两条毒舌风格通知，便于观察系统展示效果。
    static func sendRoastSequence(
        itemName: String = "Kindle",
        itemID: UUID? = nil,
        primaryCategory: ItemPrimaryCategory = .other,
        secondaryCategory: ItemSecondaryCategory = .other,
        behaviorTags: [ItemBehaviorTag] = []
    ) async {
        await NotificationManager.shared.scheduleDebugNotification(
            title: "Mock 轻提醒",
            body: AppConstants.RoastCopy.light(
                itemName: itemName,
                idleDays: AppConstants.Notification.lightIdleDays,
                itemID: itemID,
                primaryCategory: primaryCategory,
                secondaryCategory: secondaryCategory,
                behaviorTags: behaviorTags
            ),
            after: 4
        )
        await NotificationManager.shared.scheduleDebugNotification(
            title: "Mock 强提醒",
            body: AppConstants.RoastCopy.strong(
                itemName: itemName,
                idleDays: AppConstants.Notification.strongIdleDays,
                itemID: itemID,
                primaryCategory: primaryCategory,
                secondaryCategory: secondaryCategory,
                behaviorTags: behaviorTags
            ),
            after: 8
        )
    }

    /// 发送冷静期决策提醒组，便于联调“到期提醒 + 追提醒”文案。
    static func sendCooldownDecisionSequence(
        itemName: String = "机械键盘",
        itemID: UUID? = nil,
        primaryCategory: ItemPrimaryCategory = .other,
        secondaryCategory: ItemSecondaryCategory = .other,
        behaviorTags: [ItemBehaviorTag] = []
    ) async {
        await NotificationManager.shared.scheduleDebugNotification(
            title: "Mock 到期提醒",
            body: AppConstants.RoastCopy.cooldownReady(
                itemName: itemName,
                itemID: itemID,
                primaryCategory: primaryCategory,
                secondaryCategory: secondaryCategory,
                behaviorTags: behaviorTags
            ),
            after: 3
        )
        await NotificationManager.shared.scheduleDebugNotification(
            title: "Mock 追提醒",
            body: AppConstants.RoastCopy.cooldownFollowup(
                itemName: itemName,
                itemID: itemID,
                primaryCategory: primaryCategory,
                secondaryCategory: secondaryCategory,
                behaviorTags: behaviorTags
            ),
            after: 6
        )
    }
}
