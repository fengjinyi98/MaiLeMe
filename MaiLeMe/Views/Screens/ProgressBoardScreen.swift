//
//  ProgressBoardScreen.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import SwiftUI
import SwiftData

/// 资产健康板：查看所有已购物品的健康度与风险排序。
struct ProgressBoardScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.createdAt, order: .forward) private var allItems: [Item]
    @State private var hasAppeared = false
    @State private var errorMessage: String?

    private let viewModel = ExtractorViewModel()

    private var purchasedItems: [Item] {
        allItems.filter { $0.status == .purchased }
    }

    private var healthSortedItems: [Item] {
        purchasedItems.sorted { lhs, rhs in
            let lhsScore = viewModel.healthScore(for: lhs)
            let rhsScore = viewModel.healthScore(for: rhs)
            if lhsScore != rhsScore {
                return lhsScore < rhsScore
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    private var averageHealthScore: Double {
        guard !healthSortedItems.isEmpty else { return 0 }
        let values = healthSortedItems.map { viewModel.healthScore(for: $0) }
        return values.reduce(0, +) / Double(values.count)
    }

    var body: some View {
        ZStack {
            AuroraBackgroundView()

            ScrollView {
                VStack(spacing: 12) {
                    GlassCardView(accent: AppTheme.Palette.cooling) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("平均资产健康度")
                                .font(.caption)
                                .foregroundStyle(AppTheme.Palette.secondaryText)
                            Text("共 \(healthSortedItems.count) 件已追踪")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.Palette.primaryText)
                            ProgressBarView(progress: averageHealthScore, tintColor: AppTheme.Palette.cooling, height: 16)
                                .frame(height: 16)
                        }
                    }
                    .cardReveal(isVisible: hasAppeared, delay: 0.02)

                    if healthSortedItems.isEmpty {
                        GlassCardView(accent: AppTheme.Palette.warning) {
                            Text("暂无可计算资产健康度的数据。")
                                .foregroundStyle(AppTheme.Palette.secondaryText)
                        }
                        .cardReveal(isVisible: hasAppeared, delay: 0.06)
                    } else {
                        ForEach(Array(healthSortedItems.enumerated()), id: \.element.id) { index, item in
                            let snapshot = viewModel.healthSnapshot(for: item)
                            let score = snapshot?.overallScore ?? 0
                            let tint: Color = cardAccent(for: snapshot)

                            NavigationLink {
                                ExtractorItemDetailScreen(
                                    item: item,
                                    viewModel: viewModel,
                                    onDelete: { target in
                                        performDelete(target)
                                    }
                                )
                            } label: {
                                GlassCardView(accent: tint) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack(alignment: .top, spacing: 10) {
                                            ItemThumbnailView(imageData: item.coverImageData, size: 46, cornerRadius: 10)

                                            Text(item.displayName)
                                                .foregroundStyle(AppTheme.Palette.primaryText)
                                                .lineLimit(2)
                                            Spacer()
                                            VStack(alignment: .trailing, spacing: 5) {
                                                progressTag(for: item)
                                                Image(systemName: "chevron.right")
                                                    .font(.caption.bold())
                                                    .foregroundStyle(AppTheme.Palette.tertiaryText)
                                            }
                                        }

                                        metricLine(title: "日均持有成本", value: dailyHoldingCostText(for: item))
                                        metricLine(title: "近30天活跃", value: "\(snapshot?.activeDaysIn30 ?? 0) 天")
                                        metricLine(title: "连续闲置", value: "\(snapshot?.idleDays ?? 0) 天")

                                        ProgressBarView(progress: score, tintColor: tint, height: 14)
                                            .frame(height: 14)
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
        .navigationTitle("资产健康板")
        .navigationBarTitleDisplayMode(.inline)
        .alert("操作失败", isPresented: showErrorBinding) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
        .onAppear {
            hasAppeared = true
        }
    }

    /// 健康卡主色：高分偏绿色，中分偏蓝，低分偏橙红。
    private func cardAccent(for snapshot: ItemHealthSnapshot?) -> Color {
        guard let snapshot else {
            return AppTheme.Palette.cooling
        }
        if snapshot.idleDays >= 60 {
            return Color(red: 0.86, green: 0.28, blue: 0.25)
        }
        if snapshot.overallScore >= 0.75 {
            return AppTheme.Palette.success
        } else if snapshot.overallScore >= 0.45 {
            return AppTheme.Palette.cooling
        }
        return AppTheme.Palette.warning
    }

    /// 健康状态标签。
    private func progressTag(for item: Item) -> some View {
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
        case .resale:
            tint = Color(red: 0.86, green: 0.20, blue: 0.36)
        }

        return Text(status.text)
            .font(.caption.weight(.heavy))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(tint.opacity(0.14))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.8), lineWidth: 2)
            )
    }

    /// 指标行样式。
    private func metricLine(title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text("\(title)：")
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.tertiaryText)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.secondaryText)
            Spacer(minLength: 0)
        }
    }

    /// 日均持有成本展示文本。
    private func dailyHoldingCostText(for item: Item) -> String {
        guard let dailyCost = viewModel.dailyHoldingCostCents(for: item) else {
            return "暂无"
        }
        return "¥\(centsToYuan(dailyCost))/天"
    }

    /// 从进度板直接删除条目（供详情页回调）。
    private func performDelete(_ item: Item) {
        NotificationManager.shared.cancelAllReminders(for: item.id)
        modelContext.delete(item)
        do {
            try modelContext.save()
        } catch {
            errorMessage = "删除失败：\(error.localizedDescription)"
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
