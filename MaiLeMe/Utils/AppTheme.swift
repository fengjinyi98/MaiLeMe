//
//  AppTheme.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import SwiftUI

/// 全局视觉主题：统一颜色、圆角、间距与动效。
/// 现已全面升级为多邻国(Duolingo)风格的 3D 厚重、活泼感。
enum AppTheme {
    /// 颜色体系。
    enum Palette {
        /// 页面背景色（纯白或极浅的灰），突出卡片内容。
        static let canvas = Color(red: 0.96, green: 0.97, blue: 0.98)

        /// 正文主文字（极深墨蓝或纯黑，对比度极高）。
        static let primaryText = Color(red: 0.08, green: 0.09, blue: 0.11)
        /// 正文次级文字。
        static let secondaryText = Color(red: 0.45, green: 0.48, blue: 0.52)
        /// 低强调信息。
        static let tertiaryText = Color(red: 0.68, green: 0.71, blue: 0.75)

        /// 全局强调色（多邻国风格的亮天蓝）。
        static let accent = Color(red: 0.11, green: 0.69, blue: 0.96)
        /// 冷静中的提示色（饱和度更高的深蓝）。
        static let cooling = Color(red: 0.20, green: 0.40, blue: 0.95)
        /// 收益/完成提示色（多邻国标志性亮绿）。
        static let success = Color(red: 0.35, green: 0.80, blue: 0.0)
        /// 风险/高吃灰提示色（鲜艳的橘红/橘黄）。
        static let warning = Color(red: 1.00, green: 0.58, blue: 0.00)

        /// 卡片背景色（纯白）。
        static let cardFill = Color.white
        /// 卡片边框色（比之前更深，用于勾勒形状，常为浅灰带点蓝）。
        static let cardStroke = Color(red: 0.89, green: 0.91, blue: 0.93)
        /// 卡片阴影色（完全不透明的浅灰蓝，模拟物理厚度）。
        static let cardShadow = Color(red: 0.82, green: 0.85, blue: 0.88)
        
        /// 进度条背景轨道色。
        static let progressTrack = Color(red: 0.89, green: 0.91, blue: 0.93)
    }

    /// 圆角体系：更加肥硕圆滑。
    enum Radius {
        static let card: CGFloat = 20
        static let chip: CGFloat = 999
    }

    /// 全局动效：极致 Q 弹。
    enum Motion {
        /// 替代一切常规 Spring 的极具弹性的物理反馈。
        static let bouncySpring = Animation.spring(response: 0.45, dampingFraction: 0.6, blendDuration: 0)
        /// 较硬的弹簧反馈，用于快速的、厚重的面板。
        static let rigidSpring = Animation.spring(response: 0.3, dampingFraction: 0.65, blendDuration: 0)
        
        /// (保留向下兼容)
        static let cardSpring = bouncySpring
        static let cardFloat = Animation.easeInOut(duration: 4).repeatForever(autoreverses: true)
    }
}
