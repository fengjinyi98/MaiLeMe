//
//  ProgressBoardScreen.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import SwiftUI
import SwiftData

/// 回本进度板：查看所有已购物品的当前 ROI 进度。
struct ProgressBoardScreen: View {
    @Query(sort: \Item.createdAt, order: .forward) private var allItems: [Item]
    @State private var hasAppeared = false

    private let viewModel = ExtractorViewModel()

    private var purchasedItems: [Item] {
        allItems.filter { $0.status == .purchased }
    }

    private var progressSortedItems: [Item] {
        purchasedItems.sorted { lhs, rhs in
            let lhsProgress = viewModel.paybackProgress(for: lhs) ?? 0
            let rhsProgress = viewModel.paybackProgress(for: rhs) ?? 0
            if lhsProgress != rhsProgress {
                return lhsProgress < rhsProgress
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    private var averageProgress: Double {
        let values = progressSortedItems.compactMap { viewModel.paybackProgress(for: $0) }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    var body: some View {
        ZStack {
            AuroraBackgroundView()

            ScrollView {
                VStack(spacing: 12) {
                    GlassCardView(accent: AppTheme.Palette.cooling) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("平均回本进度")
                                .font(.caption)
                                .foregroundStyle(AppTheme.Palette.secondaryText)
                            Text("共 \(progressSortedItems.count) 件可计算")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.Palette.primaryText)
                            ProgressBarView(progress: averageProgress, tintColor: AppTheme.Palette.cooling, height: 16)
                                .frame(height: 16)
                        }
                    }
                    .cardReveal(isVisible: hasAppeared, delay: 0.02)

                    if progressSortedItems.isEmpty {
                        GlassCardView(accent: AppTheme.Palette.warning) {
                            Text("暂无可计算回本进度的数据。")
                                .foregroundStyle(AppTheme.Palette.secondaryText)
                        }
                        .cardReveal(isVisible: hasAppeared, delay: 0.06)
                    } else {
                        ForEach(Array(progressSortedItems.enumerated()), id: \.element.id) { index, item in
                            let progress = viewModel.paybackProgress(for: item) ?? 0
                            let tint: Color = progress >= 1 ? AppTheme.Palette.success : AppTheme.Palette.cooling

                            GlassCardView(accent: tint) {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(alignment: .top, spacing: 10) {
                                        ItemThumbnailView(imageData: item.coverImageData, size: 46, cornerRadius: 10)

                                        Text(item.displayName)
                                            .foregroundStyle(AppTheme.Palette.primaryText)
                                            .lineLimit(2)
                                        Spacer()
                                        Text("目标追踪中")
                                            .foregroundStyle(AppTheme.Palette.tertiaryText)
                                            .font(.caption)
                                    }

                                    if let currentCost = viewModel.currentCostPerUseCents(for: item) {
                                        Text("当前单次成本：¥\(centsToYuan(currentCost))")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.Palette.tertiaryText)
                                    } else {
                                        Text("当前单次成本：未使用")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.Palette.tertiaryText)
                                    }

                                    ProgressBarView(progress: progress, tintColor: tint, height: 14)
                                        .frame(height: 14)
                                }
                            }
                            .cardReveal(isVisible: hasAppeared, delay: 0.08 + Double(index) * 0.04)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle("回本进度板")
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
