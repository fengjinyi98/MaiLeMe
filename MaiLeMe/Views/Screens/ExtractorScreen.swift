//
//  ExtractorScreen.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import SwiftUI
import SwiftData

/// 闲置榨干机主页面：卡片化看板 + 详情跳转 + 删除确认与撤销。
struct ExtractorScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.createdAt, order: .reverse) private var allItems: [Item]

    @State private var errorMessage: String?
    @State private var itemPendingDeletion: Item?
    @State private var hasAppeared = false

    /// 最近删除快照，用于撤销。
    @State private var pendingUndoSnapshot: ItemSnapshot?
    @State private var undoTitle: String?
    @State private var undoTask: Task<Void, Never>?

    private let viewModel = ExtractorViewModel()

    private var purchasedItems: [Item] {
        allItems.filter { $0.status == .purchased }
    }

    private var savedAmountCents: Int {
        viewModel.totalSavedAmountCents(from: allItems)
    }

    private var topIdleItems: [Item] {
        viewModel.topIdleItems(from: allItems, limit: 3)
    }

    private var averageProgress: Double {
        let progresses = purchasedItems.compactMap { viewModel.paybackProgress(for: $0) }
        guard !progresses.isEmpty else {
            return 0
        }
        return progresses.reduce(0, +) / Double(progresses.count)
    }

    private var highRiskIdleCount: Int {
        purchasedItems.filter { (viewModel.idleDays(for: $0) ?? 0) >= AppConstants.Notification.lightIdleDays }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackgroundView()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        summaryHero
                            .cardReveal(isVisible: hasAppeared, delay: 0.02)

                        dashboardSection
                            .cardReveal(isVisible: hasAppeared, delay: 0.06)

                        sectionHeader(
                            title: "已购物品",
                            subtitle: "持续打卡，把单次成本拉下来",
                            count: purchasedItems.count
                        )

                        if purchasedItems.isEmpty {
                            emptyCard("暂无已购买物品。先去小黑屋做决策。")
                                .cardReveal(isVisible: hasAppeared, delay: 0.1)
                        } else {
                            ForEach(Array(purchasedItems.enumerated()), id: \.element.id) { index, item in
                                purchasedCard(item)
                                    .cardReveal(isVisible: hasAppeared, delay: 0.1 + Double(index) * 0.04)
                            }
                        }

                        sectionHeader(
                            title: "吃灰 Top 3",
                            subtitle: "优先处理这些高风险资产",
                            count: topIdleItems.count
                        )

                        if topIdleItems.isEmpty {
                            emptyCard("暂无数据。")
                                .cardReveal(isVisible: hasAppeared, delay: 0.16)
                        } else {
                            ForEach(Array(topIdleItems.enumerated()), id: \.offset) { index, item in
                                idleRankCard(index: index + 1, item: item)
                                    .cardReveal(isVisible: hasAppeared, delay: 0.16 + Double(index) * 0.04)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("闲置榨干机")
            .alert("确认删除该物品？", isPresented: showDeleteAlertBinding) {
                Button("取消", role: .cancel) {
                    itemPendingDeletion = nil
                }
                Button("删除", role: .destructive) {
                    if let item = itemPendingDeletion {
                        performDelete(item)
                    }
                    itemPendingDeletion = nil
                }
            } message: {
                Text("“\(itemPendingDeletion?.displayName ?? "该物品")”及其全部打卡记录会被删除。")
            }
            .task(id: purchasedItems.map(\.id)) {
                await rescheduleAllPurchasedReminders()
            }
            .safeAreaInset(edge: .bottom) {
                if let undoTitle, pendingUndoSnapshot != nil {
                    UndoToastView(
                        title: undoTitle,
                        onUndo: restoreLastDeletedItem,
                        onDismiss: clearUndoState
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(AppTheme.Motion.cardSpring, value: pendingUndoSnapshot != nil)
            .alert("操作失败", isPresented: showErrorBinding) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
            .onAppear {
                hasAppeared = true
            }
        }
    }

    /// 顶部总览卡片：展示榨干效率与风险数量。
    private var summaryHero: some View {
        GlassCardView(accent: AppTheme.Palette.success, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.Palette.success)
                    Text("资产榨干总览")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.Palette.primaryText)
                }

                Text("已跟踪 \(purchasedItems.count) 件物品，今天也要把买来的东西用起来。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.secondaryText)

                HStack {
                    heroMetric(title: "平均回本", value: "\(Int(averageProgress * 100))%", tint: AppTheme.Palette.success)
                    Spacer()
                    heroMetric(title: "高风险吃灰", value: "\(highRiskIdleCount)", tint: AppTheme.Palette.warning)
                    Spacer()
                    heroMetric(title: "累计打卡", value: "\(purchasedItems.map(\.usageCount).reduce(0, +))", tint: AppTheme.Palette.cooling)
                }
            }
        }
    }

    /// 顶部看板卡片，支持点击钻取。
    private var dashboardSection: some View {
        VStack(spacing: 12) {
            sectionHeader(
                title: "看板汇总",
                subtitle: "点击卡片查看完整明细",
                count: 3
            )

            HStack(spacing: 12) {
                NavigationLink {
                    SavedAmountDetailScreen()
                } label: {
                    dashboardCard(
                        title: "靠意念省下",
                        value: "¥\(centsToYuan(savedAmountCents))",
                        subtitle: "省钱明细",
                        icon: "banknote.fill",
                        tint: AppTheme.Palette.success
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    IdleRankingScreen()
                } label: {
                    dashboardCard(
                        title: "吃灰冠军",
                        value: topIdleItems.first.map { "\((viewModel.idleDays(for: $0) ?? 0)) 天" } ?? "暂无",
                        subtitle: "吃灰排行",
                        icon: "flame.fill",
                        tint: AppTheme.Palette.warning,
                        thumbnailData: topIdleItems.first?.coverImageData
                    )
                }
                .buttonStyle(.plain)
            }

            NavigationLink {
                ProgressBoardScreen()
            } label: {
                dashboardWideCard(
                    title: "平均回本进度",
                    value: "已追踪 \(purchasedItems.count) 件",
                    subtitle: "查看全部回本进度板",
                    icon: "chart.line.uptrend.xyaxis",
                    tint: AppTheme.Palette.cooling,
                    progress: averageProgress
                )
            }
            .buttonStyle(.plain)
        }
    }

    /// 已购物品卡片，支持进入详情页。
    private func purchasedCard(_ item: Item) -> some View {
        let progress = viewModel.paybackProgress(for: item) ?? 0

        return NavigationLink {
            ExtractorItemDetailScreen(
                item: item,
                viewModel: viewModel,
                onDelete: { target in
                    performDelete(target)
                }
            )
        } label: {
            GlassCardView(accent: AppTheme.Palette.success) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        ItemThumbnailView(imageData: item.coverImageData, size: 56, cornerRadius: 12)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.displayName)
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.primaryText)
                                .lineLimit(2)

                            Text("买入价：¥\(centsToYuan(item.purchasePriceCents ?? item.wishPriceCents))")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Palette.secondaryText)
                        }

                        Spacer(minLength: 10)

                        VStack(alignment: .trailing, spacing: 6) {
                            purchasedStatusTagView(for: item)

                            Text("打卡 \(item.usageCount)")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.Palette.cooling)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(AppTheme.Palette.cooling.opacity(0.14))
                                )
                        }
                    }

                    HStack {
                        Label(
                            "吃灰 \(viewModel.idleDays(for: item) ?? 0) 天",
                            systemImage: "calendar.badge.exclamationmark"
                        )
                        .font(.caption)
                        .foregroundStyle(AppTheme.Palette.tertiaryText)

                        Spacer()

                        Text(viewModel.currentCostPerUseCents(for: item).map { "单次 ¥\(centsToYuan($0))" } ?? "单次 未使用")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Palette.tertiaryText)
                    }

                    HStack {
                        Text("回本进度")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Palette.tertiaryText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.Palette.tertiaryText)
                    }

                    ProgressBarView(progress: progress, tintColor: AppTheme.Palette.success, height: 14)
                        .frame(height: 14)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                itemPendingDeletion = item
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    /// Top3 卡片样式。
    private func idleRankCard(index: Int, item: Item) -> some View {
        let medalColor: Color
        switch index {
        case 1:
            medalColor = Color(red: 0.95, green: 0.64, blue: 0.20)
        case 2:
            medalColor = Color(red: 0.67, green: 0.71, blue: 0.79)
        case 3:
            medalColor = Color(red: 0.77, green: 0.52, blue: 0.30)
        default:
            medalColor = AppTheme.Palette.tertiaryText
        }

        return GlassCardView(accent: AppTheme.Palette.warning) {
            HStack(spacing: 12) {
                Text("#\(index)")
                    .font(.headline.bold())
                    .foregroundStyle(medalColor)
                    .frame(width: 34)

                ItemThumbnailView(imageData: item.coverImageData, size: 44, cornerRadius: 10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayName)
                        .foregroundStyle(AppTheme.Palette.primaryText)
                    Text("最近使用：\(formattedLatestUsage(for: item))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Palette.tertiaryText)
                }

                Spacer()

                Text("\(viewModel.idleDays(for: item) ?? 0) 天")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.warning)
            }
        }
    }

    /// 半宽看板卡片样式。
    private func dashboardCard(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        tint: Color,
        thumbnailData: Data? = nil
    ) -> some View {
        GlassCardView(accent: tint, padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(tint)
                    Spacer()
                    if let thumbnailData {
                        ItemThumbnailView(imageData: thumbnailData, size: 26, cornerRadius: 7)
                    }
                }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Palette.secondaryText)
                Text(value)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(AppTheme.Palette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 4) {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.Palette.tertiaryText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(AppTheme.Palette.tertiaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 全宽看板卡片样式。
    private func dashboardWideCard(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        tint: Color,
        progress: Double
    ) -> some View {
        GlassCardView(accent: tint) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .foregroundStyle(tint)
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Palette.secondaryText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.Palette.tertiaryText)
                }

                Text(value)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.Palette.primaryText)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Palette.tertiaryText)

                ProgressBarView(progress: progress, tintColor: tint, height: 14)
                    .frame(height: 14)
            }
        }
    }

    /// 删除并注册撤销。
    private func performDelete(_ item: Item) {
        let snapshot = ItemSnapshot(item: item)
        NotificationManager.shared.cancelAllReminders(for: item.id)
        modelContext.delete(item)
        registerUndo(snapshot: snapshot, title: "已删除 \(snapshot.name)")
    }

    /// 同步全部已购物品通知计划。
    private func rescheduleAllPurchasedReminders() async {
        for item in purchasedItems {
            await NotificationManager.shared.scheduleIdleReminders(for: item)
        }
    }

    /// 注册删除后的撤销窗口（默认 6 秒）。
    private func registerUndo(snapshot: ItemSnapshot, title: String) {
        undoTask?.cancel()
        pendingUndoSnapshot = snapshot
        undoTitle = title

        undoTask = Task {
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            await MainActor.run {
                clearUndoState()
            }
        }
    }

    /// 执行撤销，恢复已删除条目。
    private func restoreLastDeletedItem() {
        guard let snapshot = pendingUndoSnapshot else {
            return
        }

        let restoredItem = snapshot.restore(in: modelContext)
        if restoredItem.status == .purchased {
            Task {
                await NotificationManager.shared.scheduleIdleReminders(for: restoredItem)
            }
        } else if restoredItem.status == .wish {
            Task {
                await NotificationManager.shared.scheduleCooldownDecisionReminders(for: restoredItem)
            }
        }
        clearUndoState()
    }

    /// 清空撤销状态。
    private func clearUndoState() {
        undoTask?.cancel()
        undoTask = nil
        pendingUndoSnapshot = nil
        undoTitle = nil
    }

    /// 分区标题样式。
    private func sectionHeader(title: String, subtitle: String, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.Palette.primaryText)
                Spacer()
                Text("\(count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Palette.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.52))
                    )
            }
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.tertiaryText)
        }
        .padding(.top, 8)
    }

    /// 顶部数据指标样式。
    private func heroMetric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.tertiaryText)
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
        }
    }

    /// 空态卡片。
    private func emptyCard(_ text: String) -> some View {
        GlassCardView(accent: AppTheme.Palette.cooling) {
            Text(text)
                .foregroundStyle(AppTheme.Palette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 删除确认弹窗展示控制。
    private var showDeleteAlertBinding: Binding<Bool> {
        Binding(
            get: { itemPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    itemPendingDeletion = nil
                }
            }
        )
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

    /// 格式化最近使用时间。
    private func formattedLatestUsage(for item: Item) -> String {
        let date = item.lastUsedAt ?? item.purchaseAt
        guard let date else { return "无记录" }
        return date.zhDateString()
    }

    /// 将“分”转换为“元”。
    private func centsToYuan(_ cents: Int) -> String {
        String(format: "%.2f", Double(cents) / 100.0)
    }

    /// 已购物品状态标签：根据打卡次数与吃灰天数动态更新。
    private func purchasedStatusTagView(for item: Item) -> some View {
        let status = viewModel.purchasedStatusTag(for: item)
        let tint: Color
        switch status.tone {
        case .fresh:
            tint = AppTheme.Palette.accent
        case .active:
            tint = AppTheme.Palette.success
        case .lightIdle:
            tint = AppTheme.Palette.cooling
        case .midIdle:
            tint = AppTheme.Palette.warning
        case .heavyIdle:
            tint = Color(red: 0.86, green: 0.28, blue: 0.25)
        }

        return Text(status.text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(tint.opacity(0.14))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.44), lineWidth: 1)
            )
    }
}

#Preview {
    ExtractorScreen()
        .modelContainer(for: [Item.self, UsageRecord.self], inMemory: true)
}
