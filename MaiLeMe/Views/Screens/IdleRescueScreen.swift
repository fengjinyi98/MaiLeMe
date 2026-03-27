//
//  IdleRescueScreen.swift
//  MaiLeMe
//
//  Created by Codex on 2026/3/3.
//

import SwiftUI
import UIKit

/// 吃灰挽救页面：提供诊断、毒舌提示与一键处置动作（打卡/转卖文案/追提醒）。
struct IdleRescueScreen: View {
    @EnvironmentObject private var navigationState: AppNavigationState

    let item: Item
    let viewModel: ExtractorViewModel

    @State private var hasAppeared = false
    @State private var resaleCopy: ResaleCopyPackage?
    @State private var toastMessage: String?
    @State private var toastTask: Task<Void, Never>?

    private var idleDays: Int {
        viewModel.idleDays(for: item) ?? 0
    }

    private var purchasePriceCents: Int {
        item.purchasePriceCents ?? item.wishPriceCents
    }

    private var suggestedRange: ClosedRange<Int> {
        resalePriceRange(for: item)
    }

    private var roastLine: String {
        AppConstants.RoastCopy.idleRescuePrimary(
            idleDays: idleDays,
            itemName: item.displayName,
            itemID: item.id,
            primaryCategory: item.primaryCategory,
            secondaryCategory: item.secondaryCategory,
            behaviorTags: item.behaviorTags
        )
    }

    private var secondaryRoastLine: String {
        AppConstants.RoastCopy.idleRescueSecondary(
            idleDays: idleDays,
            usageCount: item.usageCount,
            itemName: item.displayName,
            itemID: item.id,
            primaryCategory: item.primaryCategory,
            secondaryCategory: item.secondaryCategory,
            behaviorTags: item.behaviorTags
        )
    }

    var body: some View {
        ZStack {
            AuroraBackgroundView()

            ScrollView {
                VStack(spacing: 16) {
                    heroCard
                        .cardReveal(isVisible: hasAppeared, delay: 0.02)

                    diagnosisCard
                        .cardReveal(isVisible: hasAppeared, delay: 0.06)

                    actionCard
                        .cardReveal(isVisible: hasAppeared, delay: 0.1)

                    if let resaleCopy {
                        resaleCopyCard(resaleCopy)
                            .cardReveal(isVisible: hasAppeared, delay: 0.14)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle("吃灰挽救")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            hasAppeared = true
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
    }

    /// 头图卡：展示物品与吃灰状态。
    private var heroCard: some View {
        GlassCardView(accent: AppTheme.Palette.warning) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ItemThumbnailView(imageData: item.coverImageData, size: 72, cornerRadius: 14)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.displayName)
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.Palette.primaryText)
                            .lineLimit(2)

                        Text("已吃灰 \(idleDays) 天")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.warning)
                    }

                    Spacer()

                    Text(idleLevelTag)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Palette.warning)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(AppTheme.Palette.warning.opacity(0.16))
                        )
                }

                Text(roastLine)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.primaryText)

                Text(secondaryRoastLine)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.secondaryText)
            }
        }
    }

    /// 诊断卡：集中给出处置决策所需数据。
    private var diagnosisCard: some View {
        GlassCardView(accent: AppTheme.Palette.cooling) {
            VStack(alignment: .leading, spacing: 12) {
                Text("吃灰诊断")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.primaryText)

                diagnosticRow(title: "买入价格", value: "¥\(centsToYuan(purchasePriceCents))")
                diagnosticRow(title: "累计打卡", value: "\(item.usageCount) 次")
                diagnosticRow(title: "当前单次成本", value: currentCostText)
                diagnosticRow(title: "最近使用", value: formattedLastUseText)
                diagnosticRow(
                    title: "建议转卖价",
                    value: "¥\(centsToYuan(suggestedRange.lowerBound)) - ¥\(centsToYuan(suggestedRange.upperBound))"
                )
            }
        }
    }

    /// 行动卡：提供“自救打卡/生成转卖文案/7天追提醒”。
    private var actionCard: some View {
        GlassCardView(accent: AppTheme.Palette.success) {
            VStack(alignment: .leading, spacing: 12) {
                Text("立即行动")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.primaryText)

                HStack(spacing: 10) {
                    Button {
                        HapticFeedback.buttonTap()
                        navigationState.routeToExtractorCheckin(itemID: item.id)
                    } label: {
                        Label("去榨干机打卡", systemImage: "bolt.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SolidActionButtonStyle(tint: AppTheme.Palette.success))

                    Button {
                        HapticFeedback.buttonTap()
                        resaleCopy = buildResaleCopyPackage(for: item)
                        showToast("闲鱼文案已生成，可一键复制")
                    } label: {
                        Label("生成闲鱼文案", systemImage: "doc.text.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SolidActionButtonStyle(tint: AppTheme.Palette.cooling))
                }

                Button {
                    HapticFeedback.buttonTap()
                    Task {
                        await NotificationManager.shared.scheduleRescueReminder(
                            for: item,
                            days: AppConstants.Notification.rescueFollowupDays
                        )
                        await MainActor.run {
                            showToast("已设置 7 天后提醒你处置")
                        }
                    }
                } label: {
                    Label("7天后再提醒我", systemImage: "bell.badge")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SolidActionButtonStyle(tint: AppTheme.Palette.warning))
            }
        }
    }

    /// 转卖文案卡：标题、正文、议价回复与复制能力。
    private func resaleCopyCard(_ copy: ResaleCopyPackage) -> some View {
        GlassCardView(accent: AppTheme.Palette.warning) {
            VStack(alignment: .leading, spacing: 12) {
                Text("闲鱼转卖文案")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.primaryText)

                copyBlock(title: "标题", text: copy.title)
                copyBlock(title: "正文", text: copy.body)
                copyBlock(title: "议价回复", text: copy.negotiationReply)

                HStack(spacing: 10) {
                    Button {
                        copyToPasteboard(copy.title, success: "标题已复制")
                    } label: {
                        Label("复制标题", systemImage: "text.cursor")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SolidActionButtonStyle(tint: AppTheme.Palette.cooling))
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)

                    Button {
                        copyToPasteboard(copy.fullText, success: "完整文案已复制")
                    } label: {
                        Label("复制全部", systemImage: "doc.on.doc.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SolidActionButtonStyle(tint: AppTheme.Palette.success))
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                }
            }
        }
    }

    /// 文本分区块样式。
    private func copyBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Palette.tertiaryText)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Palette.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Palette.softSurface)
        )
    }

    /// 诊断行样式。
    private func diagnosticRow(title: String, value: String) -> some View {
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

    /// 底部轻提示样式。
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

    /// 当前吃灰等级标签。
    private var idleLevelTag: String {
        switch idleDays {
        case ..<7: return "轻度"
        case 7..<14: return "升温"
        case 14..<30: return "中度"
        case 30..<60: return "重度"
        default: return "爆表"
        }
    }

    /// 当前单次成本显示文本。
    private var currentCostText: String {
        if let cost = viewModel.currentCostPerUseCents(for: item) {
            return "¥\(centsToYuan(cost))"
        }
        return "尚未使用"
    }

    /// 最近使用时间显示文本。
    private var formattedLastUseText: String {
        let date = item.lastUsedAt ?? item.purchaseAt
        guard let date else { return "无记录" }
        return date.zhDateString()
    }

    /// 估算建议转卖区间（单位：分）。
    /// 使用简单折价规则，先给用户一个可执行的挂牌参考。
    private func resalePriceRange(for item: Item) -> ClosedRange<Int> {
        let price = max(1, purchasePriceCents)
        let usage = max(0, item.usageCount)

        let lowerRate: Double
        let upperRate: Double
        if usage == 0 {
            lowerRate = 0.75
            upperRate = 0.85
        } else if usage <= 5 {
            lowerRate = 0.60
            upperRate = 0.75
        } else {
            lowerRate = 0.45
            upperRate = 0.65
        }

        let lower = max(1, Int(Double(price) * lowerRate))
        let upper = max(lower, Int(Double(price) * upperRate))
        return lower...upper
    }

    /// 生成闲鱼文案包。
    private func buildResaleCopyPackage(for item: Item) -> ResaleCopyPackage {
        let condition = AppConstants.RoastCopy.resaleCondition(usageCount: item.usageCount)

        let suggested = resalePriceRange(for: item)
        let purchaseDate = item.purchaseAt?.zhDateString() ?? item.createdAt.zhDateString()
        let reason = AppConstants.RoastCopy.resaleReason(idleDays: idleDays, itemID: item.id)

        let title = "【\(item.displayName)】\(condition) 闲置转出，可小刀"
        let body = """
        物品名称：\(item.displayName)
        入手时间：\(purchaseDate)
        买入价：¥\(centsToYuan(purchasePriceCents))
        当前状态：\(condition)，累计使用 \(item.usageCount) 次，已闲置 \(idleDays) 天
        参考出价：¥\(centsToYuan(suggested.lowerBound)) - ¥\(centsToYuan(suggested.upperBound))
        转手原因：\(reason)
        交易方式：同城优先，外地可走平台流程。
        """

        let negotiationReply = AppConstants.RoastCopy.resaleNegotiationReply(itemID: item.id)
        return ResaleCopyPackage(title: title, body: body, negotiationReply: negotiationReply)
    }

    /// 复制文本到系统剪贴板。
    private func copyToPasteboard(_ text: String, success: String) {
        UIPasteboard.general.string = text
        showToast(success)
        HapticFeedback.buttonTap()
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

    /// 金额格式化：分 -> 元。
    private func centsToYuan(_ cents: Int) -> String {
        String(format: "%.2f", Double(cents) / 100.0)
    }
}

/// 闲鱼转卖文案组合。
private struct ResaleCopyPackage {
    let title: String
    let body: String
    let negotiationReply: String

    /// 便于“一键复制全部文案”。
    var fullText: String {
        """
        【标题】
        \(title)

        【正文】
        \(body)

        【议价回复】
        \(negotiationReply)
        """
    }
}
