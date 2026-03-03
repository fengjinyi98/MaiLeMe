//
//  CloudSyncPreferences.swift
//  MaiLeMe
//
//  Created by Codex on 2026/3/3.
//

import Foundation

/// iCloud 同步偏好配置：统一管理开关键名与默认值。
enum CloudSyncPreferences {
    /// 用户偏好：是否启用 iCloud 同步（需重启后生效）。
    static let isEnabledKey = "cloudSyncEnabled"
    /// 默认关闭：避免在未配置 iCloud Capability 时启动阶段触发崩溃。
    static let defaultEnabled = false
    /// Info.plist 开关：只有在能力配置完成后才允许尝试 CloudKit 容器。
    static let buildReadyInfoKey = "MaiLeMeCloudKitReady"

    /// 当前构建是否允许启用 CloudKit。
    static var isCloudKitBuildReady: Bool {
        (Bundle.main.object(forInfoDictionaryKey: buildReadyInfoKey) as? Bool) ?? false
    }
}
