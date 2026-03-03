//
//  SolidActionButtonStyle.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import SwiftUI

/// 纯色按钮样式：避免系统默认按钮的半透明灰色蒙层。
struct SolidActionButtonStyle: ButtonStyle {
    let tint: Color

    init(tint: Color = AppTheme.Palette.accent) {
        self.tint = tint
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.82 : 1.0))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
