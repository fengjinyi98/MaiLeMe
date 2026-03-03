//
//  RationalDefenseWidget.swift
//  MaiLeMeWidget
//
//  Created by Codex on 2026/3/4.
//

import SwiftUI
import WidgetKit

/// 多邻国风格色彩系统
private enum DuolingoColors {
    static let green = Color(red: 0.35, green: 0.80, blue: 0.01)     // #58CC02
    static let greenDark = Color(red: 0.29, green: 0.67, blue: 0.01) // #4B9E00
    static let blue = Color(red: 0.11, green: 0.69, blue: 0.96)      // #1CB0F6
    static let blueDark = Color(red: 0.09, green: 0.58, blue: 0.81)  // #1899D6
    static let orange = Color(red: 1.00, green: 0.59, blue: 0.00)    // #FF9600
    static let orangeDark = Color(red: 0.85, green: 0.50, blue: 0.00)// #D97E00
    static let red = Color(red: 1.00, green: 0.29, blue: 0.29)       // #FF4B4B
    static let redDark = Color(red: 0.84, green: 0.25, blue: 0.25)   // #D63F3F
    static let yellow = Color(red: 1.00, green: 0.78, blue: 0.00)    // #FFC800
    static let gray = Color(red: 0.90, green: 0.90, blue: 0.90)
    static let textMain = Color.primary
    static let textSecondary = Color.secondary
}

/// 多邻国风格的 3D 按钮/卡片修饰器
struct Duolingo3DStyle: ViewModifier {
    let color: Color
    let darkColor: Color
    let depth: CGFloat
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(darkColor)
                        .offset(y: depth)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(color)
                }
            )
    }
}

extension View {
    func duolingoButtonStyle(color: Color, darkColor: Color, depth: CGFloat = 4, cornerRadius: CGFloat = 12) -> some View {
        self.modifier(Duolingo3DStyle(color: color, darkColor: darkColor, depth: depth, cornerRadius: cornerRadius))
    }
}

/// 小组件共享常量：与主 App 约定同一组键值，避免 magic string 漂移。
private enum WidgetSharedConstants {
    static let rationalDefenseKind = "MaiLeMeRationalDefenseWidget"
    static let todayActionKind = "MaiLeMeTodayActionWidget"
    static let idleAlertKind = "MaiLeMeIdleAlertWidget"
    static let appGroupIdentifier = "group.com.jinyi.MaiLeMe"
    static let snapshotDefaultsKey = "widget.rationalDefense.snapshot.v1"
    static let deepLinkScheme = "maileme"
    static let darkRoomHost = "darkroom"
    static let extractorHost = "extractor"
    static let focusQueryName = "focus"
    static let itemIDQueryName = "itemID"
    static let extractorEntryQueryName = "entry"
    static let extractorEntryDetail = "detail"
    static let extractorEntryRescue = "rescue"
}

/// 小组件消费的快照模型（与主 App 侧编码结构保持一致）。
private struct RationalDefenseWidgetSnapshot: Codable {
    let generatedAt: Date
    let readyCount: Int
    let coolingCount: Int
    let totalWishCount: Int
    let totalSavedAmountCents: Int
    let topIdleItemName: String?
    let topIdleItemID: String?
    let topIdleDays: Int?

    static let placeholder = RationalDefenseWidgetSnapshot(
        generatedAt: .now,
        readyCount: 2,
        coolingCount: 4,
        totalWishCount: 6,
        totalSavedAmountCents: 26_800,
        topIdleItemName: "Kindle",
        topIdleItemID: nil,
        topIdleDays: 37
    )
}

/// 理性防线总览时间线条目。
private struct RationalDefenseEntry: TimelineEntry {
    let date: Date
    let snapshot: RationalDefenseWidgetSnapshot
}

/// 今日行动卡时间线条目。
private struct TodayActionEntry: TimelineEntry {
    let date: Date
    let snapshot: RationalDefenseWidgetSnapshot
}

/// 吃灰警报卡时间线条目。
private struct IdleAlertEntry: TimelineEntry {
    let date: Date
    let snapshot: RationalDefenseWidgetSnapshot
}

/// 数据源提供者：从 App Group 读取聚合快照，避免在小组件内直接读取 SwiftData。
private struct RationalDefenseTimelineProvider: TimelineProvider {
    private let decoder = JSONDecoder()

    func placeholder(in context: Context) -> RationalDefenseEntry {
        RationalDefenseEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (RationalDefenseEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RationalDefenseEntry>) -> Void) {
        let entry = makeEntry()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    /// 组装一条时间线条目。
    private func makeEntry() -> RationalDefenseEntry {
        RationalDefenseEntry(
            date: .now,
            snapshot: loadSnapshot() ?? .placeholder
        )
    }

    /// 从 App Group 读取快照；若不可用则回退占位数据。
    private func loadSnapshot() -> RationalDefenseWidgetSnapshot? {
        let defaults = UserDefaults(suiteName: WidgetSharedConstants.appGroupIdentifier) ?? .standard
        guard let data = defaults.data(forKey: WidgetSharedConstants.snapshotDefaultsKey) else {
            return nil
        }
        return try? decoder.decode(RationalDefenseWidgetSnapshot.self, from: data)
    }
}

/// 数据源提供者：复用同一份快照，为「今日行动卡」生成时间线。
private struct TodayActionTimelineProvider: TimelineProvider {
    private let decoder = JSONDecoder()

    func placeholder(in context: Context) -> TodayActionEntry {
        TodayActionEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayActionEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayActionEntry>) -> Void) {
        let entry = makeEntry()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    /// 组装一条时间线条目。
    private func makeEntry() -> TodayActionEntry {
        TodayActionEntry(
            date: .now,
            snapshot: loadSnapshot() ?? .placeholder
        )
    }

    /// 从 App Group 读取快照；若不可用则回退占位数据。
    private func loadSnapshot() -> RationalDefenseWidgetSnapshot? {
        let defaults = UserDefaults(suiteName: WidgetSharedConstants.appGroupIdentifier) ?? .standard
        guard let data = defaults.data(forKey: WidgetSharedConstants.snapshotDefaultsKey) else {
            return nil
        }
        return try? decoder.decode(RationalDefenseWidgetSnapshot.self, from: data)
    }
}

/// 数据源提供者：复用同一份快照，为「吃灰警报卡」生成时间线。
private struct IdleAlertTimelineProvider: TimelineProvider {
    private let decoder = JSONDecoder()

    func placeholder(in context: Context) -> IdleAlertEntry {
        IdleAlertEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (IdleAlertEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<IdleAlertEntry>) -> Void) {
        let entry = makeEntry()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    /// 组装一条时间线条目。
    private func makeEntry() -> IdleAlertEntry {
        IdleAlertEntry(
            date: .now,
            snapshot: loadSnapshot() ?? .placeholder
        )
    }

    /// 从 App Group 读取快照；若不可用则回退占位数据。
    private func loadSnapshot() -> RationalDefenseWidgetSnapshot? {
        let defaults = UserDefaults(suiteName: WidgetSharedConstants.appGroupIdentifier) ?? .standard
        guard let data = defaults.data(forKey: WidgetSharedConstants.snapshotDefaultsKey) else {
            return nil
        }
        return try? decoder.decode(RationalDefenseWidgetSnapshot.self, from: data)
    }
}

/// 小组件 V1-1：理性防线总览。
struct RationalDefenseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetSharedConstants.rationalDefenseKind,
            provider: RationalDefenseTimelineProvider()
        ) { entry in
            RationalDefenseWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("理性防线总览")
        .description("一眼看清可决策、待冷静、省钱与吃灰风险。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// 小组件 V1-2：今日行动卡。
struct TodayActionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetSharedConstants.todayActionKind,
            provider: TodayActionTimelineProvider()
        ) { entry in
            TodayActionWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("今日行动卡")
        .description("每天只给你一个动作，点一下就直达执行页。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// 小组件 V1-3：吃灰警报卡。
struct IdleAlertWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetSharedConstants.idleAlertKind,
            provider: IdleAlertTimelineProvider()
        ) { entry in
            IdleAlertWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("吃灰警报卡")
        .description("盯住 Top1 吃灰资产，立刻进入挽救动作。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// 小组件视图：理性防线总览。
private struct RationalDefenseWidgetEntryView: View {
    let entry: RationalDefenseEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        switch family {
        case .systemSmall:
            smallLayout
                .widgetURL(preferredFocusURL)
                .containerBackground(for: .widget) {
                    widgetBackground
                }
        default:
            mediumLayout
                .containerBackground(for: .widget) {
                    widgetBackground
                }
        }
    }

    /// 小尺寸布局：突出今天最核心的理性指标。
    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("理性防线")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(DuolingoColors.green)
                Spacer()
                Text("总 \(entry.snapshot.totalWishCount)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                metricRow(title: "可决策", value: "\(entry.snapshot.readyCount)", color: DuolingoColors.green, darkColor: DuolingoColors.greenDark)
                metricRow(title: "待冷静", value: "\(entry.snapshot.coolingCount)", color: DuolingoColors.orange, darkColor: DuolingoColors.orangeDark)
                metricRow(title: "已省下", value: moneyText(entry.snapshot.totalSavedAmountCents), color: DuolingoColors.blue, darkColor: DuolingoColors.blueDark)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
    }

    /// 中尺寸布局：增加吃灰风险与操作入口。
    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("理性防线总览")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(DuolingoColors.green)
                Spacer()
                Text(relativeTimeText(entry.snapshot.generatedAt))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                metricPill(title: "可决策", value: "\(entry.snapshot.readyCount)", color: DuolingoColors.green, darkColor: DuolingoColors.greenDark)
                metricPill(title: "待冷静", value: "\(entry.snapshot.coolingCount)", color: DuolingoColors.orange, darkColor: DuolingoColors.orangeDark)
                metricPill(title: "已省下", value: moneyShortText(entry.snapshot.totalSavedAmountCents), color: DuolingoColors.blue, darkColor: DuolingoColors.blueDark)
            }

            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(DuolingoColors.yellow)
                Text(topIdleText)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Link(destination: focusURL(.ready)) {
                    actionButton(title: "看可决策", color: DuolingoColors.green, darkColor: DuolingoColors.greenDark)
                }
                Link(destination: focusURL(.cooling)) {
                    actionButton(title: "看待冷静", color: DuolingoColors.orange, darkColor: DuolingoColors.orangeDark)
                }
            }
        }
        .padding(12)
    }

    /// 指标行。
    private func metricRow(title: String, value: String, color: Color, darkColor: Color) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .duolingoButtonStyle(color: color, darkColor: darkColor, depth: 2, cornerRadius: 6)
        }
    }

    /// 指标胶囊。
    private func metricPill(title: String, value: String, color: Color, darkColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .duolingoButtonStyle(color: color, darkColor: darkColor, depth: 3, cornerRadius: 10)
    }

    /// 操作按钮样式。
    private func actionButton(title: String, color: Color, darkColor: Color) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .duolingoButtonStyle(color: color, darkColor: darkColor, depth: 4, cornerRadius: 12)
    }

    /// 小组件底色：使用 iOS 26 的 Liquid Glass 效果。
    private var widgetBackground: some View {
        Rectangle()
            .fill(.clear)
            .glassEffect(.regular.interactive(), in: .rect)
    }

    /// 吃灰提醒文本。
    private var topIdleText: String {
        guard let name = entry.snapshot.topIdleItemName, let days = entry.snapshot.topIdleDays else {
            return "暂无吃灰风险数据。"
        }
        return "\(name)已吃灰\(days)天"
    }

    /// 优先跳转目标：有可决策就优先去可决策，否则去待冷静。
    private var preferredFocusURL: URL {
        if entry.snapshot.readyCount > 0 {
            return focusURL(.ready)
        }
        return focusURL(.cooling)
    }

    /// 生成小黑屋深链 URL。
    private func focusURL(_ focus: FocusRoute) -> URL {
        var components = URLComponents()
        components.scheme = WidgetSharedConstants.deepLinkScheme
        components.host = WidgetSharedConstants.darkRoomHost
        components.queryItems = [
            URLQueryItem(name: WidgetSharedConstants.focusQueryName, value: focus.rawValue)
        ]
        return components.url ?? URL(string: "maileme://darkroom?focus=all")!
    }

    /// 金额展示（分 -> 元）。
    private func moneyText(_ cents: Int) -> String {
        String(format: "¥%.1f", Double(cents) / 100.0)
    }

    /// 金额展示（简写）。
    private func moneyShortText(_ cents: Int) -> String {
        let yuan = Double(cents) / 100.0
        if yuan >= 10000 {
            return String(format: "%.1fW", yuan / 10000.0)
        } else if yuan >= 1000 {
            return String(format: "%.1fK", yuan / 1000.0)
        }
        return String(format: "%.0f", yuan)
    }

    /// 相对更新时间展示。
    private func relativeTimeText(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

/// 今日行动卡视图模型：把“今天最该做的一步”封装成展示与路由统一结构。
private struct TodayActionPlan {
    let badge: String
    let title: String
    let subtitle: String
    let buttonTitle: String
    let iconName: String
    let color: Color
    let darkColor: Color
    let url: URL
}

/// 小组件视图：今日行动卡。
private struct TodayActionWidgetEntryView: View {
    let entry: TodayActionEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    private var plan: TodayActionPlan {
        buildTodayActionPlan(from: entry.snapshot)
    }

    var body: some View {
        switch family {
        case .systemSmall:
            smallLayout
                .widgetURL(plan.url)
                .containerBackground(for: .widget) {
                    widgetBackground
                }
        default:
            mediumLayout
                .widgetURL(plan.url)
                .containerBackground(for: .widget) {
                    widgetBackground
                }
        }
    }

    /// 小尺寸布局：只留“今天做什么 + 一键执行”。
    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("今日行动")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(DuolingoColors.green)
                Spacer()
                Text(plan.badge)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(plan.color.opacity(0.15))
                    )
                    .foregroundStyle(plan.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Label {
                    Text(plan.title)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                } icon: {
                    Image(systemName: plan.iconName)
                        .foregroundStyle(plan.color)
                }

                Text(plan.subtitle)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Text(plan.buttonTitle)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .duolingoButtonStyle(color: plan.color, darkColor: plan.darkColor, depth: 3, cornerRadius: 10)
        }
        .padding(12)
    }

    /// 中尺寸布局：增加“为何推荐”的上下文信息。
    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今日行动卡")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(DuolingoColors.green)
                Spacer()
                Text(relativeTimeText(entry.snapshot.generatedAt))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.badge)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(plan.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(plan.color.opacity(0.12))
                        )

                    Text(plan.title)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Text(plan.subtitle)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(plan.color.opacity(0.1))
                    Image(systemName: plan.iconName)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(plan.color)
                }
                .frame(width: 48, height: 48)
            }

            HStack {
                Text(plan.buttonTitle)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .duolingoButtonStyle(color: plan.color, darkColor: plan.darkColor, depth: 3, cornerRadius: 10)
        }
        .padding(12)
    }

    /// 今日动作决策器：优先推动“可决策”清单，其次救活吃灰，再处理待冷静。
    private func buildTodayActionPlan(from snapshot: RationalDefenseWidgetSnapshot) -> TodayActionPlan {
        if snapshot.readyCount > 0 {
            return TodayActionPlan(
                badge: "高优先级",
                title: "先处理 \(snapshot.readyCount) 条可决策",
                subtitle: "今天先判一件，避免拖延后再次冲动下单。",
                buttonTitle: "去小黑屋决策",
                iconName: "gavel.fill",
                color: DuolingoColors.green,
                darkColor: DuolingoColors.greenDark,
                url: focusURL(.ready)
            )
        }

        if let idleDays = snapshot.topIdleDays,
           idleDays >= 7,
           let name = snapshot.topIdleItemName {
            return TodayActionPlan(
                badge: "吃灰预警",
                title: "\(name)已吃灰\(idleDays)天",
                subtitle: "现在打卡一次，先把它从吃灰名单里拽出来。",
                buttonTitle: "去榨干机打卡",
                iconName: "flame.fill",
                color: DuolingoColors.orange,
                darkColor: DuolingoColors.orangeDark,
                url: extractorURL(itemID: snapshot.topIdleItemID)
            )
        }

        if snapshot.coolingCount > 0 {
            return TodayActionPlan(
                badge: "稳住手速",
                title: "还有 \(snapshot.coolingCount) 条在冷静中",
                subtitle: "复盘一次清单，避免“看着看着就下单”。",
                buttonTitle: "查看待冷静",
                iconName: "hourglass.bottomhalf.filled",
                color: DuolingoColors.blue,
                darkColor: DuolingoColors.blueDark,
                url: focusURL(.cooling)
            )
        }

        return TodayActionPlan(
            badge: "保持节奏",
            title: "今天去榨干机补一条打卡",
            subtitle: "清单很干净，继续让已买资产发挥价值。",
            buttonTitle: "打开榨干机",
            iconName: "bolt.fill",
            color: DuolingoColors.green,
            darkColor: DuolingoColors.greenDark,
            url: extractorURL(itemID: nil)
        )
    }

    /// 今日行动卡背景：使用 iOS 26 的 Liquid Glass 效果，确保立体按钮更突出。
    private var widgetBackground: some View {
        Rectangle()
            .fill(.clear)
            .glassEffect(.regular.interactive(), in: .rect)
    }

    /// 生成小黑屋深链 URL。
    private func focusURL(_ focus: FocusRoute) -> URL {
        var components = URLComponents()
        components.scheme = WidgetSharedConstants.deepLinkScheme
        components.host = WidgetSharedConstants.darkRoomHost
        components.queryItems = [
            URLQueryItem(name: WidgetSharedConstants.focusQueryName, value: focus.rawValue)
        ]
        return components.url ?? URL(string: "maileme://darkroom?focus=all")!
    }

    /// 生成榨干机深链 URL：可选带 itemID，带上时会直达对应物品详情。
    private func extractorURL(itemID: String?) -> URL {
        var components = URLComponents()
        components.scheme = WidgetSharedConstants.deepLinkScheme
        components.host = WidgetSharedConstants.extractorHost
        if let itemID, !itemID.isEmpty {
            components.queryItems = [
                URLQueryItem(name: WidgetSharedConstants.itemIDQueryName, value: itemID)
            ]
        }
        return components.url ?? URL(string: "maileme://extractor")!
    }

    /// 相对更新时间展示。
    private func relativeTimeText(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

/// 吃灰警报卡视图：聚焦 Top1 闲置风险与立即挽救入口。
private struct IdleAlertWidgetEntryView: View {
    let entry: IdleAlertEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    /// 风险分级：用于映射颜色、标题与行为优先级。
    private enum AlertLevel {
        case none
        case light
        case medium
        case high
    }

    private var level: AlertLevel {
        guard let idleDays = entry.snapshot.topIdleDays else { return .none }
        switch idleDays {
        case 0..<7:
            return .light
        case 7..<30:
            return .medium
        default:
            return .high
        }
    }

    private var levelTitle: String {
        switch level {
        case .none:
            return "暂无警报"
        case .light:
            return "轻度预警"
        case .medium:
            return "中度预警"
        case .high:
            return "重度预警"
        }
    }

    private var levelColors: (main: Color, dark: Color) {
        switch level {
        case .none:
            return (DuolingoColors.blue, DuolingoColors.blueDark)
        case .light:
            return (DuolingoColors.green, DuolingoColors.greenDark)
        case .medium:
            return (DuolingoColors.orange, DuolingoColors.orangeDark)
        case .high:
            return (DuolingoColors.red, DuolingoColors.redDark)
        }
    }

    private var actionURL: URL {
        guard entry.snapshot.topIdleItemID != nil else {
            return extractorURL(itemID: nil, entryType: WidgetSharedConstants.extractorEntryDetail)
        }
        return extractorURL(
            itemID: entry.snapshot.topIdleItemID,
            entryType: WidgetSharedConstants.extractorEntryRescue
        )
    }

    var body: some View {
        switch family {
        case .systemSmall:
            smallLayout
                .widgetURL(actionURL)
                .containerBackground(for: .widget) {
                    widgetBackground
                }
        default:
            mediumLayout
                .widgetURL(actionURL)
                .containerBackground(for: .widget) {
                    widgetBackground
                }
        }
    }

    /// 小尺寸布局：突出“哪件在吃灰 + 今天就救”。
    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("吃灰警报")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(DuolingoColors.red)
                Spacer()
                Text(levelTitle)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(levelColors.main)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(levelColors.main.opacity(0.15))
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(alertHeadline)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Text(alertSubtitle)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Text("立刻去挽救")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .duolingoButtonStyle(color: levelColors.main, darkColor: levelColors.dark, depth: 3, cornerRadius: 10)
        }
        .padding(12)
    }

    /// 中尺寸布局：补充风险指标与执行提示，形成“预警 -> 行动”闭环。
    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("吃灰警报卡")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(DuolingoColors.red)
                Spacer()
                Text(relativeTimeText(entry.snapshot.generatedAt))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(levelTitle)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(levelColors.main)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(levelColors.main.opacity(0.12))
                        )

                    Text(alertHeadline)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(alertSubtitle)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                VStack(spacing: 6) {
                    alertMetric(title: "吃灰天数", value: idleDaysText, color: levelColors.main, darkColor: levelColors.dark)
                    alertMetric(title: "待冷静", value: "\(entry.snapshot.coolingCount)", color: DuolingoColors.orange, darkColor: DuolingoColors.orangeDark)
                }
            }

            HStack {
                Label("打开挽救页", systemImage: "lifepreserver.fill")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .duolingoButtonStyle(color: levelColors.main, darkColor: levelColors.dark, depth: 3, cornerRadius: 10)
        }
        .padding(12)
    }

    /// 警报指标胶囊。
    private func alertMetric(title: String, value: String, color: Color, darkColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
            Text(value)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: 70, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .duolingoButtonStyle(color: color, darkColor: darkColor, depth: 2, cornerRadius: 6)
    }

    /// 主标题：没有数据时降级为空状态引导。
    private var alertHeadline: String {
        guard let itemName = entry.snapshot.topIdleItemName,
              let idleDays = entry.snapshot.topIdleDays else {
            return "暂无高风险吃灰资产"
        }
        return "\(itemName)已吃灰\(idleDays)天"
    }

    /// 副标题：给出毒舌行动提示。
    private var alertSubtitle: String {
        guard entry.snapshot.topIdleItemName != nil,
              let idleDays = entry.snapshot.topIdleDays else {
            return "今天可继续打卡连击，降低成本。"
        }

        switch idleDays {
        case 0..<7:
            return "还来得及，今天用一次就能救它。"
        case 7..<30:
            return "再拖进重灾区，打卡或卖掉？"
        default:
            return "“站岗”太久，今天必须处置。"
        }
    }

    /// 闲置天数文字。
    private var idleDaysText: String {
        guard let idleDays = entry.snapshot.topIdleDays else {
            return "--"
        }
        return "\(idleDays)天"
    }

    /// 吃灰警报卡背景：使用 iOS 26 的 Liquid Glass 效果，完美适应主屏幕壁纸。
    private var widgetBackground: some View {
        Rectangle()
            .fill(.clear)
            .glassEffect(.regular.interactive(), in: .rect)
    }

    /// 生成榨干机深链 URL：支持详情或挽救入口。
    private func extractorURL(itemID: String?, entryType: String) -> URL {
        var components = URLComponents()
        components.scheme = WidgetSharedConstants.deepLinkScheme
        components.host = WidgetSharedConstants.extractorHost

        var items: [URLQueryItem] = [
            URLQueryItem(name: WidgetSharedConstants.extractorEntryQueryName, value: entryType)
        ]
        if let itemID, !itemID.isEmpty {
            items.append(URLQueryItem(name: WidgetSharedConstants.itemIDQueryName, value: itemID))
        }
        components.queryItems = items
        return components.url ?? URL(string: "maileme://extractor")!
    }

    /// 相对更新时间展示。
    private func relativeTimeText(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

/// 跳转焦点类型。
private enum FocusRoute: String {
    case all
    case ready
    case cooling
}
