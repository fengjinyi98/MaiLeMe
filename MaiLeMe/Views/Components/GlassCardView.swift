//
//  GlassCardView.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import SwiftUI

/// 通用卡片容器，Telegram 风格：纯白背景 + 细边框 + 轻阴影。
struct GlassCardView<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    init(
        accent: Color = AppTheme.Palette.accent,
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        let cardShape = RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)

        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(AppTheme.Palette.cardFill)
            .clipShape(cardShape)
            .overlay(cardShape.stroke(AppTheme.Palette.cardStroke, lineWidth: 0.5))
            .shadow(color: AppTheme.Palette.cardShadow, radius: 4, x: 0, y: 2)
    }
}
