//
//  SavedAmountDetailScreen.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import SwiftUI
import SwiftData
import UIKit

/// 省钱明细页：展示“忍住没买”的历史条目。
struct SavedAmountDetailScreen: View {
    @Query(sort: \Item.createdAt, order: .reverse) private var allItems: [Item]
    @State private var hasAppeared = false

    private var savedItems: [Item] {
        allItems.filter { $0.status == .saved }
    }

    private var totalSavedCents: Int {
        savedItems
            .map { max($0.savedAmountCents, $0.wishPriceCents) }
            .reduce(0, +)
    }

    var body: some View {
        ZStack {
            AuroraBackgroundView()

            ScrollView {
                VStack(spacing: 14) {
                    GlassCardView(accent: AppTheme.Palette.success) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("累计省下")
                                .foregroundStyle(AppTheme.Palette.secondaryText)
                            Text("¥\(centsToYuan(totalSavedCents))")
                                .font(.system(size: 34, weight: .black, design: .rounded))
                                .foregroundStyle(AppTheme.Palette.primaryText)
                            Text("共 \(savedItems.count) 次理性决策")
                                .font(.caption)
                                .foregroundStyle(AppTheme.Palette.tertiaryText)
                            Text("点击任一条目可查看完整复盘与分享海报")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.Palette.tertiaryText)
                        }
                    }
                    .cardReveal(isVisible: hasAppeared, delay: 0.02)

                    if savedItems.isEmpty {
                        GlassCardView(accent: AppTheme.Palette.warning) {
                            Text("暂无“忍住没买”的记录。")
                                .foregroundStyle(AppTheme.Palette.secondaryText)
                        }
                        .cardReveal(isVisible: hasAppeared, delay: 0.06)
                    } else {
                        ForEach(Array(savedItems.enumerated()), id: \.element.id) { index, item in
                            NavigationLink {
                                SavedDecisionDetailScreen(item: item)
                            } label: {
                                GlassCardView(accent: AppTheme.Palette.success) {
                                    HStack(spacing: 12) {
                                        ItemThumbnailView(imageData: item.coverImageData, size: 48, cornerRadius: 10)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.displayName)
                                                .foregroundStyle(AppTheme.Palette.primaryText)
                                            if let decisionAt = item.decisionAt {
                                                Text(decisionAt.zhDateString())
                                                    .font(.caption)
                                                    .foregroundStyle(AppTheme.Palette.tertiaryText)
                                            }
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 5) {
                                            Text("¥\(centsToYuan(max(item.savedAmountCents, item.wishPriceCents)))")
                                                .foregroundStyle(AppTheme.Palette.success)
                                                .fontWeight(.semibold)
                                            Image(systemName: "chevron.right")
                                                .font(.caption.bold())
                                                .foregroundStyle(AppTheme.Palette.tertiaryText)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .cardReveal(isVisible: hasAppeared, delay: 0.08 + Double(index) * 0.04)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle("省钱明细")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            hasAppeared = true
        }
    }

    /// 将“分”转换为“元”。
    private func centsToYuan(_ cents: Int) -> String {
        String(format: "%.2f", Double(cents) / 100.0)
    }
}

/// 省钱条目详情页：复盘单条“忍住没买”记录，并提供分享能力。
struct SavedDecisionDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let item: Item

    @State private var hasAppeared = false
    @State private var toastMessage: String?
    @State private var toastTask: Task<Void, Never>?
    @State private var posterSnapshot: SavedPosterSnapshot?
    @State private var isPresentingDeleteAlert = false
    @State private var errorMessage: String?

    /// 省下金额：优先使用显式记录，兼容历史数据兜底为想买价。
    private var savedCents: Int {
        max(item.savedAmountCents, item.wishPriceCents)
    }

    /// 决策时间：若缺失则回退到创建时间，保证详情可读。
    private var decisionDate: Date {
        item.decisionAt ?? item.createdAt
    }

    /// 实际冷静天数：优先使用配置值，次选由时间差估算。
    private var cooldownDaysText: String {
        if let cooldownDays = item.cooldownDays, cooldownDays > 0 {
            return "\(cooldownDays) 天"
        }
        let day = Calendar.current.dateComponents([.day], from: item.createdAt, to: decisionDate).day ?? 0
        return "\(max(day, 1)) 天"
    }

    /// 毒舌主文案：按省钱金额分层，增强分享时的冲击感。
    private var roastHeadline: String {
        AppConstants.RoastCopy.savedReviewHeadline(
            savedCents: savedCents,
            itemName: item.displayName,
            itemID: item.id,
            primaryCategory: item.primaryCategory,
            secondaryCategory: item.secondaryCategory,
            behaviorTags: item.behaviorTags
        )
    }

    /// 毒舌副文案：结合冷静期长度输出更个性化的复盘语气。
    private var roastBody: String {
        let cooldownDays = item.cooldownDays ?? 0
        return AppConstants.RoastCopy.savedReviewBody(
            cooldownDays: cooldownDays,
            itemName: item.displayName,
            itemID: item.id,
            primaryCategory: item.primaryCategory,
            secondaryCategory: item.secondaryCategory,
            behaviorTags: item.behaviorTags
        )
    }

    /// 复盘文案：复用 resolver 选出的主/副点评，保证复制文本与分享配文保持同一条叙事。
    private var retrospectiveCopy: String {
        """
        【买了么｜省钱复盘】
        物品：\(item.displayName)
        冷静期：\(cooldownDaysText)
        决策时间：\(decisionDate.zhDateString())
        省下金额：¥\(centsToYuan(savedCents))
        
        审判结论：忍住没买。
        毒舌点评：\(roastHeadline)
        复盘补刀：\(roastBody)
        """
    }

    var body: some View {
        ZStack {
            AuroraBackgroundView()

            ScrollView {
                VStack(spacing: 16) {
                    heroCard
                        .cardReveal(isVisible: hasAppeared, delay: 0.02)

                    timelineCard
                        .cardReveal(isVisible: hasAppeared, delay: 0.06)

                    parallelUniverseCard
                        .cardReveal(isVisible: hasAppeared, delay: 0.1)

                    roastCard
                        .cardReveal(isVisible: hasAppeared, delay: 0.14)

                    actionCard
                        .cardReveal(isVisible: hasAppeared, delay: 0.18)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle("省钱复盘")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    isPresentingDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(AppTheme.Palette.warning)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let toastMessage {
                toastView(toastMessage)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .animation(AppTheme.Motion.cardSpring, value: toastMessage)
        .onAppear {
            hasAppeared = true
        }
        .onDisappear {
            toastTask?.cancel()
            toastTask = nil
        }
        .alert("确认删除这条省钱记录？", isPresented: $isPresentingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deleteCurrentItem()
            }
        } message: {
            Text("删除后无法恢复，“\(item.displayName)”会从省钱明细中移除。")
        }
        .alert("操作失败", isPresented: showErrorBinding) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
        .sheet(item: $posterSnapshot) { snapshot in
            SavedPosterPreviewScreen(snapshot: snapshot)
        }
    }

    /// 顶部结果卡：展示决策结果与核心金额。
    private var heroCard: some View {
        GlassCardView(accent: AppTheme.Palette.success) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ItemThumbnailView(imageData: item.coverImageData, size: 72, cornerRadius: 14)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.displayName)
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.Palette.primaryText)
                            .lineLimit(2)

                        Text("省下 ¥\(centsToYuan(savedCents))")
                            .font(.headline.weight(.black))
                            .foregroundStyle(AppTheme.Palette.success)
                    }
                    Spacer()
                    Text("理性胜利")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(AppTheme.Palette.success)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(AppTheme.Palette.success.opacity(0.16))
                        )
                        .overlay(
                            Capsule()
                                .stroke(AppTheme.Palette.success.opacity(0.8), lineWidth: 2)
                        )
                }

                Text(roastHeadline)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.primaryText)

                Text(roastBody)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.secondaryText)
            }
        }
    }

    /// 时间线卡：复盘冲动到理性的完整路径。
    private var timelineCard: some View {
        GlassCardView(accent: AppTheme.Palette.cooling) {
            VStack(alignment: .leading, spacing: 10) {
                Text("决策时间线")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.primaryText)

                timelineRow(title: "录入愿望", value: item.createdAt.zhDateTimeString())
                timelineRow(title: "冷静期长度", value: cooldownDaysText)
                timelineRow(title: "最终决策", value: decisionDate.zhDateTimeString())
                timelineRow(title: "裁决结果", value: "忍住没买")
            }
        }
    }

    /// 平行宇宙卡：强化“没花掉就是赚到”的体感。
    private var parallelUniverseCard: some View {
        GlassCardView(accent: AppTheme.Palette.warning) {
            VStack(alignment: .leading, spacing: 12) {
                Text("平行宇宙对比")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.primaryText)

                HStack(spacing: 10) {
                    metricTile(
                        title: "如果当时买了",
                        value: "-¥\(centsToYuan(item.wishPriceCents))",
                        tint: AppTheme.Palette.warning
                    )
                    metricTile(
                        title: "你实际保住",
                        value: "+¥\(centsToYuan(savedCents))",
                        tint: AppTheme.Palette.success
                    )
                }
            }
        }
    }

    /// 毒舌复盘卡：输出可传播、可截图的网感文案。
    private var roastCard: some View {
        GlassCardView(accent: AppTheme.Palette.cooling) {
            VStack(alignment: .leading, spacing: 8) {
                Text("毒舌复盘")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.primaryText)

                Text("“\(roastHeadline)”")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.Palette.primaryText)

                Text("“\(roastBody)”")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.secondaryText)
            }
        }
    }

    /// 操作区：生成海报、复制文案、删除记录。
    private var actionCard: some View {
        GlassCardView(accent: AppTheme.Palette.success) {
            VStack(alignment: .leading, spacing: 12) {
                Text("操作")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.primaryText)

                HStack(spacing: 10) {
                    Button {
                        HapticFeedback.buttonTap()
                        generatePoster()
                    } label: {
                        Label("生成省钱海报", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SolidActionButtonStyle(tint: AppTheme.Palette.cooling))
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)

                    Button {
                        copyToPasteboard(retrospectiveCopy, success: "复盘文案已复制")
                    } label: {
                        Label("复制复盘文案", systemImage: "doc.on.doc.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SolidActionButtonStyle(tint: AppTheme.Palette.success))
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                }

                Button(role: .destructive) {
                    HapticFeedback.buttonTap()
                    isPresentingDeleteAlert = true
                } label: {
                    Label("删除记录", systemImage: "trash.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SolidActionButtonStyle(tint: AppTheme.Palette.warning))
            }
        }
    }

    /// 时间线行样式。
    private func timelineRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(AppTheme.Palette.secondaryText)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(AppTheme.Palette.primaryText)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    /// 指标小卡片。
    private func metricTile(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.secondaryText)
            Text(value)
                .font(.title3.weight(.black))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Palette.softSurface)
        )
    }

    /// 统一底部轻提示。
    private func toastView(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.Palette.success)
            Text(text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.primaryText)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Palette.inputFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.Palette.cardStroke.opacity(0.7), lineWidth: 1)
        )
    }

    /// 生成海报并进入预览页。
    @MainActor
    private func generatePoster() {
        guard let image = renderPosterImage() else {
            errorMessage = "海报生成失败，请稍后重试。"
            return
        }
        posterSnapshot = SavedPosterSnapshot(
            image: image,
            shareText: retrospectiveCopy,
            title: "省钱复盘海报"
        )
        showToast("海报已生成，可预览后分享")
    }

    /// 渲染用于分享的静态海报图。
    @MainActor
    private func renderPosterImage() -> UIImage? {
        let poster = SavedPosterTemplateView(
            itemName: item.displayName,
            savedAmount: "¥\(centsToYuan(savedCents))",
            decisionDate: decisionDate.zhDateString(),
            cooldownText: cooldownDaysText,
            roastLine: roastHeadline,
            imageData: item.coverImageData
        )
        .frame(width: 1080, height: 1920)

        let renderer = ImageRenderer(content: poster)
        renderer.scale = 1
        return renderer.uiImage
    }

    /// 复制文本到剪贴板。
    private func copyToPasteboard(_ text: String, success: String) {
        UIPasteboard.general.string = text
        HapticFeedback.buttonTap()
        showToast(success)
    }

    /// 删除当前条目并返回上一页。
    private func deleteCurrentItem() {
        NotificationManager.shared.cancelAllReminders(for: item.id)
        modelContext.delete(item)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "删除失败：\(error.localizedDescription)"
        }
    }

    /// 展示短时提示。
    private func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.22)) {
                    toastMessage = nil
                }
            }
        }
    }

    /// 错误弹窗展示控制。
    private var showErrorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    /// 将“分”转换为“元”。
    private func centsToYuan(_ cents: Int) -> String {
        String(format: "%.2f", Double(cents) / 100.0)
    }
}

/// 海报快照：用于预览与系统分享。
private struct SavedPosterSnapshot: Identifiable {
    let id = UUID()
    let image: UIImage
    let shareText: String
    let title: String
}

/// 省钱海报预览页：先预览，再触发系统分享。
private struct SavedPosterPreviewScreen: View {
    @Environment(\.dismiss) private var dismiss

    let snapshot: SavedPosterSnapshot

    @State private var isPresentingShareSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackgroundView()

                ScrollView {
                    VStack(spacing: 14) {
                        Text(snapshot.title)
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.Palette.primaryText)
                            .padding(.top, 6)

                        Image(uiImage: snapshot.image)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(maxWidth: 380)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(AppTheme.Palette.cardStroke, lineWidth: 2)
                            )
                            .shadow(color: AppTheme.Palette.cardShadow.opacity(0.45), radius: 14, x: 0, y: 8)

                        Text("长按海报可保存图片，再点分享发到你的社交平台。")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)

                        Button {
                            HapticFeedback.buttonTap()
                            isPresentingShareSheet = true
                        } label: {
                            Label("分享海报", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SolidActionButtonStyle(tint: AppTheme.Palette.accent))
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Label("返回", systemImage: "chevron.left")
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingShareSheet) {
            ActivityShareSheet(items: [snapshot.image, snapshot.shareText])
        }
    }
}

/// 省钱海报模板：用于离屏渲染静态图片。
private struct SavedPosterTemplateView: View {
    let itemName: String
    let savedAmount: String
    let decisionDate: String
    let cooldownText: String
    let roastLine: String
    let imageData: Data?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.18, blue: 0.45),
                    Color(red: 0.10, green: 0.35, blue: 0.78),
                    Color(red: 0.75, green: 0.90, blue: 1.00)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                Circle()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 660, height: 660)
                    .offset(x: 320, y: -700)
            )

            RoundedRectangle(cornerRadius: 52, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 52, style: .continuous)
                        .stroke(Color.white.opacity(0.85), lineWidth: 4)
                )
                .padding(.horizontal, 72)
                .padding(.vertical, 116)

            VStack(spacing: 34) {
                Text("冷静决策海报")
                    .font(.system(size: 78, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.05, green: 0.13, blue: 0.32))

                VStack(spacing: 14) {
                    if let imageData,
                       let image = UIImage(data: imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 250, height: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 34, style: .continuous)
                                    .stroke(Color.white, lineWidth: 6)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .fill(Color(red: 0.90, green: 0.94, blue: 1.00))
                            .frame(width: 250, height: 250)
                            .overlay(
                                Image(systemName: "shippingbox.fill")
                                    .font(.system(size: 96))
                                    .foregroundStyle(Color(red: 0.65, green: 0.70, blue: 0.78))
                            )
                    }

                    Text(itemName)
                        .font(.system(size: 58, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.08, green: 0.10, blue: 0.15))
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 80)
                }

                VStack(spacing: 16) {
                    posterMetricRow(title: "审判结果", value: "忍住没买")
                    posterMetricRow(title: "省下金额", value: savedAmount)
                    posterMetricRow(title: "冷静期", value: cooldownText)
                    posterMetricRow(title: "决策日期", value: decisionDate)
                }

                Text("“\(roastLine)”")
                    .font(.system(size: 43, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.09, green: 0.12, blue: 0.20))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 88)

                Spacer(minLength: 0)

                Text("⚡ 买了么 APP")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.38, green: 0.45, blue: 0.58))
                    .padding(.bottom, 26)
            }
            .padding(.top, 180)
            .padding(.bottom, 170)
        }
    }

    /// 海报指标行。
    private func posterMetricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.60, green: 0.66, blue: 0.75))
            Spacer()
            Text(value)
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.37, blue: 0.95))
        }
        .padding(.horizontal, 88)
    }
}

/// 系统分享面板封装。
private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
