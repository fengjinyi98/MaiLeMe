//
//  DecisionCelebrationOverlay.swift
//  MaiLeMe
//
//  Created by Codex on 2026/3/3.
//

import SwiftUI

/// 冷静期决策仪式弹层：用于“忍住没买 / 还是买了”后的统一反馈。
struct DecisionCelebrationOverlay: View {
    let payload: DarkRoomDecisionCelebrationPayload
    let onDismiss: () -> Void

    @State private var animateEntry = false
    @State private var animatePulse = false

    private var accent: Color {
        switch payload.tone {
        case .saved:
            return AppTheme.Palette.success
        case .purchased:
            return AppTheme.Palette.accent
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(animateEntry ? 0.34 : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.22))
                        .frame(width: 94, height: 94)
                        .scaleEffect(animatePulse ? 1.1 : 0.92)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: animatePulse)

                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: 74, height: 74)

                    Image(systemName: payload.iconSystemName)
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(accent)
                }

                Text(payload.badge)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(accent.opacity(0.15))
                    )

                Text(payload.title)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.Palette.primaryText)
                    .multilineTextAlignment(.center)

                Text(payload.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.secondaryText)
                    .multilineTextAlignment(.center)

                VStack(spacing: 3) {
                    Text(payload.metricTitle)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.Palette.tertiaryText)
                    Text(payload.metricValue)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.Palette.primaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.Palette.progressTrack.opacity(0.52))
                )

                Button(payload.actionTitle) {
                    onDismiss()
                }
                .buttonStyle(SolidActionButtonStyle(tint: accent))
                .padding(.top, 2)
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppTheme.Palette.cardStroke, lineWidth: 1)
            )
            .padding(.horizontal, 28)
            .scaleEffect(animateEntry ? 1 : 0.84)
            .opacity(animateEntry ? 1 : 0)
            .shadow(color: Color.black.opacity(0.15), radius: 18, x: 0, y: 9)
        }
        .onAppear {
            withAnimation(.spring(response: 0.46, dampingFraction: 0.8)) {
                animateEntry = true
            }
            animatePulse = true
        }
    }
}
