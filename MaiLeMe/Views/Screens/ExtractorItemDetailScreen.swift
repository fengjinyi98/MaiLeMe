//
//  ExtractorItemDetailScreen.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import SwiftUI
import SwiftData

/// 榨干机物品详情页：展示 ROI、打卡历史并支持删除。
struct ExtractorItemDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let item: Item
    let viewModel: ExtractorViewModel
    let onDelete: (Item) -> Void

    @State private var isPresentingDeleteConfirm = false
    @State private var isPresentingAdvancedCheckin = false
    @State private var errorMessage: String?
    @State private var celebrationPayload: CheckinCelebrationPayload?
    @State private var hasAppeared = false
    @State private var advancedUsedAt: Date = .now
    @State private var advancedDurationText: String = ""
    @State private var advancedNote: String = ""
    @State private var celebrationDismissTask: Task<Void, Never>?

    private var usageRecords: [UsageRecord] {
        item.usageRecords.sorted(by: { $0.usedAt > $1.usedAt })
    }

    private var paybackProgress: Double {
        viewModel.paybackProgress(for: item) ?? 0
    }

    var body: some View {
        ZStack {
            AuroraBackgroundView()

            ScrollView {
                VStack(spacing: 16) {
                    heroCard
                        .cardReveal(isVisible: hasAppeared, delay: 0.02)
                    metricCard
                        .cardReveal(isVisible: hasAppeared, delay: 0.06)
                    usageCard
                        .cardReveal(isVisible: hasAppeared, delay: 0.1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }

            if let celebrationPayload {
                CheckinCelebrationOverlay(
                    payload: celebrationPayload,
                    usageCount: item.usageCount,
                    currentCostText: viewModel.currentCostPerUseCents(for: item).map { "¥\(centsToYuan($0))" } ?? "未使用",
                    onDismiss: dismissCelebration
                )
                .transition(.scale(scale: 0.92).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .navigationTitle(item.displayName)
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
        .alert("确认删除该物品？", isPresented: $isPresentingDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                onDelete(item)
                dismiss()
            }
        } message: {
            Text("“\(item.displayName)”及全部打卡记录会被删除。")
        }
        .alert("操作失败", isPresented: showErrorBinding) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
        .sheet(isPresented: $isPresentingAdvancedCheckin) {
            advancedCheckinSheet
        }
        .onAppear {
            hasAppeared = true
        }
        .animation(AppTheme.Motion.cardSpring, value: celebrationPayload != nil)
        .onDisappear {
            celebrationDismissTask?.cancel()
        }
    }

    /// 顶部主卡：突出核心指标。
    private var heroCard: some View {
        GlassCardView(accent: AppTheme.Palette.success) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
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
                    VStack(alignment: .trailing, spacing: 6) {
                        purchasedStatusTagView
                        Text("打卡 \(item.usageCount)")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.Palette.cooling)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(AppTheme.Palette.cooling.opacity(0.14))
                            )
                    }
                }

                HStack {
                    metric(label: "买入价", value: "¥\(centsToYuan(item.purchasePriceCents ?? item.wishPriceCents))")
                    Spacer(minLength: 12)
                    metric(label: "吃灰天数", value: "\(viewModel.idleDays(for: item) ?? 0) 天")
                }

                Text("点击图片可看大图，长按可更换图片。")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.Palette.tertiaryText)

                ProgressBarView(progress: paybackProgress, tintColor: AppTheme.Palette.success, height: 16)
                    .frame(height: 16)
            }
        }
    }

    /// 成本与进度卡：展示 ROI 关键计算。
    private var metricCard: some View {
        GlassCardView(accent: AppTheme.Palette.cooling) {
            VStack(alignment: .leading, spacing: 12) {
                Text("ROI 指标")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.primaryText)

                metricRow(
                    title: "当前单次成本",
                    value: viewModel.currentCostPerUseCents(for: item).map { "¥\(centsToYuan($0))" } ?? "未使用"
                )

                metricRow(
                    title: "目标单次成本",
                    value: item.targetCostPerUseCents.map { "¥\(centsToYuan($0))" } ?? "未设置"
                )

                metricRow(
                    title: "最近使用",
                    value: (item.lastUsedAt ?? item.purchaseAt)?.zhDateTimeString() ?? "无记录"
                )

                HStack(spacing: 10) {
                    Button {
                        addUsage()
                    } label: {
                        Label("快速 +1", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SolidActionButtonStyle(tint: AppTheme.Palette.success))

                    Button {
                        prepareAdvancedCheckin()
                    } label: {
                        Label("详细打卡", systemImage: "slider.horizontal.3")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SolidActionButtonStyle(tint: AppTheme.Palette.cooling))
                }
            }
        }
    }

    /// 使用记录卡：展示最近打卡时间线。
    private var usageCard: some View {
        GlassCardView(accent: AppTheme.Palette.warning) {
            VStack(alignment: .leading, spacing: 12) {
                Text("使用记录")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.primaryText)

                if usageRecords.isEmpty {
                    Text("还没有任何打卡记录。")
                        .foregroundStyle(AppTheme.Palette.secondaryText)
                } else {
                    ForEach(usageRecords, id: \.id) { record in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(AppTheme.Palette.warning)
                                .frame(width: 8, height: 8)
                                .padding(.top, 5)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.usedAt.zhDateTimeString())
                                    .foregroundStyle(AppTheme.Palette.primaryText)
                                if let durationMinutes = record.durationMinutes {
                                    Text("使用时长：\(durationMinutes) 分钟")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.Palette.tertiaryText)
                                }
                                if let note = record.note, !note.isEmpty {
                                    Text(note)
                                        .font(.footnote)
                                        .foregroundStyle(AppTheme.Palette.secondaryText)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// 执行一次打卡并同步通知计划。
    private func addUsage() {
        addUsage(usedAt: .now, durationMinutes: nil, note: nil)
    }

    /// 按指定参数新增打卡并同步通知计划。
    private func addUsage(usedAt: Date, durationMinutes: Int?, note: String?) {
        do {
            let previousUsageCount = item.usageCount
            let previousIdleDays = viewModel.idleDays(for: item)

            try viewModel.addUsageRecord(
                for: item,
                usedAt: usedAt,
                durationMinutes: durationMinutes,
                note: note,
                context: modelContext
            )
            let celebration = viewModel.makeCheckinCelebration(
                for: item,
                previousUsageCount: previousUsageCount,
                previousIdleDays: previousIdleDays,
                usedAt: usedAt
            )
            presentCelebration(celebration)

            Task {
                await NotificationManager.shared.scheduleIdleReminders(for: item)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 准备并展示“详细打卡”弹层。
    private func prepareAdvancedCheckin() {
        advancedUsedAt = .now
        advancedDurationText = ""
        advancedNote = ""
        isPresentingAdvancedCheckin = true
    }

    /// 详细打卡弹层。
    private var advancedCheckinSheet: some View {
        NavigationStack {
            ZStack {
                AuroraBackgroundView()

                ScrollView {
                    VStack(spacing: 14) {
                        GlassCardView(accent: AppTheme.Palette.cooling) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("详细打卡")
                                    .font(.title3.bold())
                                    .foregroundStyle(AppTheme.Palette.primaryText)
                                Text("补充一次真实使用记录，时长和备注都可以填。")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.Palette.secondaryText)
                            }
                        }

                        GlassCardView(accent: AppTheme.Palette.success) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("打卡信息")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.Palette.primaryText)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("使用时间")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.Palette.tertiaryText)
                                    DatePicker(
                                        "使用时间",
                                        selection: $advancedUsedAt,
                                        displayedComponents: [.date, .hourAndMinute]
                                    )
                                    .labelsHidden()
                                    .environment(\.locale, Locale(identifier: "zh_CN"))
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("使用时长（分钟，可选）")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.Palette.tertiaryText)
                                    TextField("例如：45", text: $advancedDurationText)
                                        .keyboardType(.numberPad)
                                        .textFieldStyle(.roundedBorder)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("备注（可选）")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.Palette.tertiaryText)
                                    TextField("例如：阅读《纳瓦尔宝典》", text: $advancedNote, axis: .vertical)
                                        .lineLimit(2...4)
                                        .textFieldStyle(.roundedBorder)
                                }

                                if !isAdvancedDurationInputValid {
                                    Text("时长格式错误，请填写大于 0 的整数分钟。")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.Palette.warning)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("详细打卡")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresentingAdvancedCheckin = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        errorMessage = nil
                        addUsage(
                            usedAt: advancedUsedAt,
                            durationMinutes: parsedAdvancedDurationMinutes,
                            note: advancedNote
                        )
                        if errorMessage == nil {
                            isPresentingAdvancedCheckin = false
                        }
                    }
                    .disabled(!isAdvancedDurationInputValid)
                }
            }
        }
    }

    /// 解析后的“详细打卡时长”（分钟）。
    private var parsedAdvancedDurationMinutes: Int? {
        parsedPositiveInt(from: advancedDurationText)
    }

    /// “详细打卡时长”输入校验：空值合法，非空时需为正整数。
    private var isAdvancedDurationInputValid: Bool {
        advancedDurationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || parsedAdvancedDurationMinutes != nil
    }

    /// 将文本解析为正整数；空字符串返回 `nil`。
    private func parsedPositiveInt(from text: String) -> Int? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return nil
        }
        guard let value = Int(normalized), value > 0 else {
            return nil
        }
        return value
    }

    /// 小型指标展示组件。
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

    /// 指标行样式。
    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(AppTheme.Palette.secondaryText)
            Spacer()
            Text(value)
                .foregroundStyle(AppTheme.Palette.primaryText)
        }
        .font(.subheadline)
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

    /// 已购物品动态状态标签。
    private var purchasedStatusTagView: some View {
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

    /// 展示打卡成功仪式弹层，并安排自动消失。
    private func presentCelebration(_ payload: CheckinCelebrationPayload) {
        celebrationDismissTask?.cancel()
        HapticFeedback.checkinSuccess(isBigMoment: payload.isBigMoment)
        celebrationPayload = payload

        celebrationDismissTask = Task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            await MainActor.run {
                dismissCelebration()
            }
        }
    }

    /// 关闭仪式弹层并取消自动任务。
    private func dismissCelebration() {
        celebrationDismissTask?.cancel()
        celebrationDismissTask = nil
        celebrationPayload = nil
    }
}
