//
//  OnboardingScreen.swift
//  MaiLeMe
//
//  Created by Codex on 2026/3/3.
//

import SwiftUI

/// 首次引导页：帮助用户在 30 秒内理解「小黑屋 -> 榨干机 -> 看板复盘」的核心闭环。
struct OnboardingScreen: View {
    /// 结束引导回调。
    let onFinish: () -> Void

    @State private var hasAppeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackgroundView()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        heroCard
                            .cardReveal(isVisible: hasAppeared, delay: 0.02)

                        featureCard(
                            icon: "lock.shield.fill",
                            title: "冲动先关进小黑屋",
                            subtitle: "想买先记下来，强制冷静期结束后再做决定。",
                            tint: AppTheme.Palette.warning
                        )
                        .cardReveal(isVisible: hasAppeared, delay: 0.06)

                        featureCard(
                            icon: "bolt.fill",
                            title: "买了就去榨干机",
                            subtitle: "每次使用都打卡，把“买后吃灰”改成“持续回血”。",
                            tint: AppTheme.Palette.success
                        )
                        .cardReveal(isVisible: hasAppeared, delay: 0.1)

                        featureCard(
                            icon: "chart.bar.fill",
                            title: "看板复盘更上头",
                            subtitle: "省了多少钱、谁在吃灰，一眼看懂你的消费体质。",
                            tint: AppTheme.Palette.cooling
                        )
                        .cardReveal(isVisible: hasAppeared, delay: 0.14)

                        actionCard
                            .cardReveal(isVisible: hasAppeared, delay: 0.18)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("欢迎来到买了么")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                hasAppeared = true
            }
        }
        .interactiveDismissDisabled()
    }

    /// 头图卡片：突出产品主张。
    private var heroCard: some View {
        GlassCardView(accent: AppTheme.Palette.accent, padding: 20) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "brain.head.profile")
                        .font(.title3)
                        .foregroundStyle(AppTheme.Palette.accent)
                    Text("不做冲动消费的受害者")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.Palette.primaryText)
                }

                Text("记下冲动、执行冷静、持续打卡。让每一笔消费，都有结果。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.secondaryText)
            }
        }
    }

    /// 功能说明卡。
    private func featureCard(icon: String, title: String, subtitle: String, tint: Color) -> some View {
        GlassCardView(accent: tint) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.primaryText)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.secondaryText)
                }
            }
        }
    }

    /// 底部行动区。
    private var actionCard: some View {
        GlassCardView(accent: AppTheme.Palette.accent, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("准备好了就开始你的理性模式。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.secondaryText)

                Button {
                    onFinish()
                } label: {
                    Label("开始使用", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SolidActionButtonStyle(tint: AppTheme.Palette.accent))
            }
        }
    }
}

#Preview {
    OnboardingScreen(onFinish: {})
}
