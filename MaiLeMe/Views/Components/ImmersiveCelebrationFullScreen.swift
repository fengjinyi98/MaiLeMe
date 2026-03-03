//
//  ImmersiveCelebrationFullScreen.swift
//  MaiLeMe
//
//  Created by Codex on 2026/3/3.
//

import SwiftUI

/// 榨干机打卡庆祝页快照：用于 `fullScreenCover(item:)`。
struct CheckinCelebrationSnapshot: Identifiable {
    let id = UUID()
    let payload: CheckinCelebrationPayload
    let itemName: String
    let usageCount: Int
    let currentCostText: String
    let imageData: Data?
}

/// 小黑屋决策庆祝页快照：用于 `fullScreenCover(item:)`。
struct DecisionCelebrationSnapshot: Identifiable {
    let id = UUID()
    let payload: DarkRoomDecisionCelebrationPayload
    let itemName: String
    let imageData: Data?
}

/// 榨干机打卡后的全屏仪式页：替代弹窗方案，提供更强烈的视觉与触觉反馈。
struct CheckinCelebrationFullScreen: View {
    let snapshot: CheckinCelebrationSnapshot
    let onComplete: () -> Void

    @State private var showHero = false
    @State private var showText = false
    @State private var showMetrics = false
    @State private var showButton = false
    @State private var confettiReady = false
    @State private var breathing = false
    @State private var didComplete = false

    private var accent: Color {
        snapshot.payload.isBigMoment ? AppTheme.Palette.warning : AppTheme.Palette.success
    }

    /// 毒舌点评：用于强化仪式感与传播欲。
    private var roastLine: String {
        if snapshot.usageCount == 1 {
            return "首刷到账，这件东西终于不是家里最贵摆件了。"
        }
        if snapshot.payload.isBigMoment {
            return "你把吃灰库存救回来了，这波比捡钱还狠。"
        }
        if snapshot.usageCount >= 30 {
            return "打卡强度离谱，物品都怕你不给它下班。"
        }
        return "继续连击，别让它回到“买前刚需、买后装饰”的老路。"
    }

    /// 分享文本：用于外部平台传播。
    private var shareText: String {
        """
        我在「买了么」完成一次榨干机打卡：
        物品：\(snapshot.itemName)
        累计打卡：\(snapshot.usageCount) 次
        当前单次成本：\(snapshot.currentCostText)

        毒舌点评：\(roastLine)
        你也来试试，别让买过的东西继续吃灰。
        #买了么 #反冲动消费 #闲置榨干机
        """
    }

    var body: some View {
        ZStack {
            CelebrationBackdrop(accent: accent)

            if confettiReady {
                ConfettiView()
                    .transition(.opacity)
            }

            VStack(spacing: 18) {
                Spacer(minLength: 28)

                CelebrationHero3DView(
                    accent: accent,
                    iconSystemName: "sparkles",
                    imageData: snapshot.imageData,
                    isVisible: showHero,
                    isBreathing: breathing
                )

                VStack(spacing: 12) {
                    Text(snapshot.payload.badge)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(accent)
                        )

                    Text(snapshot.payload.title)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 4)

                    Text(snapshot.payload.subtitle)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.88))
                        .multilineTextAlignment(.center)

                    Text(snapshot.itemName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .scaleEffect(showText ? 1 : 0.82)
                .opacity(showText ? 1 : 0)

                HStack(spacing: 12) {
                    CelebrationMetricPill(title: "累计打卡", value: "\(snapshot.usageCount)")
                    CelebrationMetricPill(title: "当前单次", value: snapshot.currentCostText)
                }
                .opacity(showMetrics ? 1 : 0)
                .offset(y: showMetrics ? 0 : 16)

                CelebrationRoastCard(title: "毒舌点评", line: roastLine)
                    .opacity(showMetrics ? 1 : 0)
                    .offset(y: showMetrics ? 0 : 20)

                if showButton {
                    VStack(spacing: 10) {
                        ShareLink(
                            item: shareText,
                            subject: Text("我的买了么战报"),
                            message: Text("来和我比比，谁更会反向消费。")
                        ) {
                            Label("分享战报去裂变", systemImage: "square.and.arrow.up.fill")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.white.opacity(0.12))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }

                        Button {
                            HapticFeedback.buttonTap()
                            completeOnce()
                        } label: {
                            Text("继续榨干")
                                .font(.title3.weight(.bold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(DuolingoButtonStyle(tint: accent))
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Color.clear
                        .frame(height: 124)
                }

                Spacer(minLength: 34)
            }
            .padding(.horizontal, 20)
        }
        .ignoresSafeArea()
        .onAppear {
            startSequence()
        }
    }

    /// 庆祝编排：按节奏依次落下 3D 卡、文案、指标和行动按钮。
    /// 注意：不再自动关闭，必须由用户主动点击按钮收尾。
    private func startSequence() {
        withAnimation(.spring(response: 0.52, dampingFraction: 0.75)) {
            showHero = true
        }
        HapticFeedback.playSequenceStep(step: .cardEntry)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.66)) {
                confettiReady = true
                breathing = true
            }
            HapticFeedback.playSequenceStep(step: .iconBurst)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.7)) {
                showText = true
            }
            HapticFeedback.playSequenceStep(step: .textDrop)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.72)) {
                showMetrics = true
                showButton = true
            }
            HapticFeedback.playSequenceStep(step: .buttonReady)
        }
    }

    /// 保障只触发一次关闭回调，避免重复点击导致状态错乱。
    private func completeOnce() {
        guard !didComplete else { return }
        didComplete = true
        onComplete()
    }
}

/// 小黑屋决策后的全屏仪式页：统一“忍住没买 / 还是买了”两条路径。
struct DecisionCelebrationFullScreen: View {
    let snapshot: DecisionCelebrationSnapshot
    let onComplete: () -> Void

    @State private var showHero = false
    @State private var showText = false
    @State private var showMetric = false
    @State private var showButton = false
    @State private var confettiReady = false
    @State private var breathing = false
    @State private var didComplete = false

    private var accent: Color {
        switch snapshot.payload.tone {
        case .saved:
            return AppTheme.Palette.success
        case .purchased:
            return AppTheme.Palette.accent
        }
    }

    /// 决策毒舌点评。
    private var roastLine: String {
        switch snapshot.payload.tone {
        case .saved:
            return "你的理性刚刚全票通过，冲动消费被请出群聊。"
        case .purchased:
            return "既然买了就狠狠干活，下次见面只接受“已回本”。"
        }
    }

    /// 决策分享文本。
    private var shareText: String {
        let outcomeLine: String
        switch snapshot.payload.tone {
        case .saved:
            outcomeLine = "我在小黑屋成功忍住没买，直接省下一笔。"
        case .purchased:
            outcomeLine = "我在小黑屋完成决策购买，接下来进入榨干模式。"
        }

        return """
        我在「买了么」完成一次冷静期决策：
        物品：\(snapshot.itemName)
        结果：\(outcomeLine)
        关键数据：\(snapshot.payload.metricTitle) \(snapshot.payload.metricValue)

        毒舌点评：\(roastLine)
        你也来挑战下自己的冲动消费。
        #买了么 #冷静期挑战 #理性消费
        """
    }

    var body: some View {
        ZStack {
            CelebrationBackdrop(accent: accent)

            if confettiReady {
                ConfettiView()
                    .transition(.opacity)
            }

            VStack(spacing: 18) {
                Spacer(minLength: 30)

                CelebrationHero3DView(
                    accent: accent,
                    iconSystemName: snapshot.payload.iconSystemName,
                    imageData: snapshot.imageData,
                    isVisible: showHero,
                    isBreathing: breathing
                )

                VStack(spacing: 12) {
                    Text(snapshot.payload.badge)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(accent)
                        )

                    Text(snapshot.payload.title)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 4)

                    Text(snapshot.payload.subtitle)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.88))
                        .multilineTextAlignment(.center)

                    Text(snapshot.itemName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .scaleEffect(showText ? 1 : 0.82)
                .opacity(showText ? 1 : 0)

                CelebrationMetricPill(
                    title: snapshot.payload.metricTitle,
                    value: snapshot.payload.metricValue
                )
                .opacity(showMetric ? 1 : 0)
                .offset(y: showMetric ? 0 : 16)

                CelebrationRoastCard(title: "毒舌点评", line: roastLine)
                    .opacity(showMetric ? 1 : 0)
                    .offset(y: showMetric ? 0 : 20)

                if showButton {
                    VStack(spacing: 10) {
                        ShareLink(
                            item: shareText,
                            subject: Text("我的买了么决策战报"),
                            message: Text("来挑战你的冲动消费阈值。")
                        ) {
                            Label("分享战报去裂变", systemImage: "square.and.arrow.up.fill")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.white.opacity(0.12))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }

                        Button {
                            HapticFeedback.buttonTap()
                            completeOnce()
                        } label: {
                            Text(snapshot.payload.actionTitle)
                                .font(.title3.weight(.bold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(DuolingoButtonStyle(tint: accent))
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Color.clear
                        .frame(height: 124)
                }

                Spacer(minLength: 36)
            }
            .padding(.horizontal, 20)
        }
        .ignoresSafeArea()
        .onAppear {
            startSequence()
        }
    }

    /// 决策庆祝编排：入口反馈 + 爆发彩带 + 文案/指标落位。
    /// 注意：不再自动关闭，必须由用户主动点击按钮收尾。
    private func startSequence() {
        withAnimation(.spring(response: 0.52, dampingFraction: 0.75)) {
            showHero = true
        }
        HapticFeedback.playSequenceStep(step: .cardEntry)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
                confettiReady = true
                breathing = true
            }
            HapticFeedback.decisionCompleted(isSaved: snapshot.payload.tone == .saved)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            withAnimation(.spring(response: 0.46, dampingFraction: 0.72)) {
                showText = true
            }
            HapticFeedback.playSequenceStep(step: .textDrop)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.72)) {
                showMetric = true
                showButton = true
            }
            HapticFeedback.playSequenceStep(step: .buttonReady)
        }
    }

    /// 保障只触发一次关闭回调，避免重复点击导致状态错乱。
    private func completeOnce() {
        guard !didComplete else { return }
        didComplete = true
        onComplete()
    }
}

/// 庆祝页背景：通过光晕、渐变和透视网格营造“裸眼 3D”舞台感。
private struct CelebrationBackdrop: View {
    let accent: Color

    @State private var drift = false
    @State private var gridPulse = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.06, blue: 0.14),
                    Color(red: 0.08, green: 0.12, blue: 0.24),
                    Color(red: 0.05, green: 0.08, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(accent.opacity(0.32))
                .frame(width: 360, height: 360)
                .blur(radius: 70)
                .offset(x: drift ? -145 : 120, y: drift ? -250 : -150)

            Circle()
                .fill(Color.cyan.opacity(0.23))
                .frame(width: 250, height: 250)
                .blur(radius: 54)
                .offset(x: drift ? 150 : -130, y: drift ? 210 : 120)

            CelebrationPerspectiveGrid()
                .stroke(Color.white.opacity(gridPulse ? 0.24 : 0.15), lineWidth: 0.75)
                .rotation3DEffect(.degrees(70), axis: (x: 1, y: 0, z: 0), perspective: 0.42)
                .scaleEffect(1.18)
                .offset(y: 250)
                .blendMode(.plusLighter)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 4.6).repeatForever(autoreverses: true)) {
                drift = true
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                gridPulse = true
            }
        }
    }
}

/// 透视网格路径：作为“舞台地面”强化空间纵深。
private struct CelebrationPerspectiveGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let columnSpacing: CGFloat = 26
        let rowSpacing: CGFloat = 22

        var x: CGFloat = 0
        while x <= rect.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
            x += columnSpacing
        }

        var y: CGFloat = 0
        while y <= rect.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
            y += rowSpacing
        }

        return path
    }
}

/// 庆祝页 3D 主卡：多层厚度 + 透视旋转，形成裸眼立体感。
private struct CelebrationHero3DView: View {
    let accent: Color
    let iconSystemName: String
    let imageData: Data?
    let isVisible: Bool
    let isBreathing: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.black.opacity(0.34))
                .frame(height: 246)
                .offset(y: 18)
                .blur(radius: 6)

            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(accent.opacity(0.38))
                .frame(height: 240)
                .offset(y: 10)

            VStack(spacing: 14) {
                ItemThumbnailView(
                    imageData: imageData,
                    size: 86,
                    cornerRadius: 20,
                    placeholderSystemName: "shippingbox.fill"
                )
                .shadow(color: Color.black.opacity(0.24), radius: 12, x: 0, y: 8)

                Image(systemName: iconSystemName)
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(accent)

                Text("MISSION CLEAR")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(AppTheme.Palette.secondaryText)
                    .tracking(1.2)
            }
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 230)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.98),
                                Color.white.opacity(0.86)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.white.opacity(0.62), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 262)
        .rotation3DEffect(
            .degrees(isBreathing ? 7.5 : -7.5),
            axis: (x: -1, y: 1, z: 0),
            anchor: .center,
            perspective: 0.72
        )
        .scaleEffect(isVisible ? 1 : 0.56)
        .opacity(isVisible ? 1 : 0)
        .animation(
            .easeInOut(duration: 2.1).repeatForever(autoreverses: true),
            value: isBreathing
        )
    }
}

/// 仪式页指标胶囊：用于关键数值强调。
private struct CelebrationMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
            Text(value)
                .font(.title3.weight(.heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.11))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}

/// 毒舌点评卡：突出一句可传播、可截图的“网感话术”。
private struct CelebrationRoastCard: View {
    let title: String
    let line: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.74))
            Text(line)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.11))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}
