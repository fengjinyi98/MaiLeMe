//
//  SolidActionButtonStyle.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import SwiftUI

/// 纯色按钮样式：多邻国风格的 3D 物理按键。
/// 具有厚重的底部阴影，按下时具备真实的物理位移感。
struct SolidActionButtonStyle: ButtonStyle {
    let tint: Color

    init(tint: Color = AppTheme.Palette.accent) {
        self.tint = tint
    }

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            // 底部阴影层（物理厚度）
            RoundedRectangle(cornerRadius: AppTheme.Radius.card * 0.8, style: .continuous)
                // 使用主色叠加变暗（模拟同色系的深色阴影）
                .fill(tint)
                .colorMultiply(Color(white: 0.8))
                .offset(y: configuration.isPressed ? 0 : 5)
            
            // 顶部交互内容层
            configuration.label
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.card * 0.8, style: .continuous)
                        .fill(tint)
                )
                // 当按下时，上方内容向下位移，模拟压下去的物理感
                .offset(y: configuration.isPressed ? 5 : 0)
        }
        // 为了避免挤压外部布局，固定下边缘的高度占用
        .padding(.bottom, configuration.isPressed ? 0 : 5)
        .animation(AppTheme.Motion.bouncySpring, value: configuration.isPressed)
    }
}
