//
//  ProgressBarView.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import SwiftUI

/// 多邻国风格 3D 果冻进度条：粗圆的轨道伴随顶部高光，视觉更亲和、饱满。
struct ProgressBarView: View {
    /// 进度值，取值范围 0.0 ~ 1.0。
    let progress: Double
    /// 前景色主色调。
    var tintColor: Color = AppTheme.Palette.success
    /// 轨道高度，多邻国风格明显更粗。
    var height: CGFloat = 22

    /// 动画中的进度值，用于实现弹性过渡。
    @State private var animatedProgress: Double = 0
    /// 百分比文本缩放值，用于模拟轻微弹跳反馈。
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
            let labelFontSize = max(11, height * 0.55)

            ZStack(alignment: .leading) {
                // 1. 背景轨道
                Capsule()
                    .fill(AppTheme.Palette.progressTrack)

                // 2. 进度填充层 (3D 果冻质感)
                ZStack(alignment: .top) {
                    // 主填充色
                    Capsule()
                        .fill(tintColor)
                        
                    // 顶部高光 (Specular Highlight) 制造 3D 圆柱体错觉
                    Capsule()
                        .fill(Color.white.opacity(0.3))
                        .padding(.horizontal, 4)
                        .padding(.top, 3)
                        .frame(height: height * 0.35)
                }
                .clipShape(Capsule())
                .frame(width: max(fillWidth, animatedProgress == 0 ? 0 : height))
                .overlay(alignment: .trailing) {
                    // 终点处的白色光晕（可选保留，增加灵动感）
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: max(height - 8, 6), height: max(height - 8, 6))
                        .padding(.trailing, 4)
                        .opacity(animatedProgress > 0.05 ? 1 : 0)
                }
                // 使用全局设定的超弹动画
                .animation(AppTheme.Motion.bouncySpring, value: animatedProgress)
            }
            .overlay {
                // 进度文字
                Text("\(Int((animatedProgress * 100).rounded()))%")
                    .font(.system(size: labelFontSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(animatedProgress >= 0.45 ? Color.white : AppTheme.Palette.primaryText)
                    .scaleEffect(percentScale)
                    .contentTransition(.numericText())
                    // 增加微小的文字阴影使其在 3D 圆柱上更容易识别
                    .shadow(color: animatedProgress >= 0.45 ? Color.black.opacity(0.15) : .clear, radius: 1, x: 0, y: 1)
            }
            .onAppear {
                animatedProgress = clampedTarget
            }
            .onDisappear {
                percentBounceTask?.cancel()
                percentBounceTask = nil
            }
            .onChange(of: clampedTarget, initial: false) { _, newValue in
                withAnimation(AppTheme.Motion.bouncySpring) {
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
        withAnimation(AppTheme.Motion.rigidSpring) {
            percentScale = 1.15
        }
        percentBounceTask = Task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                withAnimation(AppTheme.Motion.rigidSpring) {
                    percentScale = 1
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        ProgressBarView(progress: 0.15, tintColor: AppTheme.Palette.warning)
        ProgressBarView(progress: 0.82, tintColor: AppTheme.Palette.success)
    }
    .padding()
}
