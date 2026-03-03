//
//  DarkRoomScreen.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 冲动小黑屋主页面：支持分区展示、详情跳转、删除确认与撤销。
struct DarkRoomScreen: View {
    /// 小黑屋列表聚焦模式：用于快速筛选“可决策 / 待冷静 / 全部”。
    private enum WishListFocus: String {
        case all
        case ready
        case cooling

        var title: String {
            switch self {
            case .all:
                return "总条目"
            case .ready:
                return "可决策"
            case .cooling:
                return "待冷静"
            }
        }
    }

    /// 价格筛选模式：用于在大列表中快速缩小查找范围。
    private enum PriceFilter: String, CaseIterable {
        case all
        case under500
        case from500To1500
        case above1500

        /// 筛选标题。
        var title: String {
            switch self {
            case .all:
                return "全部价格"
            case .under500:
                return "500 以下"
            case .from500To1500:
                return "500-1500"
            case .above1500:
                return "1500+"
            }
        }

        /// 是否命中当前价格区间（单位：分）。
        func matches(_ priceCents: Int) -> Bool {
            switch self {
            case .all:
                return true
            case .under500:
                return priceCents < 50_000
            case .from500To1500:
                return priceCents >= 50_000 && priceCents < 150_000
            case .above1500:
                return priceCents >= 150_000
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.createdAt, order: .reverse) private var allItems: [Item]

    @State private var isPresentingAddSheet = false
    @State private var errorMessage: String?
    @State private var itemPendingDeletion: Item?
    @State private var hasAppeared = false
    @State private var selectedFocus: WishListFocus = .all
    @State private var searchText: String = ""
    @State private var selectedPriceFilter: PriceFilter = .all
    /// 置顶条目 ID 存储（逗号分隔）：用于在不改模型结构的前提下持久化用户偏好。
    @AppStorage("darkRoomPinnedIDs") private var pinnedIDsStorage: String = ""
    /// 当前拖拽中的置顶条目 ID。
    @State private var draggingPinnedItemID: UUID?

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

    /// 已置顶条目 ID（有序）。
    private var pinnedOrderedIDs: [UUID] {
        pinnedIDsStorage
            .split(separator: ",")
            .compactMap { UUID(uuidString: String($0)) }
    }

    /// 已置顶条目 ID 集合。
    private var pinnedIDSet: Set<UUID> {
        Set(pinnedOrderedIDs)
    }

    /// 置顶顺序索引表：值越小代表越靠前。
    private var pinnedOrderMap: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: pinnedOrderedIDs.enumerated().map { ($0.element, $0.offset) })
    }

    /// 当前筛选条件下需要展示的置顶条目（保持置顶顺序）。
    private var displayedPinnedItems: [Item] {
        wishItems
            .filter { isPinned($0) }
            .filter(matchesFocus)
            .filter(matchesPriceFilter)
            .filter(matchesSearch)
            .sorted { lhs, rhs in
                let lhsOrder = pinnedOrderMap[lhs.id] ?? .max
                let rhsOrder = pinnedOrderMap[rhs.id] ?? .max
                if lhsOrder != rhsOrder {
                    return lhsOrder < rhsOrder
                }
                return lhs.createdAt < rhs.createdAt
            }
    }

    /// 清洗后的搜索词：用于忽略两端空白。
    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 按“到期最早优先”排序后的可决策条目。
    private var sortedReadyItems: [Item] {
        readyItems
            .filter { !isPinned($0) }
            .sorted { lhs, rhs in
            let lhsDate = lhs.cooldownEndAt ?? lhs.createdAt
            let rhsDate = rhs.cooldownEndAt ?? rhs.createdAt
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            return lhs.createdAt < rhs.createdAt
            }
    }

    /// 按“剩余天数最少优先”排序后的待冷静条目。
    private var sortedCoolingItems: [Item] {
        coolingItems
            .filter { !isPinned($0) }
            .sorted { lhs, rhs in
            let lhsRemaining = viewModel.remainingCooldownDays(for: lhs)
            let rhsRemaining = viewModel.remainingCooldownDays(for: rhs)
            if lhsRemaining != rhsRemaining {
                return lhsRemaining < rhsRemaining
            }
            return lhs.createdAt < rhs.createdAt
            }
    }

    /// 当前搜索下可展示的可决策条目。
    private var displayedReadyItems: [Item] {
        sortedReadyItems
            .filter(matchesPriceFilter)
            .filter(matchesSearch)
    }

    /// 当前搜索下可展示的待冷静条目。
    private var displayedCoolingItems: [Item] {
        sortedCoolingItems
            .filter(matchesPriceFilter)
            .filter(matchesSearch)
    }

    /// 当前焦点+搜索下的展示总量。
    private var visibleItemCount: Int {
        switch selectedFocus {
        case .all:
            return displayedPinnedItems.count + displayedReadyItems.count + displayedCoolingItems.count
        case .ready:
            return displayedPinnedItems.count + displayedReadyItems.count
        case .cooling:
            return displayedPinnedItems.count + displayedCoolingItems.count
        }
    }

    /// 当前是否存在可展示置顶区。
    private var shouldShowPinnedSection: Bool {
        !displayedPinnedItems.isEmpty
    }

    /// 是否需要展示“可决策”分区。
    private var shouldShowReadySection: Bool {
        selectedFocus != .cooling
    }

    /// 是否需要展示“待冷静”分区。
    private var shouldShowCoolingSection: Bool {
        selectedFocus != .ready
    }

    /// 当前搜索词下是否没有任何命中结果。
    private var hasNoSearchResult: Bool {
        !normalizedSearchText.isEmpty && visibleItemCount == 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackgroundView()

                contentScrollView
            }
            .navigationTitle("冲动小黑屋")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "搜索条目名称")
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
                removeInvalidPinnedIDs()
            }
            .onChange(of: wishItems.map(\.id), initial: false) { _, _ in
                removeInvalidPinnedIDs()
            }
        }
    }

    /// 页面滚动主体：分离 `body` 复杂度，避免 SwiftUI 类型推断超时。
    private var contentScrollView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                summaryHero
                    .cardReveal(isVisible: hasAppeared, delay: 0.02)

                priceFilterBar
                    .cardReveal(isVisible: hasAppeared, delay: 0.05)

                listSections
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 30)
        }
    }

    /// 列表分区容器：按“搜索命中/筛选模式”动态组织。
    @ViewBuilder
    private var listSections: some View {
        if hasNoSearchResult {
            emptyCard("没有找到匹配条目，换个关键词试试。")
                .cardReveal(isVisible: hasAppeared, delay: 0.08)
        } else {
            if shouldShowPinnedSection {
                pinnedSection
            }
            if shouldShowReadySection {
                readySection
            }
            if shouldShowCoolingSection {
                coolingSection
            }
        }
    }

    /// 置顶分区：支持多条目拖拽排序。
    @ViewBuilder
    private var pinnedSection: some View {
        sectionHeader(
            title: "置顶条目",
            subtitle: "长按拖拽可排序，优先处理最常纠结的冲动",
            count: displayedPinnedItems.count
        )

        ForEach(Array(displayedPinnedItems.enumerated()), id: \.element.id) { index, item in
            pinnedWishCard(item: item)
                .cardReveal(isVisible: hasAppeared, delay: 0.06 + Double(index) * 0.03)
        }
    }

    /// 可决策分区。
    @ViewBuilder
    private var readySection: some View {
        sectionHeader(
            title: "可决策",
            subtitle: "冷静期到点，现在可以做最终决定",
            count: displayedReadyItems.count
        )

        if displayedReadyItems.isEmpty {
            emptyCard("当前筛选下没有可决策条目。")
                .cardReveal(isVisible: hasAppeared, delay: 0.08)
        } else {
            ForEach(Array(displayedReadyItems.enumerated()), id: \.element.id) { index, item in
                wishCard(item: item, isReady: true)
                    .cardReveal(isVisible: hasAppeared, delay: 0.08 + Double(index) * 0.04)
            }
        }
    }

    /// 待冷静分区。
    @ViewBuilder
    private var coolingSection: some View {
        sectionHeader(
            title: "待冷静",
            subtitle: "把冲动关一会，给理性一点时间",
            count: displayedCoolingItems.count
        )

        if displayedCoolingItems.isEmpty {
            emptyCard("当前筛选下没有待冷静条目。")
                .cardReveal(isVisible: hasAppeared, delay: 0.14)
        } else {
            ForEach(Array(displayedCoolingItems.enumerated()), id: \.element.id) { index, item in
                wishCard(item: item, isReady: false)
                    .cardReveal(isVisible: hasAppeared, delay: 0.14 + Double(index) * 0.04)
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

                Text(summaryDescriptionText)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.secondaryText)

                ProgressBarView(
                    progress: decisionRate,
                    tintColor: AppTheme.Palette.success,
                    height: 16
                )
                .frame(height: 16)

                HStack {
                    metricFilterButton(
                        focus: .ready,
                        value: "\(readyItems.count)",
                        tint: AppTheme.Palette.warning
                    )
                    Spacer()
                    metricFilterButton(
                        focus: .cooling,
                        value: "\(coolingItems.count)",
                        tint: AppTheme.Palette.cooling
                    )
                    Spacer()
                    metricFilterButton(
                        focus: .all,
                        value: "\(wishItems.count)",
                        tint: AppTheme.Palette.success
                    )
                }

                Text("点击上方数字可快速筛选条目。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Palette.tertiaryText)
            }
        }
    }

    /// 价格筛选条：用于快速缩小列表范围。
    private var priceFilterBar: some View {
        GlassCardView(accent: AppTheme.Palette.cooling, padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("价格筛选")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Palette.secondaryText)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(PriceFilter.allCases, id: \.rawValue) { filter in
                            Button {
                                withAnimation(AppTheme.Motion.cardSpring) {
                                    selectedPriceFilter = filter
                                }
                            } label: {
                                Text(filter.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(selectedPriceFilter == filter ? AppTheme.Palette.primaryText : AppTheme.Palette.secondaryText)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule()
                                            .fill(
                                                selectedPriceFilter == filter
                                                    ? AppTheme.Palette.cooling.opacity(0.24)
                                                    : AppTheme.Palette.softSurface
                                            )
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                selectedPriceFilter == filter
                                                    ? AppTheme.Palette.cooling.opacity(0.8)
                                                    : Color.clear,
                                                lineWidth: 1.5
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    /// 顶部摘要文案：根据搜索和筛选上下文动态提示。
    private var summaryDescriptionText: String {
        if !normalizedSearchText.isEmpty {
            return "关键词“\(normalizedSearchText)”命中 \(visibleItemCount) 条，继续定位目标条目。"
        }
        if selectedPriceFilter != .all {
            return "当前价格筛选：\(selectedPriceFilter.title)，匹配 \(visibleItemCount) 条。"
        }
        if !pinnedOrderedIDs.isEmpty {
            return "已置顶 \(pinnedOrderedIDs.count) 条，最常纠结的条目会始终排在前面。"
        }
        switch selectedFocus {
        case .all:
            return "有 \(wishItems.count) 个冲动被关进小黑屋，继续保持。"
        case .ready:
            return "当前聚焦可决策条目，优先处理已到期的冲动消费。"
        case .cooling:
            return "当前聚焦待冷静条目，先熬过倒计时再做决定。"
        }
    }

    /// 置顶卡片容器：叠加拖拽排序能力，不影响原有卡片样式。
    private func pinnedWishCard(item: Item) -> some View {
        let isReady = viewModel.canMakeDecision(for: item)
        return wishCard(item: item, isReady: isReady)
            .onDrag {
                draggingPinnedItemID = item.id
                return NSItemProvider(object: item.id.uuidString as NSString)
            }
            .onDrop(
                of: [UTType.text],
                delegate: PinnedItemDropDelegate(
                    targetItemID: item.id,
                    draggingPinnedItemID: $draggingPinnedItemID,
                    moveAction: movePinnedItem
                )
            )
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

                        VStack(alignment: .trailing, spacing: 6) {
                            if isPinned(item) {
                                statusTag(
                                    text: "已置顶",
                                    tint: AppTheme.Palette.accent
                                )
                            }

                            statusTag(
                                text: isReady ? "可决策" : "待冷静",
                                tint: isReady ? AppTheme.Palette.warning : AppTheme.Palette.cooling
                            )
                        }
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
            Button {
                togglePinned(item)
            } label: {
                Label(isPinned(item) ? "取消置顶" : "加入置顶区", systemImage: isPinned(item) ? "pin.slash" : "pin.fill")
            }

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
                            .fill(AppTheme.Palette.softSurface)
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

    /// 可点击的顶部筛选指标按钮。
    private func metricFilterButton(
        focus: WishListFocus,
        value: String,
        tint: Color
    ) -> some View {
        Button {
            withAnimation(AppTheme.Motion.cardSpring) {
                selectedFocus = focus
            }
        } label: {
            heroMetric(
                title: focus.title,
                value: value,
                tint: tint,
                isActive: selectedFocus == focus
            )
        }
        .buttonStyle(.plain)
    }

    /// 顶部数据指标样式。
    private func heroMetric(
        title: String,
        value: String,
        tint: Color,
        isActive: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.tertiaryText)
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isActive ? tint.opacity(0.14) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isActive ? tint.opacity(0.45) : Color.clear, lineWidth: 1.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    /// 当前价格筛选是否命中。
    private func matchesPriceFilter(_ item: Item) -> Bool {
        selectedPriceFilter.matches(item.wishPriceCents)
    }

    /// 当前焦点筛选是否命中。
    private func matchesFocus(_ item: Item) -> Bool {
        switch selectedFocus {
        case .all:
            return true
        case .ready:
            return viewModel.canMakeDecision(for: item)
        case .cooling:
            return !viewModel.canMakeDecision(for: item)
        }
    }

    /// 搜索匹配规则：名称包含关键词即命中（忽略大小写）。
    private func matchesSearch(_ item: Item) -> Bool {
        guard !normalizedSearchText.isEmpty else {
            return true
        }
        return item.displayName.localizedCaseInsensitiveContains(normalizedSearchText)
    }

    /// 判断条目是否已置顶。
    private func isPinned(_ item: Item) -> Bool {
        pinnedIDSet.contains(item.id)
    }

    /// 切换置顶状态并持久化到本地偏好。
    private func togglePinned(_ item: Item) {
        var ids = pinnedOrderedIDs
        if let index = ids.firstIndex(of: item.id) {
            ids.remove(at: index)
        } else {
            // 新置顶默认插入到最前，减少重复查找成本。
            ids.insert(item.id, at: 0)
        }
        savePinnedIDs(ids)
    }

    /// 在置顶列表内移动顺序：将 source 移动到 target 前面。
    private func movePinnedItem(sourceID: UUID, targetID: UUID) {
        guard sourceID != targetID else {
            return
        }
        var ids = pinnedOrderedIDs
        guard let fromIndex = ids.firstIndex(of: sourceID),
              let targetIndex = ids.firstIndex(of: targetID) else {
            return
        }
        let moving = ids.remove(at: fromIndex)
        let insertionIndex = fromIndex < targetIndex ? max(targetIndex - 1, 0) : targetIndex
        ids.insert(moving, at: insertionIndex)
        savePinnedIDs(ids)
    }

    /// 清理已不存在条目的置顶 ID，避免偏好数据累积脏值。
    private func removeInvalidPinnedIDs() {
        let validIDs = Set(wishItems.map(\.id))
        let cleaned = pinnedOrderedIDs.filter { validIDs.contains($0) }
        if cleaned != pinnedOrderedIDs {
            savePinnedIDs(cleaned)
        }
    }

    /// 保存置顶 ID（有序）。
    private func savePinnedIDs(_ ids: [UUID]) {
        // 去重并保持首个出现顺序，避免拖拽过程中出现重复 ID。
        var seen = Set<UUID>()
        let uniqueOrdered = ids.filter { seen.insert($0).inserted }
        pinnedIDsStorage = uniqueOrdered
            .map(\.uuidString)
            .joined(separator: ",")
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

/// 置顶条目拖拽排序代理：进入目标卡片时立即重排，放手后结束拖拽态。
private struct PinnedItemDropDelegate: DropDelegate {
    let targetItemID: UUID
    @Binding var draggingPinnedItemID: UUID?
    let moveAction: (_ sourceID: UUID, _ targetID: UUID) -> Void

    func dropEntered(info: DropInfo) {
        guard let sourceID = draggingPinnedItemID, sourceID != targetItemID else {
            return
        }
        moveAction(sourceID, targetItemID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingPinnedItemID = nil
        return true
    }
}

#Preview {
    DarkRoomScreen()
        .modelContainer(for: [Item.self, UsageRecord.self], inMemory: true)
}
