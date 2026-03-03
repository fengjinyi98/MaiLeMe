//
//  GlassCardView.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import SwiftUI

/// 多邻国风格 3D 卡片：厚边框 + 完全不透明的硬实体下边缘阴影。
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

        ZStack {
            // 底层物理厚度（阴影块），向下偏移
            cardShape
                .fill(AppTheme.Palette.cardShadow)
                .offset(y: 5)

            // 上层主体内容
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(padding)
                .background(cardShape.fill(AppTheme.Palette.cardFill))
                .clipShape(cardShape)
                // 仅对上层进行粗犷线框描边
                .overlay(cardShape.stroke(AppTheme.Palette.cardStroke, lineWidth: 2.0))
        }
        // 为了整体布局不被挤压，将下方因偏移产生的 5pt 空间用 padding 撑开，让 SwiftUI 布局系统能感知到
        .padding(.bottom, 5)
    }
}
