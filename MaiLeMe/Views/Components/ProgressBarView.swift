//
//  ProgressBarView.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import SwiftUI

/// 简单的线性进度条组件，统一用于回本进度展示。
struct ProgressBarView: View {
    /// 进度值，取值范围 0.0 ~ 1.0。
    let progress: Double
    /// 前景色。
    var tintColor: Color = .green
    /// 轨道高度。
    var height: CGFloat = 14

    /// 动画中的进度值，用于实现弹性过渡。
    @State private var animatedProgress: Double = 0
    /// 百分比文本缩放值，用于模拟多邻国风格的轻微弹跳反馈。
    @State private var percentScale: CGFloat = 1
    /// 百分比弹跳任务，避免连续更新时叠加动画。
    @State private var percentBounceTask: Task<Void, Never>?

    /// 归一化后的目标进度。
    private var clampedTarget: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            let fillWidth = geometry.size.width * animatedProgress
            let labelFontSize = max(10, height * 0.62)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.Palette.progressTrack)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                tintColor.opacity(0.72),
                                tintColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(fillWidth, animatedProgress == 0 ? 0 : height))
                    .overlay(alignment: .trailing) {
                        // 终点高光点：增强“进度推进”动感，风格参考学习类产品的积极反馈。
                        Circle()
                            .fill(Color.white.opacity(0.42))
                            .frame(width: max(height - 4, 6), height: max(height - 4, 6))
                            .padding(.trailing, 2)
                            .opacity(animatedProgress > 0.01 ? 1 : 0)
                    }
                    .animation(.spring(response: 0.45, dampingFraction: 0.78), value: animatedProgress)
            }
            .overlay {
                Text("\(Int((animatedProgress * 100).rounded()))%")
                    .font(.system(size: labelFontSize, weight: .black, design: .rounded))
                    .foregroundStyle(animatedProgress >= 0.45 ? Color.white : AppTheme.Palette.primaryText)
                    .scaleEffect(percentScale)
                    .contentTransition(.numericText())
            }
            .onAppear {
                animatedProgress = clampedTarget
            }
            .onDisappear {
                percentBounceTask?.cancel()
                percentBounceTask = nil
            }
            .onChange(of: clampedTarget, initial: false) { _, newValue in
                withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                    animatedProgress = newValue
                }
                runPercentBounce()
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("进度条")
        .accessibilityValue("\(Int(clampedTarget * 100))%")
    }

    /// 触发一次百分比文本弹跳，强化“进度变化”的即时反馈。
    private func runPercentBounce() {
        percentBounceTask?.cancel()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) {
            percentScale = 1.08
        }
        percentBounceTask = Task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    percentScale = 1
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ProgressBarView(progress: 0.25, tintColor: .orange)
        ProgressBarView(progress: 0.72, tintColor: .green)
    }
    .padding()
}
