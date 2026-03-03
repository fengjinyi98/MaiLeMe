//
//  SavedAmountDetailScreen.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import SwiftUI
import SwiftData

/// 省钱明细页：展示“忍住没买”的历史条目。
struct SavedAmountDetailScreen: View {
    @Query(sort: \Item.createdAt, order: .reverse) private var allItems: [Item]
    @State private var hasAppeared = false

    private var savedItems: [Item] {
        allItems.filter { $0.status == .saved }
    }

    private var totalSavedCents: Int {
        savedItems.map(\.savedAmountCents).reduce(0, +)
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
                                    Text("¥\(centsToYuan(item.savedAmountCents))")
                                        .foregroundStyle(AppTheme.Palette.success)
                                        .fontWeight(.semibold)
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
