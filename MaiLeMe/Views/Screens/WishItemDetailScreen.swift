//
//  WishItemDetailScreen.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import SwiftUI

/// 小黑屋条目详情页：支持查看状态、执行决策与删除。
struct WishItemDetailScreen: View {
    @Environment(\.dismiss) private var dismiss

    let item: Item
    let viewModel: DarkRoomViewModel
    let onDelete: (Item) -> Void

    @State private var isPresentingPurchaseSheet = false
    @State private var isPresentingDeleteConfirm = false
    @State private var errorMessage: String?
    @State private var decisionCelebration: DecisionCelebrationSnapshot?
    @State private var hasAppeared = false
    @State private var purchasePath: PurchasePath = .normalDecision

    /// 购买路径：用于区分“到期决策购买”与“冷静期内提前购买”。
    private enum PurchasePath {
        case normalDecision
        case impulseDuringCooldown
    }

    private var canMakeDecision: Bool {
        viewModel.canMakeDecision(for: item)
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

                    if canMakeDecision {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("最终决策")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.tertiaryText)
                            decisionCard
                        }
                            .cardReveal(isVisible: hasAppeared, delay: 0.1)
                    } else {
                        cooldownCard
                            .cardReveal(isVisible: hasAppeared, delay: 0.1)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }

        }
        .navigationTitle("小黑屋详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    isPresentingDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(AppTheme.Palette.warning)
                }
            }
        }
        .sheet(isPresented: $isPresentingPurchaseSheet) {
            PurchaseDecisionSheet(
                itemName: item.displayName,
                defaultPriceCents: item.wishPriceCents
            ) { purchasePriceCents, targetCostPerUseCents, expectedUseCount in
                markAsPurchased(
                    purchasePriceCents: purchasePriceCents,
                    targetCostPerUseCents: targetCostPerUseCents,
                    expectedUseCount: expectedUseCount
                )
            }
        }
        .alert("确认删除该条目？", isPresented: $isPresentingDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                onDelete(item)
                dismiss()
            }
        } message: {
            Text("“\(item.displayName)”及其关联记录会被删除。")
        }
        .alert("操作失败", isPresented: showErrorBinding) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
        .onAppear {
            hasAppeared = true
        }
        .fullScreenCover(item: $decisionCelebration) { snapshot in
            DecisionCelebrationFullScreen(snapshot: snapshot) {
                completeDecisionFlow()
            }
            .interactiveDismissDisabled(true)
        }
    }

    /// 顶部主卡片：展示核心信息。
    private var heroCard: some View {
        GlassCardView(accent: canMakeDecision ? AppTheme.Palette.warning : AppTheme.Palette.cooling) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    InteractiveItemImageView(
                        imageData: item.coverImageData,
                        previewTitle: item.displayName,
                        size: 72,
                        cornerRadius: 14,
                        onImageUpdated: { imageData in
                            item.coverImageData = imageData
                        },
                        onError: { message in
                            errorMessage = message
                        }
                    )

                    Text(item.displayName)
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.Palette.primaryText)
                        .lineLimit(2)

                    Spacer()

                    statusTag(
                        text: canMakeDecision ? "可决策" : "待冷静",
                        tint: canMakeDecision ? AppTheme.Palette.warning : AppTheme.Palette.cooling
                    )
                }

                HStack {
                    metric(label: "想买价格", value: "¥\(centsToYuan(item.wishPriceCents))")
                    Spacer(minLength: 12)
                    metric(label: "冷静期", value: "\(item.cooldownDays ?? 0) 天")
                }

                Text("点击图片可看大图，长按可更换图片。")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.Palette.tertiaryText)
            }
        }
    }

    /// 时间线信息卡片。
    private var timelineCard: some View {
        GlassCardView(accent: AppTheme.Palette.cooling) {
            VStack(alignment: .leading, spacing: 10) {
                Text("时间线")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.primaryText)

                timelineRow(title: "录入时间", value: item.createdAt.zhDateTimeString())
                if let cooldownEndAt = item.cooldownEndAt {
                    timelineRow(title: "冷静结束", value: cooldownEndAt.zhDateTimeString())
                }
                if let decisionAt = item.decisionAt {
                    timelineRow(title: "决策时间", value: decisionAt.zhDateTimeString())
                }
            }
        }
    }

    /// 冷静期未结束时显示的提示卡。
    private var cooldownCard: some View {
        GlassCardView(accent: AppTheme.Palette.cooling) {
            let remainingDays = viewModel.remainingCooldownDays(for: item)
            let totalDays = max(1, item.cooldownDays ?? 1)
            let progress = min(max(1.0 - (Double(remainingDays) / Double(totalDays)), 0), 1)

            return VStack(alignment: .leading, spacing: 12) {
                Text("还在冷静中")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.primaryText)

                Text("剩余 \(remainingDays) 天，等冲动降温再做决定。")
                    .foregroundStyle(AppTheme.Palette.secondaryText)

                ProgressBarView(progress: progress, tintColor: AppTheme.Palette.cooling, height: 14)
                    .frame(height: 14)

                Button {
                    purchasePath = .impulseDuringCooldown
                    isPresentingPurchaseSheet = true
                } label: {
                    Label("冷静期内提前买了", systemImage: "bolt.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SolidActionButtonStyle(tint: AppTheme.Palette.warning))
            }
        }
    }

    /// 可决策卡片：展示两种终局路径。
    private var decisionCard: some View {
        GlassCardView(accent: AppTheme.Palette.warning) {
            VStack(alignment: .leading, spacing: 12) {
                Text("冷静期已结束")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.primaryText)

                Text("现在做决定：你是忍住，还是确认购买。")
                    .foregroundStyle(AppTheme.Palette.secondaryText)

                HStack(spacing: 12) {
                    Button("忍住没买") {
                        markAsSaved()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(SolidActionButtonStyle(tint: AppTheme.Palette.success))

                    Button("还是买了") {
                        purchasePath = .normalDecision
                        isPresentingPurchaseSheet = true
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(SolidActionButtonStyle(tint: AppTheme.Palette.accent))
                }
            }
        }
    }

    /// 执行“忍住没买”。
    private func markAsSaved() {
        do {
            try viewModel.markAsSaved(item: item)
            NotificationManager.shared.cancelAllReminders(for: item.id)
            let celebration = viewModel.makeDecisionCelebration(
                for: item,
                outcome: .saved
            )
            presentDecisionCelebration(celebration)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 执行“还是买了”并写入购买参数。
    private func markAsPurchased(
        purchasePriceCents: Int,
        targetCostPerUseCents: Int?,
        expectedUseCount: Int?
    ) {
        do {
            switch purchasePath {
            case .normalDecision:
                try viewModel.markAsPurchased(
                    item: item,
                    purchasePriceCents: purchasePriceCents,
                    targetCostPerUseCents: targetCostPerUseCents,
                    expectedUseCount: expectedUseCount
                )
            case .impulseDuringCooldown:
                try viewModel.markAsPurchasedDuringCooldown(
                    item: item,
                    purchasePriceCents: purchasePriceCents,
                    targetCostPerUseCents: targetCostPerUseCents,
                    expectedUseCount: expectedUseCount
                )
            }
            Task {
                await NotificationManager.shared.scheduleIdleReminders(for: item)
            }
            if purchasePath == .normalDecision {
                let celebration = viewModel.makeDecisionCelebration(
                    for: item,
                    outcome: .purchased
                )
                presentDecisionCelebration(celebration)
            } else {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 小型指标组件。
    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.tertiaryText)
            Text(value)
                .font(.headline)
                .foregroundStyle(AppTheme.Palette.primaryText)
        }
    }

    /// 时间线行样式。
    private func timelineRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(AppTheme.Palette.secondaryText)
            Spacer()
            Text(value)
                .foregroundStyle(AppTheme.Palette.primaryText)
        }
        .font(.subheadline)
    }

    /// 状态标签样式。
    private func statusTag(text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(tint.opacity(0.16))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.52), lineWidth: 1)
            )
            .foregroundStyle(tint)
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

    /// 展示决策仪式页（全屏版）。
    private func presentDecisionCelebration(_ payload: DarkRoomDecisionCelebrationPayload) {
        decisionCelebration = DecisionCelebrationSnapshot(
            payload: payload,
            itemName: item.displayName,
            imageData: item.coverImageData
        )
    }

    /// 结束决策流程：关闭庆祝页并返回上一页。
    private func completeDecisionFlow() {
        decisionCelebration = nil
        dismiss()
    }
}
