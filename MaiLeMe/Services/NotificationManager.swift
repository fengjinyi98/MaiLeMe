//
//  NotificationManager.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import Foundation
import UserNotifications

/// 本地通知管理器：负责权限申请、吃灰提醒与冷静期决策提醒调度。
@MainActor
final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let calendar = Calendar.current
    private let defaults = UserDefaults.standard
    private let askedPermissionKey = "notification.permission.requested"

    private override init() {
        super.init()
        center.delegate = self
    }

    /// App 启动时调用：仅首次触发系统权限弹窗。
    func prepareForLaunch() async {
        guard !defaults.bool(forKey: askedPermissionKey) else {
            return
        }
        defaults.set(true, forKey: askedPermissionKey)
        _ = try? await requestAuthorization()
    }

    /// 主动请求通知权限。
    @discardableResult
    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    /// 获取当前通知授权状态，用于设置页展示和异常引导。
    func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    /// 为已购物品安排吃灰提醒（7 天轻提醒 + 30 天强提醒）。
    /// 每次调用会先清理旧提醒，避免重复通知。
    func scheduleIdleReminders(for item: Item) async {
        guard item.status == .purchased else {
            cancelIdleReminders(for: item.id)
            return
        }

        // 已进入购买状态后，不应再保留冷静期决策提醒。
        cancelCooldownDecisionReminders(for: item.id)
        // 发生新使用行为后，用户通常已处理该条目，清掉手动“处置追提醒”。
        cancelRescueReminder(for: item.id)

        guard let baseDate = item.lastUsedAt ?? item.purchaseAt else {
            cancelIdleReminders(for: item.id)
            return
        }

        cancelIdleReminders(for: item.id)
        await scheduleIdleReminder(
            itemID: item.id,
            itemName: item.displayName,
            baseDate: baseDate,
            idleDays: AppConstants.Notification.lightIdleDays,
            isStrong: false,
            primaryCategory: item.primaryCategory,
            secondaryCategory: item.secondaryCategory,
            behaviorTags: item.behaviorTags
        )
        await scheduleIdleReminder(
            itemID: item.id,
            itemName: item.displayName,
            baseDate: baseDate,
            idleDays: AppConstants.Notification.strongIdleDays,
            isStrong: true,
            primaryCategory: item.primaryCategory,
            secondaryCategory: item.secondaryCategory,
            behaviorTags: item.behaviorTags
        )
    }

    /// 为待购条目安排“冷静期结束 + 24 小时追提醒”。
    func scheduleCooldownDecisionReminders(for item: Item) async {
        guard item.status == .wish, let cooldownEndAt = item.cooldownEndAt else {
            cancelCooldownDecisionReminders(for: item.id)
            return
        }

        cancelCooldownDecisionReminders(for: item.id)

        let now = Date.now
        if cooldownEndAt > now {
            await scheduleDateReminder(
                identifier: notificationIdentifier(for: item.id, type: .cooldownReady),
                title: AppConstants.Notification.title,
                body: AppConstants.RoastCopy.cooldownReady(
                    itemName: item.displayName,
                    itemID: item.id,
                    primaryCategory: item.primaryCategory,
                    secondaryCategory: item.secondaryCategory,
                    behaviorTags: item.behaviorTags
                ),
                triggerDate: cooldownEndAt
            )
        }

        let followupAt = cooldownEndAt.addingTimeInterval(AppConstants.Notification.cooldownDecisionFollowupDelay)
        if followupAt > now {
            await scheduleDateReminder(
                identifier: notificationIdentifier(for: item.id, type: .cooldownFollowup),
                title: AppConstants.Notification.title,
                body: AppConstants.RoastCopy.cooldownFollowup(
                    itemName: item.displayName,
                    itemID: item.id,
                    primaryCategory: item.primaryCategory,
                    secondaryCategory: item.secondaryCategory,
                    behaviorTags: item.behaviorTags
                ),
                triggerDate: followupAt
            )
        }
    }

    /// 清理指定物品的吃灰提醒。
    func cancelIdleReminders(for itemID: UUID) {
        center.removePendingNotificationRequests(
            withIdentifiers: [
                notificationIdentifier(for: itemID, type: .light),
                notificationIdentifier(for: itemID, type: .strong)
            ]
        )
    }

    /// 清理指定物品的冷静期决策提醒。
    func cancelCooldownDecisionReminders(for itemID: UUID) {
        center.removePendingNotificationRequests(
            withIdentifiers: [
                notificationIdentifier(for: itemID, type: .cooldownReady),
                notificationIdentifier(for: itemID, type: .cooldownFollowup)
            ]
        )
    }

    /// 清理指定物品的“吃灰处置追提醒”。
    func cancelRescueReminder(for itemID: UUID) {
        center.removePendingNotificationRequests(
            withIdentifiers: [notificationIdentifier(for: itemID, type: .rescueFollowup)]
        )
    }

    /// 清理指定物品的全部提醒。
    func cancelAllReminders(for itemID: UUID) {
        cancelIdleReminders(for: itemID)
        cancelCooldownDecisionReminders(for: itemID)
        cancelRescueReminder(for: itemID)
    }

    /// 安排“7天后再提醒我处置”通知：用于吃灰挽救页面的一键追提醒。
    func scheduleRescueReminder(for item: Item, days: Int = 7) async {
        guard item.status == .purchased else {
            cancelRescueReminder(for: item.id)
            return
        }
        guard days > 0 else { return }

        cancelRescueReminder(for: item.id)
        guard let triggerDate = calendar.date(byAdding: .day, value: days, to: Date.now) else {
            return
        }

        let projectedIdleDays: Int = {
            guard let baseDate = item.lastUsedAt ?? item.purchaseAt else {
                return max(days, 1)
            }
            let baseStart = calendar.startOfDay(for: baseDate)
            let triggerStart = calendar.startOfDay(for: triggerDate)
            let raw = calendar.dateComponents([.day], from: baseStart, to: triggerStart).day ?? days
            return max(raw, 1)
        }()

        await scheduleDateReminder(
            identifier: notificationIdentifier(for: item.id, type: .rescueFollowup),
            title: AppConstants.Notification.title,
            body: AppConstants.RoastCopy.idleRescueFollowup(
                itemName: item.displayName,
                idleDays: projectedIdleDays,
                itemID: item.id,
                primaryCategory: item.primaryCategory,
                secondaryCategory: item.secondaryCategory,
                behaviorTags: item.behaviorTags
            ),
            triggerDate: triggerDate
        )
    }

    /// 安排单条吃灰提醒。
    private func scheduleIdleReminder(
        itemID: UUID,
        itemName: String,
        baseDate: Date,
        idleDays: Int,
        isStrong: Bool,
        primaryCategory: ItemPrimaryCategory,
        secondaryCategory: ItemSecondaryCategory,
        behaviorTags: [ItemBehaviorTag]
    ) async {
        guard let targetDate = calendar.date(byAdding: .day, value: idleDays, to: baseDate) else {
            return
        }

        var components = calendar.dateComponents([.year, .month, .day], from: targetDate)
        components.hour = AppConstants.Notification.reminderHour
        components.minute = AppConstants.Notification.reminderMinute
        components.second = 0

        guard let triggerDate = calendar.date(from: components), triggerDate > Date.now else {
            return
        }

        let type: ReminderType = isStrong ? .strong : .light
        await scheduleDateReminder(
            identifier: notificationIdentifier(for: itemID, type: type),
            title: AppConstants.Notification.title,
            body: isStrong
                ? AppConstants.RoastCopy.strong(
                    itemName: itemName,
                    idleDays: idleDays,
                    itemID: itemID,
                    primaryCategory: primaryCategory,
                    secondaryCategory: secondaryCategory,
                    behaviorTags: behaviorTags
                )
                : AppConstants.RoastCopy.light(
                    itemName: itemName,
                    idleDays: idleDays,
                    itemID: itemID,
                    primaryCategory: primaryCategory,
                    secondaryCategory: secondaryCategory,
                    behaviorTags: behaviorTags
                ),
            triggerDate: triggerDate
        )
    }

    /// 按指定日期安排单条本地通知。
    private func scheduleDateReminder(
        identifier: String,
        title: String,
        body: String,
        triggerDate: Date
    ) async {
        guard triggerDate > Date.now else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await add(request)
        } catch {
            #if DEBUG
            print("通知创建失败：\(error.localizedDescription)")
            #endif
        }
    }

    /// 将回调式 API 转为 async，便于上层串行调度。
    private func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    /// 统一通知 ID，确保可精准覆盖与删除。
    private func notificationIdentifier(for itemID: UUID, type: ReminderType) -> String {
        "notify.\(type.rawValue).\(itemID.uuidString)"
    }

    // MARK: - Debug Mock 通知
    /// 发送调试通知（秒级），仅用于真机联调。
    func scheduleDebugNotification(title: String, body: String, after seconds: TimeInterval = 3) async {
        let safeSeconds = max(1, seconds)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "debug.\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: safeSeconds, repeats: false)
        )

        do {
            try await add(request)
        } catch {
            #if DEBUG
            print("调试通知创建失败：\(error.localizedDescription)")
            #endif
        }
    }
}

/// 提醒类型：用于区分不同业务通知。
private enum ReminderType: String {
    case light
    case strong
    case cooldownReady
    case cooldownFollowup
    case rescueFollowup
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// 允许通知在前台也展示横幅，方便真机联调。
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .badge, .sound]
    }
}
