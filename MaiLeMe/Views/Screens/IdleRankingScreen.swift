//
//  IdleRankingScreen.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import SwiftUI
import SwiftData

/// 吃灰排行榜页面：展示全部已购物品按吃灰天数排序。
struct IdleRankingScreen: View {
    @Query(sort: \Item.createdAt, order: .forward) private var allItems: [Item]
    @State private var hasAppeared = false

    private let viewModel = ExtractorViewModel()

    private var rankedItems: [Item] {
        viewModel.topIdleItems(from: allItems, limit: allItems.count)
    }

    var body: some View {
        ZStack {
            AuroraBackgroundView()

            ScrollView {
                VStack(spacing: 12) {
                    if rankedItems.isEmpty {
                        GlassCardView(accent: AppTheme.Palette.warning) {
                            Text("暂无已购买物品。")
                                .foregroundStyle(AppTheme.Palette.secondaryText)
                        }
                        .cardReveal(isVisible: hasAppeared, delay: 0.02)
                    } else {
                        ForEach(Array(rankedItems.enumerated()), id: \.element.id) { index, item in
                            rankCard(rank: index + 1, item: item)
                                .cardReveal(
                                    isVisible: hasAppeared,
                                    delay: 0.04 + Double(index) * 0.04
                                )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle("吃灰排行榜")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            hasAppeared = true
        }
    }

    /// 单行排行卡片。
    private func rankCard(rank: Int, item: Item) -> some View {
        NavigationLink {
            IdleRescueScreen(item: item, viewModel: viewModel)
        } label: {
            GlassCardView(accent: AppTheme.Palette.warning) {
                HStack(alignment: .center, spacing: 12) {
                    Text("#\(rank)")
                        .font(.headline.bold())
                        .foregroundStyle(rankTint(rank))
                        .frame(width: 42)

                    ItemThumbnailView(imageData: item.coverImageData, size: 46, cornerRadius: 10)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.displayName)
                            .foregroundStyle(AppTheme.Palette.primaryText)
                        Text("最近使用：\(formattedLatestUsage(for: item))")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Palette.tertiaryText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(viewModel.idleDays(for: item) ?? 0) 天")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.warning)
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.Palette.tertiaryText)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// 根据名次返回不同主色。
    private func rankTint(_ rank: Int) -> Color {
        switch rank {
        case 1:
            return Color(red: 0.95, green: 0.64, blue: 0.20)
        case 2:
            return Color(red: 0.67, green: 0.71, blue: 0.79)
        case 3:
            return Color(red: 0.77, green: 0.52, blue: 0.30)
        default:
            return AppTheme.Palette.tertiaryText
        }
    }

    /// 格式化最近使用时间。
    private func formattedLatestUsage(for item: Item) -> String {
        let date = item.lastUsedAt ?? item.purchaseAt
        guard let date else { return "无记录" }
        return date.zhDateString()
    }
}
