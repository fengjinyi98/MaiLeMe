//
//  CardRevealModifier.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import SwiftUI

/// 卡片入场动效修饰器：用于减轻首屏“突然出现”的生硬感。
private struct CardRevealModifier: ViewModifier {
    let isVisible: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 16)
            .scaleEffect(isVisible ? 1 : 0.98)
            .animation(AppTheme.Motion.cardSpring.delay(delay), value: isVisible)
    }
}

extension View {
    /// 统一卡片入场效果。
    func cardReveal(isVisible: Bool, delay: Double) -> some View {
        modifier(CardRevealModifier(isVisible: isVisible, delay: delay))
    }
}
