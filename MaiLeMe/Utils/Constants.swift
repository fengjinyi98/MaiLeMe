//
//  Constants.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import Foundation

/// 全局常量集中管理，避免魔法数字和散落文案。
enum AppConstants {
    /// 本地通知相关常量。
    enum Notification {
        /// 轻提醒阈值：连续未使用天数达到该值时提醒。
        static let lightIdleDays = 7
        /// 强提醒阈值：连续未使用天数达到该值时提醒。
        static let strongIdleDays = 30

        /// 提醒触发时间（本地时区）。
        static let reminderHour = 20
        static let reminderMinute = 30

        /// 通知标题。
        static let title = "买了么提醒"
        /// 冷静期结束后，首次决策提醒延迟（秒）。
        static let cooldownDecisionFollowupDelay: TimeInterval = 24 * 60 * 60
    }

    /// 毒舌文案池。
    enum RoastCopy {
        /// 轻提醒文案模板（第一个参数：物品名；第二个参数：吃灰天数）。
        private static let lightTemplates: [String] = [
            "你的 %@ 已经 %@ 天没碰了，今晚打个卡不过分吧？",
            "%@ 已经静置 %@ 天，再放下去都要进博物馆了。",
            "提醒一下：%@ 已经吃灰 %@ 天，别只会下单不会使用。"
        ]

        /// 强提醒文案模板（第一个参数：物品名；第二个参数：吃灰天数）。
        private static let strongTemplates: [String] = [
            "%@ 已经落灰 %@ 天，建议直奔二手平台回血。",
            "你和 %@ 已经 %@ 天没互动了，这段关系还要继续吗？",
            "%@ 吃灰 %@ 天：当初的“提升效率”计划还在吗？"
        ]

        /// 冷静期结束提醒文案（参数：物品名）。
        private static let cooldownReadyTemplates: [String] = [
            "冷静期已结束：%@，现在请用理性而不是手速做决定。",
            "%@ 已出小黑屋，轮到你决定是省钱还是下单。",
            "提醒：%@ 到期了，今天必须给个说法。"
        ]

        /// 冷静期结束后未决策的追提醒文案（参数：物品名）。
        private static let cooldownFollowupTemplates: [String] = [
            "%@ 到期后你还没决策，是准备拖到下次冲动吗？",
            "24 小时过去了，%@ 仍在等待判决。",
            "还没决定 %@？拖延也是一种消费陷阱。"
        ]

        /// 生成轻提醒文案。
        static func light(itemName: String, idleDays: Int) -> String {
            format(templateFrom: lightTemplates, itemName: itemName, idleDays: idleDays)
        }

        /// 生成强提醒文案。
        static func strong(itemName: String, idleDays: Int) -> String {
            format(templateFrom: strongTemplates, itemName: itemName, idleDays: idleDays)
        }

        /// 生成冷静期结束提醒文案。
        static func cooldownReady(itemName: String) -> String {
            format(templateFrom: cooldownReadyTemplates, itemName: itemName)
        }

        /// 生成冷静期结束追提醒文案。
        static func cooldownFollowup(itemName: String) -> String {
            format(templateFrom: cooldownFollowupTemplates, itemName: itemName)
        }

        /// 从模板池随机抽取一条并格式化。
        private static func format(templateFrom templates: [String], itemName: String, idleDays: Int) -> String {
            let template = templates.randomElement() ?? "%@ 已经 %@ 天未使用。"
            return String(format: template, itemName, "\(idleDays)")
        }

        /// 从模板池随机抽取一条并格式化（仅物品名参数）。
        private static func format(templateFrom templates: [String], itemName: String) -> String {
            let template = templates.randomElement() ?? "%@ 需要你做决定。"
            return String(format: template, itemName)
        }
    }
}
