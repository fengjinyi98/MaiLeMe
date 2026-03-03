//
//  DuolingoButtonStyle.swift
//  MaiLeMe
//
//  Created by Codex on 2026/3/3.
//

import SwiftUI

/// 多邻国风格 3D 按钮：厚重、夸张的物理下压反馈。
struct DuolingoButtonStyle: ButtonStyle {
    let tint: Color
    
    // 阴影颜色通常是主色的加深版
    private var shadowColor: Color {
        // 简单处理：使用默认自带的暗色或者基于传入颜色加深（这里使用系统黑色的透明度混合模拟）
        // 更优雅的做法是使用 UIColor 提取暗部，但 SwiftUI 原生可以通过叠在一个稍暗的层上实现。
        // 为了方便，直接使用明确的基于亮度的加深，或使用固定的半透明黑。
        tint.opacity(0.7) // 在实际深色的下面作为占位可能不够，我们使用混合
    }
    
    init(tint: Color = AppTheme.Palette.accent) {
        self.tint = tint
    }
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            // 底部阴影层（厚度）
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                // 模拟加深：一种简单安全的暗化方式
                .fill(tint)
                .colorMultiply(Color(white: 0.75))
                .offset(y: configuration.isPressed ? 0 : 6)
            
            // 顶部交互层
            configuration.label
                .font(.headline.weight(.bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint)
                )
                .offset(y: configuration.isPressed ? 6 : 0)
        }
        // 当按下时，整个按钮高度变矮，视觉上体现物理压缩
        .frame(height: 50 + (configuration.isPressed ? 6 : 12)) // 让外层布局不跳动太厉害，或者干脆约束整个外框
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// 预览辅助
struct DuolingoButtonStyle_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            Button("继续榨干") {}
                .buttonStyle(DuolingoButtonStyle(tint: AppTheme.Palette.success))
            
            Button("跳过") {}
                .buttonStyle(DuolingoButtonStyle(tint: AppTheme.Palette.tertiaryText))
        }
        .padding()
    }
}
