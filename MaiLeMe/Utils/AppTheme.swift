//
//  AppTheme.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import SwiftUI

/// 全局视觉主题：统一颜色、圆角、间距与动效，避免样式散落在各页面。
enum AppTheme {
    /// 颜色体系。
    enum Palette {
        /// 页面背景色（Telegram 风格浅灰）。
        static let canvas = Color(red: 0.94, green: 0.94, blue: 0.96)

        /// 正文主文字。
        static let primaryText = Color(red: 0.10, green: 0.10, blue: 0.10)
        /// 正文次级文字。
        static let secondaryText = Color(red: 0.40, green: 0.40, blue: 0.44)
        /// 低强调信息。
        static let tertiaryText = Color(red: 0.60, green: 0.60, blue: 0.63)

        /// 全局强调色（Telegram 蓝）。
        static let accent = Color(red: 0.16, green: 0.67, blue: 0.93)
        /// 冷静中的提示色。
        static let cooling = Color(red: 0.35, green: 0.53, blue: 0.95)
        /// 收益/完成提示色（iOS 系统绿）。
        static let success = Color(red: 0.20, green: 0.78, blue: 0.35)
        /// 风险/高吃灰提示色（iOS 系统橙）。
        static let warning = Color(red: 1.00, green: 0.58, blue: 0.00)

        /// 卡片背景色（纯白）。
        static let cardFill = Color.white
        /// 卡片边框色。
        static let cardStroke = Color(red: 0.88, green: 0.88, blue: 0.90)
        /// 卡片阴影色。
        static let cardShadow = Color.black.opacity(0.06)
        /// 进度条轨道色。
        static let progressTrack = Color(red: 0.90, green: 0.90, blue: 0.92)
    }

    /// 圆角体系。
    enum Radius {
        static let card: CGFloat = 16
        static let chip: CGFloat = 999
    }

    /// 全局动效。
    enum Motion {
        static let cardSpring = Animation.spring(response: 0.5, dampingFraction: 0.82)
        static let cardFloat = Animation.easeInOut(duration: 8).repeatForever(autoreverses: true)
    }
}
