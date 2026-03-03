//
//  HapticFeedback.swift
//  MaiLeMe
//
//  Created by Codex on 2026/3/3.
//

import UIKit

/// 触感反馈工具：统一管理关键操作的震动节奏。
enum HapticFeedback {
    /// 打卡成功反馈；关键里程碑会追加一次更强的冲击反馈。
    static func checkinSuccess(isBigMoment: Bool) {
        let notification = UINotificationFeedbackGenerator()
        notification.prepare()
        notification.notificationOccurred(.success)

        let impact = UIImpactFeedbackGenerator(style: isBigMoment ? .rigid : .light)
        impact.prepare()
        impact.impactOccurred(intensity: isBigMoment ? 1.0 : 0.65)
    }

    /// 冷静期决策成功反馈：两条路径都提供强烈确认感。
    static func decisionCompleted(isSaved: Bool) {
        let notification = UINotificationFeedbackGenerator()
        notification.prepare()
        notification.notificationOccurred(.success)

        let impact = UIImpactFeedbackGenerator(style: isSaved ? .heavy : .rigid)
        impact.prepare()
        impact.impactOccurred(intensity: isSaved ? 0.95 : 1.0)
    }
}
