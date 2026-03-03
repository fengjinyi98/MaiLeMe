//
//  DarkRoomScreen.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import SwiftUI
import SwiftData

/// 冲动小黑屋主页面：支持分区展示、详情跳转、删除确认与撤销。
struct DarkRoomScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.createdAt, order: .reverse) private var allItems: [Item]

    @State private var isPresentingAddSheet = false
    @State private var errorMessage: String?
    @State private var itemPendingDeletion: Item?
    @State private var hasAppeared = false

    /// 最近删除快照，用于撤销。
    @State private var pendingUndoSnapshot: ItemSnapshot?
    @State private var undoTitle: String?
    @State private var undoTask: Task<Void, Never>?

    private let viewModel = DarkRoomViewModel()

    private var wishItems: [Item] {
        allItems.filter { $0.status == .wish }
    }

    private var coolingItems: [Item] {
        wishItems.filter { !viewModel.canMakeDecision(for: $0) }
    }

    private var readyItems: [Item] {
        wishItems.filter { viewModel.canMakeDecision(for: $0) }
    }

    private var decisionRate: Double {
        guard !wishItems.isEmpty else { return 0 }
        return Double(readyItems.count) / Double(wishItems.count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackgroundView()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        summaryHero
                            .cardReveal(isVisible: hasAppeared, delay: 0.02)

                        sectionHeader(
                            title: "可决策",
                            subtitle: "冷静期到点，现在可以做最终决定",
                            count: readyItems.count
                        )

                        if readyItems.isEmpty {
                            emptyCard("今天情绪稳定，没有可决策条目。")
                                .cardReveal(isVisible: hasAppeared, delay: 0.08)
                        } else {
                            ForEach(Array(readyItems.enumerated()), id: \.element.id) { index, item in
                                wishCard(item: item, isReady: true)
                                    .cardReveal(isVisible: hasAppeared, delay: 0.08 + Double(index) * 0.04)
                            }
                        }

                        sectionHeader(
                            title: "待冷静",
                            subtitle: "把冲动关一会，给理性一点时间",
                            count: coolingItems.count
                        )

                        if coolingItems.isEmpty {
                            emptyCard("小黑屋当前空仓，可以放心逛但别乱买。")
                                .cardReveal(isVisible: hasAppeared, delay: 0.14)
                        } else {
                            ForEach(Array(coolingItems.enumerated()), id: \.element.id) { index, item in
                                wishCard(item: item, isReady: false)
                                    .cardReveal(isVisible: hasAppeared, delay: 0.14 + Double(index) * 0.04)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("冲动小黑屋")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    mockMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.Palette.accent)
                    }
                    .accessibilityLabel("新增条目")
                }
            }
            .sheet(isPresented: $isPresentingAddSheet) {
                AddItemScreen { name, wishPriceCents, cooldownDays, coverImageData in
                    createItem(
                        name: name,
                        wishPriceCents: wishPriceCents,
                        cooldownDays: cooldownDays,
                        coverImageData: coverImageData
                    )
                }
            }
            .confirmationDialog("确认删除该条目？", isPresented: showDeleteConfirmBinding) {
                Button("删除", role: .destructive) {
                    if let item = itemPendingDeletion {
                        performDelete(item)
                    }
                    itemPendingDeletion = nil
                }
                Button("取消", role: .cancel) {
                    itemPendingDeletion = nil
                }
            } message: {
                Text("“\(itemPendingDeletion?.displayName ?? "该条目")”将被删除。")
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
            .task(id: wishItems.map(\.id)) {
                await rescheduleAllWishReminders()
            }
            .onAppear {
                hasAppeared = true
            }
        }
    }

    /// 顶部汇总卡片：强化“克制消费”反馈。
    private var summaryHero: some View {
        GlassCardView(accent: AppTheme.Palette.accent, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.Palette.accent)
                    Text("你的理性防线")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.Palette.primaryText)
                }

                Text("有 \(wishItems.count) 个冲动被关进小黑屋，继续保持。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.secondaryText)

                ProgressBarView(
                    progress: decisionRate,
                    tintColor: AppTheme.Palette.success,
                    height: 16
                )
                .frame(height: 16)

                HStack {
                    heroMetric(title: "可决策", value: "\(readyItems.count)", tint: AppTheme.Palette.warning)
                    Spacer()
                    heroMetric(title: "待冷静", value: "\(coolingItems.count)", tint: AppTheme.Palette.cooling)
                    Spacer()
                    heroMetric(title: "总条目", value: "\(wishItems.count)", tint: AppTheme.Palette.success)
                }
            }
        }
    }

    /// 单个待购卡片，支持跳转详情与删除。
    private func wishCard(item: Item, isReady: Bool) -> some View {
        let remainingDays = viewModel.remainingCooldownDays(for: item)
        let totalDays = max(1, item.cooldownDays ?? 1)
        let cooldownProgress = isReady ? 1 : min(max(1.0 - (Double(remainingDays) / Double(totalDays)), 0), 1)

        return NavigationLink {
            WishItemDetailScreen(
                item: item,
                viewModel: viewModel,
                onDelete: { target in
                    performDelete(target)
                }
            )
        } label: {
            GlassCardView(accent: isReady ? AppTheme.Palette.warning : AppTheme.Palette.cooling) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        ItemThumbnailView(imageData: item.coverImageData, size: 56, cornerRadius: 12)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.displayName)
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.primaryText)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                            Text("想买价格：¥\(centsToYuan(item.wishPriceCents))")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Palette.secondaryText)
                        }

                        Spacer(minLength: 10)

                        statusTag(
                            text: isReady ? "可决策" : "待冷静",
                            tint: isReady ? AppTheme.Palette.warning : AppTheme.Palette.cooling
                        )
                    }

                    HStack(spacing: 8) {
                        Image(systemName: isReady ? "hourglass.bottomhalf.filled" : "hourglass")
                            .foregroundStyle(isReady ? AppTheme.Palette.warning : AppTheme.Palette.cooling)
                        Text(isReady ? "冷静期已结束，进入最终决策" : "还需冷静 \(remainingDays) 天")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Palette.tertiaryText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.Palette.tertiaryText)
                    }

                    ProgressBarView(
                        progress: cooldownProgress,
                        tintColor: isReady ? AppTheme.Palette.warning : AppTheme.Palette.cooling,
                        height: 14
                    )
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

    /// Mock 调试菜单。
    private var mockMenu: some View {
        Menu {
            Button("注入 Mock 数据") {
                seedMockData()
            }
            Button("清空本地数据", role: .destructive) {
                clearAllData()
            }
            Divider()
            Button("发送测试通知（3 秒）") {
                Task {
                    await MockNotificationFactory.sendQuickDemo()
                }
            }
            Button("发送毒舌通知组（4/8 秒）") {
                Task {
                    await MockNotificationFactory.sendRoastSequence()
                }
            }
            Button("发送冷静期提醒组（3/6 秒）") {
                Task {
                    await MockNotificationFactory.sendCooldownDecisionSequence()
                }
            }
        } label: {
            Label("Mock", systemImage: "hammer")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.secondaryText)
        }
    }

    /// 创建待购物品。
    private func createItem(
        name: String,
        wishPriceCents: Int,
        cooldownDays: Int,
        coverImageData: Data?
    ) {
        do {
            let item = try viewModel.createWishItem(
                name: name,
                wishPriceCents: wishPriceCents,
                cooldownDays: cooldownDays,
                coverImageData: coverImageData,
                context: modelContext
            )
            Task {
                await NotificationManager.shared.scheduleCooldownDecisionReminders(for: item)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 删除并注册撤销。
    private func performDelete(_ item: Item) {
        let snapshot = ItemSnapshot(item: item)
        NotificationManager.shared.cancelAllReminders(for: item.id)
        modelContext.delete(item)
        registerUndo(snapshot: snapshot, title: "已删除 \(snapshot.name)")
    }

    /// 注入一组可用于 UI/通知联调的 Mock 数据。
    private func seedMockData() {
        do {
            let purchasedItems = try MockDataSeeder.resetAndSeed(context: modelContext)
            let wishItems = try modelContext.fetch(FetchDescriptor<Item>())
                .filter { $0.status == .wish }
            Task {
                for item in purchasedItems {
                    await NotificationManager.shared.scheduleIdleReminders(for: item)
                }
                for item in wishItems {
                    await NotificationManager.shared.scheduleCooldownDecisionReminders(for: item)
                }
                await MockNotificationFactory.sendQuickDemo()
            }
        } catch {
            errorMessage = "Mock 注入失败：\(error.localizedDescription)"
        }
    }

    /// 清空全部本地数据。
    private func clearAllData() {
        do {
            for item in allItems {
                NotificationManager.shared.cancelAllReminders(for: item.id)
            }
            try MockDataSeeder.clearAll(context: modelContext)
            clearUndoState()
        } catch {
            errorMessage = "清空数据失败：\(error.localizedDescription)"
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

    /// 同步全部待购条目的冷静期决策提醒。
    private func rescheduleAllWishReminders() async {
        for item in allItems {
            if item.status == .wish {
                await NotificationManager.shared.scheduleCooldownDecisionReminders(for: item)
            } else {
                NotificationManager.shared.cancelCooldownDecisionReminders(for: item.id)
            }
        }
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

    /// 空态卡片。
    private func emptyCard(_ text: String) -> some View {
        GlassCardView(accent: AppTheme.Palette.cooling) {
            Text(text)
                .foregroundStyle(AppTheme.Palette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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

    /// 删除确认弹窗展示控制。
    private var showDeleteConfirmBinding: Binding<Bool> {
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

    /// 将“分”转换为“元”。
    private func centsToYuan(_ cents: Int) -> String {
        String(format: "%.2f", Double(cents) / 100.0)
    }
}

#Preview {
    DarkRoomScreen()
        .modelContainer(for: [Item.self, UsageRecord.self], inMemory: true)
}
