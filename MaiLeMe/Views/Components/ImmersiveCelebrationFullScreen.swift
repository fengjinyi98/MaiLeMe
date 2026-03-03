//
//  ImmersiveCelebrationFullScreen.swift
//  MaiLeMe
//
//  Created by Codex on 2026/3/3.
//

import SwiftUI
import UIKit

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
    @State private var posterSnapshot: CelebrationPosterSnapshot?

    private var accent: Color {
        snapshot.payload.isBigMoment ? AppTheme.Palette.warning : AppTheme.Palette.success
    }

    /// 分享文本：用于外部平台传播。
    private var shareText: String {
        AppConstants.RoastCopy.checkinShareText(
            itemName: snapshot.itemName,
            usageCount: snapshot.usageCount,
            currentCostText: snapshot.currentCostText,
            roastLine: snapshot.payload.roastLine
        )
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
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)
                        .fixedSize(horizontal: false, vertical: true)
                        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 4)

                    Text(snapshot.payload.subtitle)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.88))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

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

                CelebrationRoastCard(title: "毒舌点评", line: snapshot.payload.roastLine)
                    .opacity(showMetrics ? 1 : 0)
                    .offset(y: showMetrics ? 0 : 20)

                if showButton {
                    VStack(spacing: 10) {
                        Button {
                            generatePoster()
                        } label: {
                            Label("生成专属海报", systemImage: "sparkles")
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
        .overlay {
            if let snapshot = posterSnapshot {
                CelebrationPosterPreviewScreen(snapshot: snapshot) {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                        posterSnapshot = nil
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }
        }
    }

    @MainActor
    private func generatePoster() {
        guard let image = renderPosterImage(
            accent: accent,
            badge: snapshot.payload.badge,
            title: snapshot.payload.title,
            itemName: snapshot.itemName,
            imageData: snapshot.imageData,
            roastLine: snapshot.payload.roastLine,
            metric1Title: "累计打卡",
            metric1Value: "\(snapshot.usageCount)",
            metric2Title: "单次成本",
            metric2Value: snapshot.currentCostText
        ) else {
            return
        }

        withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
            self.posterSnapshot = CelebrationPosterSnapshot(
                image: image,
                shareText: shareText,
                accent: accent,
                title: "榨干战报海报"
            )
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

/// 决策庆祝页“继续”按钮的路由意图。
enum DecisionCelebrationContinueAction {
    case close
    case goToExtractorCheckin
}

/// 小黑屋决策后的全屏仪式页：统一“忍住没买 / 还是买了”两条路径。
struct DecisionCelebrationFullScreen: View {
    let snapshot: DecisionCelebrationSnapshot
    let onComplete: (DecisionCelebrationContinueAction) -> Void

    @State private var showHero = false
    @State private var showText = false
    @State private var showMetric = false
    @State private var showButton = false
    @State private var confettiReady = false
    @State private var breathing = false
    @State private var didComplete = false
    @State private var posterSnapshot: CelebrationPosterSnapshot?

    private var accent: Color {
        switch snapshot.payload.tone {
        case .saved:
            return AppTheme.Palette.success
        case .purchased:
            return AppTheme.Palette.accent
        }
    }

    /// 决策分享文本。
    private var shareText: String {
        AppConstants.RoastCopy.decisionShareText(
            itemName: snapshot.itemName,
            isSaved: snapshot.payload.tone == .saved,
            metricTitle: snapshot.payload.metricTitle,
            metricValue: snapshot.payload.metricValue,
            roastLine: snapshot.payload.roastLine
        )
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
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)
                        .fixedSize(horizontal: false, vertical: true)
                        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 4)

                    Text(snapshot.payload.subtitle)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.88))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

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

                CelebrationRoastCard(title: "毒舌点评", line: snapshot.payload.roastLine)
                    .opacity(showMetric ? 1 : 0)
                    .offset(y: showMetric ? 0 : 20)

                if showButton {
                    VStack(spacing: 10) {
                        Button {
                            generatePoster()
                        } label: {
                            Label("生成专属海报", systemImage: "sparkles")
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
                            let action: DecisionCelebrationContinueAction = snapshot.payload.tone == .saved ? .close : .goToExtractorCheckin
                            completeOnce(action: action)
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
        .overlay {
            if let snapshot = posterSnapshot {
                CelebrationPosterPreviewScreen(snapshot: snapshot) {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                        posterSnapshot = nil
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }
        }
    }

    @MainActor
    private func generatePoster() {
        guard let image = renderPosterImage(
            accent: accent,
            badge: snapshot.payload.badge,
            title: snapshot.payload.title,
            itemName: snapshot.itemName,
            imageData: snapshot.imageData,
            roastLine: snapshot.payload.roastLine,
            metric1Title: snapshot.payload.metricTitle,
            metric1Value: snapshot.payload.metricValue,
            metric2Title: nil,
            metric2Value: nil
        ) else {
            return
        }

        withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
            self.posterSnapshot = CelebrationPosterSnapshot(
                image: image,
                shareText: shareText,
                accent: accent,
                title: "冷静决策海报"
            )
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
    private func completeOnce(action: DecisionCelebrationContinueAction) {
        guard !didComplete else { return }
        didComplete = true
        onComplete(action)
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

            VStack {
                ItemThumbnailView(
                    imageData: imageData,
                    size: 96,
                    cornerRadius: 24,
                    placeholderSystemName: "shippingbox.fill"
                )
                .shadow(color: Color.black.opacity(0.24), radius: 12, x: 0, y: 8)
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

/// 海报预览快照：承载静态图片与分享文本，供预览页展示和系统分享。
private struct CelebrationPosterSnapshot: Identifiable {
    let id = UUID()
    let image: UIImage
    let shareText: String
    let accent: Color
    let title: String
}

/// 海报预览全屏页：先让用户确认海报，再显式触发系统分享。
private struct CelebrationPosterPreviewScreen: View {
    let snapshot: CelebrationPosterSnapshot
    let onClose: () -> Void

    @State private var showShareSheet = false
    @State private var isCardVisible = false
    @State private var horizontalDragOffset: CGFloat = 0
    
    /// 顶部安全区：使用系统窗口数据，避免被上层 ignoresSafeArea 影响。
    private var topSafeAreaInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.top ?? 0
    }

    var body: some View {
        ZStack {
            CelebrationBackdrop(accent: snapshot.accent)

            VStack(spacing: 16) {
                HStack {
                    Button {
                        HapticFeedback.buttonTap()
                        onClose()
                    } label: {
                        Label("返回", systemImage: "chevron.left")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }

                Text(snapshot.title)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)

                Image(uiImage: snapshot.image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.white.opacity(0.72), lineWidth: 1.2)
                    )
                    .shadow(color: Color.black.opacity(0.28), radius: 24, x: 0, y: 12)
                    .scaleEffect(isCardVisible ? 1 : 0.92)
                    .opacity(isCardVisible ? 1 : 0)

                Text("长按海报可保存图片，再点分享发到你的社交平台。")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.84))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)

                Button {
                    HapticFeedback.buttonTap()
                    showShareSheet = true
                } label: {
                    Label("分享海报", systemImage: "square.and.arrow.up")
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DuolingoButtonStyle(tint: snapshot.accent))
                
                Button {
                    HapticFeedback.buttonTap()
                    onClose()
                } label: {
                    Text("关闭预览")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 10)
            }
            .padding(.horizontal, 20)
            .padding(.top, max(topSafeAreaInset + 8, 24))
            .padding(.bottom, 28)
            .offset(x: horizontalDragOffset)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .onChanged { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    horizontalDragOffset = max(0, value.translation.width)
                }
                .onEnded { value in
                    let shouldClose =
                        value.translation.width > 110 ||
                        value.predictedEndTranslation.width > 180
                    if shouldClose {
                        HapticFeedback.buttonTap()
                        onClose()
                    } else {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            horizontalDragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                isCardVisible = true
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [snapshot.image, snapshot.shareText])
        }
    }
}

/// 原生分享表单
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// 统一海报渲染入口：返回可用于预览和分享的静态图片。
@MainActor
private func renderPosterImage(
    accent: Color,
    badge: String,
    title: String,
    itemName: String,
    imageData: Data?,
    roastLine: String,
    metric1Title: String,
    metric1Value: String,
    metric2Title: String?,
    metric2Value: String?
) -> UIImage? {
    let posterView = PosterTemplateView(
        accent: accent,
        badge: badge,
        title: title,
        itemName: itemName,
        imageData: imageData,
        roastLine: roastLine,
        metric1Title: metric1Title,
        metric1Value: metric1Value,
        metric2Title: metric2Title,
        metric2Value: metric2Value
    )

    let renderer = ImageRenderer(content: posterView)
    renderer.scale = 3.0
    return renderer.uiImage
}

/// 战报海报生成模板：更具设计感，包含物品图片和多邻国风粗犷卡片。
private struct PosterTemplateView: View {
    let accent: Color
    let badge: String
    let title: String
    let itemName: String
    let imageData: Data?
    let roastLine: String
    
    let metric1Title: String
    let metric1Value: String
    
    let metric2Title: String?
    let metric2Value: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // 背景板：渐变色
            ZStack {
                LinearGradient(
                    colors: [
                        accent.opacity(0.8),
                        accent.opacity(0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // 内部的白色实体粗边卡片
                VStack(spacing: 24) {
                    
                    // 1. 头衔标志
                    Text(badge)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(accent.opacity(0.15))
                        )
                        .padding(.top, 16)

                    // 2. 核心大标题与物品主图
                    VStack(spacing: 16) {
                        Text(title)
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.Palette.primaryText)
                            .multilineTextAlignment(.center)
                        
                        ItemThumbnailView(
                            imageData: imageData,
                            size: 140,
                            cornerRadius: 32,
                            placeholderSystemName: "shippingbox.fill"
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
                        
                        Text(itemName)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.Palette.secondaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    // 3. 极度突出的数据指标
                    HStack(spacing: 16) {
                        posterMetric(title: metric1Title, value: metric1Value)
                        if let t2 = metric2Title, let v2 = metric2Value {
                            posterMetric(title: t2, value: v2)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // 4. 毒舌点评区块
                    VStack(alignment: .leading, spacing: 6) {
                        Text("审判官点评")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.Palette.tertiaryText)
                        Text("“\(roastLine)”")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.primaryText)
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.Palette.canvas)
                    )
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 16)
                    
                    // 5. 底部品牌 Logo
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.heart.fill")
                            .font(.title3)
                            .foregroundStyle(accent)
                        Text("买 了 么 APP")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppTheme.Palette.secondaryText)
                    }
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(AppTheme.Palette.cardStroke, lineWidth: 2)
                )
                .padding(24) // 卡片距离边缘的留白
            }
        }
        .frame(width: 440, height: 720) // 给定一个固定的黄金比例尺寸
        .background(Color.white) // 保证整体是最底层有填充的
    }
    
    private func posterMetric(title: String, value: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.tertiaryText)
            Text(value)
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.Palette.canvas)
                .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 3)
        )
    }
}
