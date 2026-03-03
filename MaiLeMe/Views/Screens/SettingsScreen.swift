//
//  SettingsScreen.swift
//  MaiLeMe
//
//  Created by Codex on 2026/3/3.
//

import SwiftUI
import UserNotifications
import UIKit

/// 应用设置页：集中承载 iCloud 同步开关与账号状态展示。
struct SettingsScreen: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var syncRuntimeState: SyncRuntimeState
    @AppStorage(CloudSyncPreferences.isEnabledKey) private var cloudSyncEnabled = CloudSyncPreferences.defaultEnabled
    @AppStorage(AppConstants.UserDefaultsKeys.hasSeenOnboarding) private var hasSeenOnboarding = false

    @State private var accountStatusText = "正在检测 iCloud 账号状态..."
    @State private var accountStatusDetail = "请稍候"
    @State private var isCheckingAccountStatus = false
    @State private var showRestartHint = false
    @State private var notificationStatusText = "正在检测通知权限..."
    @State private var notificationStatusDetail = "请稍候"
    @State private var isCheckingNotificationStatus = false
    @State private var canRequestNotificationPermission = false
    @State private var shouldShowNotificationSettingsButton = false

    /// 当前构建是否已完成 CloudKit 能力配置。
    private var isCloudKitBuildReady: Bool {
        CloudSyncPreferences.isCloudKitBuildReady
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackgroundView()

                ScrollView {
                    VStack(spacing: 14) {
                        onboardingCard
                        notificationPermissionCard
                        syncModeCard
                        cloudToggleCard
                        iCloudAccountCard

                        if let launchMessage = syncRuntimeState.launchMessage, !launchMessage.isEmpty {
                            warningCard(message: launchMessage)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if !isCloudKitBuildReady, cloudSyncEnabled {
                    cloudSyncEnabled = false
                    syncRuntimeState.updatePreferredCloudSync(false)
                }
                await refreshNotificationPermissionStatus()
                await refreshICloudAccountStatus()
            }
            .onChange(of: cloudSyncEnabled, initial: false) { _, newValue in
                syncRuntimeState.updatePreferredCloudSync(newValue)
                showRestartHint = true
            }
            .alert("设置已更新", isPresented: $showRestartHint) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text("iCloud 同步开关会在下次启动 App 时生效。")
            }
        }
    }

    /// 引导卡片：便于用户重新查看核心玩法。
    private var onboardingCard: some View {
        GlassCardView(accent: AppTheme.Palette.cooling) {
            VStack(alignment: .leading, spacing: 10) {
                Text("新手引导")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.primaryText)

                Text("如果忘了流程，可以随时重新看一遍“冷静 -> 打卡 -> 复盘”的完整闭环。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Palette.secondaryText)

                Button {
                    hasSeenOnboarding = false
                } label: {
                    Label("重新查看引导", systemImage: "sparkles.rectangle.stack")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SolidActionButtonStyle(tint: AppTheme.Palette.cooling))
            }
        }
    }

    /// 通知权限卡片：集中处理“未授权/被拒绝”的异常场景。
    private var notificationPermissionCard: some View {
        GlassCardView(accent: AppTheme.Palette.warning) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("通知权限")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.primaryText)
                    Spacer()
                    Button {
                        Task { await refreshNotificationPermissionStatus() }
                    } label: {
                        if isCheckingNotificationStatus {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Label("刷新", systemImage: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(SolidActionButtonStyle(tint: AppTheme.Palette.warning))
                    .frame(maxWidth: 110)
                    .disabled(isCheckingNotificationStatus)
                }

                metricRow(title: "当前状态", value: notificationStatusText)
                Text(notificationStatusDetail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Palette.tertiaryText)

                HStack(spacing: 10) {
                    if canRequestNotificationPermission {
                        Button {
                            Task { await requestNotificationPermission() }
                        } label: {
                            Label("申请权限", systemImage: "bell.badge")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SolidActionButtonStyle(tint: AppTheme.Palette.accent))
                    }

                    if shouldShowNotificationSettingsButton {
                        Button {
                            openSystemSettings()
                        } label: {
                            Label("去系统设置", systemImage: "gearshape")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SolidActionButtonStyle(tint: AppTheme.Palette.warning))
                    }
                }
            }
        }
    }

    /// 同步模式卡片：展示“偏好开关 + 当前生效状态”。
    private var syncModeCard: some View {
        GlassCardView(accent: AppTheme.Palette.cooling) {
            VStack(alignment: .leading, spacing: 10) {
                Text("同步状态")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.primaryText)

                metricRow(title: "当前生效", value: syncRuntimeState.effectiveModeText)
                metricRow(title: "用户偏好", value: cloudSyncEnabled ? "已开启 iCloud 同步" : "仅本地存储")

                Text(syncRuntimeState.effectiveModeDescription)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Palette.tertiaryText)
            }
        }
    }

    /// iCloud 开关卡片：控制下次启动时是否尝试 CloudKit。
    private var cloudToggleCard: some View {
        GlassCardView(accent: AppTheme.Palette.accent) {
            VStack(alignment: .leading, spacing: 12) {
                Text("iCloud 同步")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.primaryText)

                Toggle(isOn: $cloudSyncEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("启用私有 iCloud 同步")
                            .foregroundStyle(AppTheme.Palette.primaryText)
                        Text(isCloudKitBuildReady ? "无需登录页，直接使用系统 Apple ID" : "当前构建未完成 CloudKit 能力配置，暂不可开启")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Palette.tertiaryText)
                    }
                }
                .tint(AppTheme.Palette.accent)
                .disabled(!isCloudKitBuildReady)

                if !isCloudKitBuildReady {
                    Text("请先在 Xcode 打开 iCloud/CloudKit capability，并在 Info.plist 设置 `\(CloudSyncPreferences.buildReadyInfoKey)=YES`。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Palette.warning)
                }
            }
        }
    }

    /// iCloud 账号状态卡片：帮助用户快速判断“为什么没同步”。
    private var iCloudAccountCard: some View {
        GlassCardView(accent: AppTheme.Palette.success) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("iCloud 账号检测")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.primaryText)
                    Spacer()
                    Button {
                        Task {
                            await refreshICloudAccountStatus()
                        }
                    } label: {
                        if isCheckingAccountStatus {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Label("重新检测", systemImage: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(SolidActionButtonStyle(tint: AppTheme.Palette.success))
                    .frame(maxWidth: 140)
                    .disabled(isCheckingAccountStatus || !isCloudKitBuildReady)
                }

                metricRow(title: "检测结果", value: accountStatusText)
                Text(accountStatusDetail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Palette.tertiaryText)
            }
        }
    }

    /// 启动告警卡片：例如 CloudKit 初始化失败提示。
    private func warningCard(message: String) -> some View {
        GlassCardView(accent: AppTheme.Palette.warning) {
            VStack(alignment: .leading, spacing: 8) {
                Text("同步告警")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.primaryText)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Palette.secondaryText)
            }
        }
    }

    /// 指标行样式。
    private func metricRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(AppTheme.Palette.secondaryText)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(AppTheme.Palette.primaryText)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    /// 检测 iCloud 账号状态。
    @MainActor
    private func refreshICloudAccountStatus() async {
        isCheckingAccountStatus = true
        defer { isCheckingAccountStatus = false }

        // 未完成 CloudKit 能力配置时，禁止触发 CloudKit API，避免 entitlement 断点崩溃。
        guard isCloudKitBuildReady else {
            accountStatusText = "未启用"
            accountStatusDetail = "当前构建未启用 CloudKit capability，已跳过 iCloud 账号检测。"
            return
        }

        // 采用安全检测：不直接调用 CKContainer，避免 entitlement 缺失时触发 EXC_BREAKPOINT。
        if FileManager.default.ubiquityIdentityToken != nil {
            accountStatusText = "可用"
            accountStatusDetail = "检测到系统 iCloud 账号，满足私有同步前置条件。"
        } else {
            accountStatusText = "未登录或不可用"
            accountStatusDetail = "未检测到 iCloud 账号，请在系统设置中登录 Apple ID 后重试。"
        }
    }

    /// 刷新通知权限状态。
    @MainActor
    private func refreshNotificationPermissionStatus() async {
        isCheckingNotificationStatus = true
        defer { isCheckingNotificationStatus = false }

        let status = await NotificationManager.shared.currentAuthorizationStatus()
        canRequestNotificationPermission = false
        shouldShowNotificationSettingsButton = false

        switch status {
        case .notDetermined:
            notificationStatusText = "未请求"
            notificationStatusDetail = "还没有向你申请过通知权限。"
            canRequestNotificationPermission = true
        case .authorized:
            notificationStatusText = "已开启"
            notificationStatusDetail = "通知权限正常，冷静期与吃灰提醒可正常送达。"
        case .provisional:
            notificationStatusText = "临时授权"
            notificationStatusDetail = "已获得临时通知权限，建议到系统设置升级为完整授权。"
            shouldShowNotificationSettingsButton = true
        case .ephemeral:
            notificationStatusText = "临时会话授权"
            notificationStatusDetail = "当前为临时会话授权，建议到系统设置开启完整通知权限。"
            shouldShowNotificationSettingsButton = true
        case .denied:
            notificationStatusText = "已拒绝"
            notificationStatusDetail = "通知权限已被关闭，请到系统设置手动开启。"
            shouldShowNotificationSettingsButton = true
        @unknown default:
            notificationStatusText = "未知状态"
            notificationStatusDetail = "系统返回了未识别的通知状态，请稍后重试。"
        }
    }

    /// 主动申请通知权限。
    @MainActor
    private func requestNotificationPermission() async {
        do {
            _ = try await NotificationManager.shared.requestAuthorization()
        } catch {
            notificationStatusText = "申请失败"
            notificationStatusDetail = "通知权限申请失败：\(error.localizedDescription)"
        }
        await refreshNotificationPermissionStatus()
    }

    /// 跳转系统设置页。
    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

#Preview {
    SettingsScreen()
        .environmentObject(
            SyncRuntimeState(
                preferredCloudSync: true,
                effectiveMode: .cloudPrivate,
                launchMessage: nil
            )
        )
}
