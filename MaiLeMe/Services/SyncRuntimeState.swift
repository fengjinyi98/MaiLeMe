//
//  SyncRuntimeState.swift
//  MaiLeMe
//
//  Created by Codex on 2026/3/3.
//

import Foundation
import Combine

/// 同步模式：用于展示“当前是否实际在走 CloudKit”。
enum SyncEffectiveMode {
    /// 已启用 CloudKit 私有库同步。
    case cloudPrivate
    /// 回退到本地数据库（可能因为用户关闭 iCloud、权限或容器配置问题）。
    case localOnly
}

/// 同步运行时状态：用于设置页展示和文案提示。
@MainActor
final class SyncRuntimeState: ObservableObject {
    /// 用户偏好开关（设置后需重启生效）。
    @Published var preferredCloudSync: Bool
    /// 当前生效模式（启动时判定）。
    @Published var effectiveMode: SyncEffectiveMode
    /// 启动时同步初始化提示（例如 CloudKit 初始化失败原因）。
    @Published var launchMessage: String?

    init(
        preferredCloudSync: Bool,
        effectiveMode: SyncEffectiveMode,
        launchMessage: String?
    ) {
        self.preferredCloudSync = preferredCloudSync
        self.effectiveMode = effectiveMode
        self.launchMessage = launchMessage
    }

    /// 当前生效模式文案。
    var effectiveModeText: String {
        switch effectiveMode {
        case .cloudPrivate:
            return "iCloud 私有同步已生效"
        case .localOnly:
            return "当前仅本地存储"
        }
    }

    /// 当前生效模式说明。
    var effectiveModeDescription: String {
        switch effectiveMode {
        case .cloudPrivate:
            return "数据会同步到你的 iCloud 私有空间，无需额外登录。"
        case .localOnly:
            return "数据只保存在本机。请检查 iCloud 登录状态或容器配置。"
        }
    }

    /// 更新用户偏好（切换后由 UI 提示重启生效）。
    func updatePreferredCloudSync(_ enabled: Bool) {
        preferredCloudSync = enabled
    }
}
