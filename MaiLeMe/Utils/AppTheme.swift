//
//  AppTheme.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import SwiftUI
import UIKit

/// 全局视觉主题：统一颜色、圆角、间距与动效。
/// 现已全面升级为多邻国(Duolingo)风格的 3D 厚重、活泼感。
enum AppTheme {
    /// 动态色工厂：根据系统深浅色返回不同颜色。
    private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(
            UIColor { trait in
                trait.userInterfaceStyle == .dark ? dark : light
            }
        )
    }

    /// 颜色体系。
    enum Palette {
        /// 页面背景色：适配系统深浅色。
        static let canvas = AppTheme.dynamicColor(
            light: UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1),
            dark: UIColor(red: 0.07, green: 0.08, blue: 0.10, alpha: 1)
        )

        /// 正文主文字：浅色模式深字，深色模式浅字。
        static let primaryText = AppTheme.dynamicColor(
            light: UIColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1),
            dark: UIColor(red: 0.93, green: 0.95, blue: 0.98, alpha: 1)
        )
        /// 正文次级文字。
        static let secondaryText = AppTheme.dynamicColor(
            light: UIColor(red: 0.45, green: 0.48, blue: 0.52, alpha: 1),
            dark: UIColor(red: 0.70, green: 0.74, blue: 0.80, alpha: 1)
        )
        /// 低强调信息。
        static let tertiaryText = AppTheme.dynamicColor(
            light: UIColor(red: 0.68, green: 0.71, blue: 0.75, alpha: 1),
            dark: UIColor(red: 0.50, green: 0.55, blue: 0.63, alpha: 1)
        )

        /// 全局强调色（多邻国风格的亮天蓝）。
        static let accent = Color(red: 0.11, green: 0.69, blue: 0.96)
        /// 冷静中的提示色（饱和度更高的深蓝）。
        static let cooling = Color(red: 0.20, green: 0.40, blue: 0.95)
        /// 收益/完成提示色（多邻国标志性亮绿）。
        static let success = Color(red: 0.35, green: 0.80, blue: 0.0)
        /// 风险/高吃灰提示色（鲜艳的橘红/橘黄）。
        static let warning = Color(red: 1.00, green: 0.58, blue: 0.00)

        /// 卡片背景色：深色模式下切换为深面板色，避免白卡刺眼。
        static let cardFill = AppTheme.dynamicColor(
            light: UIColor.white,
            dark: UIColor(red: 0.12, green: 0.14, blue: 0.18, alpha: 1)
        )
        /// 卡片边框色：深色模式下改为更深边框。
        static let cardStroke = AppTheme.dynamicColor(
            light: UIColor(red: 0.89, green: 0.91, blue: 0.93, alpha: 1),
            dark: UIColor(red: 0.26, green: 0.30, blue: 0.36, alpha: 1)
        )
        /// 卡片阴影色：深色模式下改为黑色阴影，保持层次。
        static let cardShadow = AppTheme.dynamicColor(
            light: UIColor(red: 0.82, green: 0.85, blue: 0.88, alpha: 1),
            dark: UIColor(white: 0, alpha: 0.55)
        )

        /// 进度条背景轨道色。
        static let progressTrack = AppTheme.dynamicColor(
            light: UIColor(red: 0.89, green: 0.91, blue: 0.93, alpha: 1),
            dark: UIColor(red: 0.22, green: 0.26, blue: 0.32, alpha: 1)
        )

        /// 芯片/轻背景填充色：替代硬编码白色透明背景。
        static let softSurface = AppTheme.dynamicColor(
            light: UIColor(white: 1.0, alpha: 0.62),
            dark: UIColor(white: 1.0, alpha: 0.14)
        )

        /// 浅层输入/占位面板背景色。
        static let inputFill = AppTheme.dynamicColor(
            light: UIColor(white: 1.0, alpha: 0.96),
            dark: UIColor(red: 0.17, green: 0.20, blue: 0.25, alpha: 0.96)
        )
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
