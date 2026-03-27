//
//  AddItemScreen.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import SwiftUI
import PhotosUI
import Photos
import UIKit

/// 新增页的品类状态快照：把自动识别结果、手动兜底结果与提交时的收敛逻辑集中在一起，便于 UI 与测试复用。
struct AddItemCategoryState {
    /// 当前界面上展示的自动识别一级品类。
    var detectedPrimaryCategory: ItemPrimaryCategory
    /// 当前界面上展示的自动识别二级品类。
    var detectedSecondaryCategory: ItemSecondaryCategory
    /// 当前界面上展示的自动识别置信度。
    var detectedConfidence: CopyConfidence
    /// 是否已启用手动兜底。
    var hasManualCategoryOverride: Bool
    /// 用户手动选择的一级品类。
    var manualPrimaryCategory: ItemPrimaryCategory
    /// 用户手动选择的二级品类。
    var manualSecondaryCategory: ItemSecondaryCategory

    /// 用最新名称刷新自动识别结果，但不会修改用户当前的手动兜底选择。
    /// - Parameters:
    ///   - name: `String`，用户当前输入的物品名称。
    ///   - classifier: `ItemCategoryClassifier`，可注入测试替身；默认使用生产规则分类器。
    mutating func refreshDetectedCategory(
        for name: String,
        classifier: ItemCategoryClassifier = .init()
    ) {
        let resolution = classifier.classify(name: name)
        detectedPrimaryCategory = resolution.primary
        detectedSecondaryCategory = resolution.secondary
        detectedConfidence = resolution.confidence
    }

    /// 在保存前同步收敛一次分类结果，确保提交一定基于当前名称的最新自动识别。
    /// - Parameters:
    ///   - currentName: `String`，点击保存时输入框中的最新名称。
    ///   - classifier: `ItemCategoryClassifier`，可注入测试替身；默认使用生产规则分类器。
    /// - Returns: `CategorySelection`，若已开启手动兜底则返回手动结果，否则返回同步刷新的自动结果。
    mutating func resolveSelectionForSubmit(
        currentName: String,
        classifier: ItemCategoryClassifier = .init()
    ) -> CategorySelection {
        refreshDetectedCategory(for: currentName, classifier: classifier)

        if hasManualCategoryOverride {
            return .manual(
                primary: manualPrimaryCategory,
                secondary: manualSecondaryCategory
            )
        }

        return .auto(
            primary: detectedPrimaryCategory,
            secondary: detectedSecondaryCategory,
            confidence: detectedConfidence
        )
    }
}

/// 新增待购物品页面。
struct AddItemScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var name: String = ""
    @State private var priceYuanText: String = ""
    @State private var cooldownDays: Int = 7
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var imageLoadErrorMessage: String?
    @State private var photoAuthorizationStatus: PHAuthorizationStatus = .notDetermined
    @State private var categoryState = AddItemCategoryState(
        detectedPrimaryCategory: .other,
        detectedSecondaryCategory: .other,
        detectedConfidence: .low,
        hasManualCategoryOverride: false,
        manualPrimaryCategory: .other,
        manualSecondaryCategory: .other
    )
    @State private var isPresentingCategorySheet = false
    /// 分类识别去抖任务：用于避免用户连续输入时重复触发规则匹配。
    @State private var categoryDetectionTask: Task<Void, Never>?

    /// 保存回调：由父页面处理持久化。
    let onSubmit: (CreateWishItemRequest) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackgroundView()

                ScrollView {
                    VStack(spacing: 14) {
                        GlassCardView(accent: AppTheme.Palette.accent) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("新增待购物品")
                                    .font(.title3.bold())
                                    .foregroundStyle(AppTheme.Palette.primaryText)
                                Text("先把冲动记下来，给自己一点冷静时间。")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.Palette.secondaryText)
                            }
                        }

                        GlassCardView(accent: AppTheme.Palette.cooling) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("基础信息")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.Palette.primaryText)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("物品名称")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.Palette.tertiaryText)
                                    brightInputField("例如：机械键盘", text: $name)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("预估价格（元）")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.Palette.tertiaryText)
                                    brightInputField("例如：599", text: $priceYuanText, keyboard: .decimalPad)
                                }
                            }
                        }

                        categoryCard

                        imagePickerCard

                        GlassCardView(accent: AppTheme.Palette.warning) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("冷静期")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.Palette.primaryText)

                                Text("\(cooldownDays) 天")
                                    .font(.system(size: 32, weight: .black, design: .rounded))
                                    .foregroundStyle(AppTheme.Palette.warning)

                                Stepper(value: $cooldownDays, in: 1...60) {
                                    Text("调整冷静天数")
                                        .foregroundStyle(AppTheme.Palette.secondaryText)
                                }
                                .tint(AppTheme.Palette.accent)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("添加条目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.Palette.secondaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard let cents = parsedPriceCents else {
                            return
                        }
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let categorySelection = resolveCategorySelectionForSubmit(currentName: trimmedName)
                        let request = CreateWishItemRequest(
                            name: trimmedName,
                            wishPriceCents: cents,
                            cooldownDays: cooldownDays,
                            coverImageData: selectedImageData,
                            categorySelection: categorySelection
                        )
                        onSubmit(request)
                        dismiss()
                    }
                    .disabled(!isFormValid)
                    .fontWeight(.semibold)
                    .foregroundStyle(isFormValid ? AppTheme.Palette.accent : AppTheme.Palette.tertiaryText)
                }
            }
            .sheet(isPresented: $isPresentingCategorySheet) {
                CategoryPickerSheet(
                    primaryCategory: categoryState.manualPrimaryCategory,
                    secondaryCategory: categoryState.manualSecondaryCategory,
                    showsResetToAutoAction: categoryState.hasManualCategoryOverride,
                    onConfirm: { primaryCategory, secondaryCategory in
                        categoryState.manualPrimaryCategory = primaryCategory
                        categoryState.manualSecondaryCategory = secondaryCategory
                        categoryState.hasManualCategoryOverride = true
                    },
                    onResetToAuto: restoreAutoCategorySelection
                )
                .presentationDetents([.medium, .large])
            }
            .onChange(of: selectedPhotoItem, initial: false) { _, item in
                Task {
                    await loadSelectedPhoto(from: item)
                }
            }
            .onChange(of: name, initial: false) { _, newValue in
                scheduleCategoryDetection(for: newValue)
            }
            .task {
                photoAuthorizationStatus = await currentPhotoAuthorizationStatus()
                applyAutoDetectedCategory(for: name)
            }
            .onDisappear {
                categoryDetectionTask?.cancel()
            }
        }
    }

    /// 品类信息卡片：展示自动识别结果、当前将要保存的结果以及手动兜底入口。
    private var categoryCard: some View {
        GlassCardView(accent: AppTheme.Palette.accent) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("品类识别")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.primaryText)

                        Text("系统识别：\(autoDetectedCategorySummary)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.primaryText)

                        Text("置信度：\(categoryState.detectedConfidence.addItemDisplayName)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(detectedConfidenceColor)
                    }

                    Spacer(minLength: 0)

                    if categoryState.hasManualCategoryOverride {
                        Text("已手动指定")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.Palette.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(AppTheme.Palette.accent.opacity(0.14))
                            )
                    }
                }

                if categoryState.hasManualCategoryOverride {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("当前保存：\(manualCategorySummary)")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.primaryText)
                        Text("你可以继续手动调整，也可以恢复为自动识别。")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Palette.tertiaryText)
                    }
                } else {
                    Text("若系统没认准，可手动选择一级 / 二级品类兜底。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Palette.tertiaryText)
                }

                HStack(spacing: 10) {
                    Button(categoryState.hasManualCategoryOverride ? "改一下" : actionButtonTitle) {
                        presentCategorySheet()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.Palette.accent)

                    if categoryState.hasManualCategoryOverride {
                        Button("恢复自动") {
                            restoreAutoCategorySelection()
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.Palette.secondaryText)
                    }
                }
            }
        }
    }

    /// 图片选择卡片：支持上传、预览和移除。
    private var imagePickerCard: some View {
        GlassCardView(accent: AppTheme.Palette.accent) {
            VStack(alignment: .leading, spacing: 12) {
                Text("商品图片（可选）")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.primaryText)

                HStack(alignment: .top, spacing: 12) {
                    ItemThumbnailView(
                        imageData: selectedImageData,
                        size: 72,
                        cornerRadius: 14,
                        placeholderSystemName: "photo.on.rectangle.angled"
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label(selectedImageData == nil ? "选择图片" : "重新选择", systemImage: "photo.badge.plus")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.accent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(AppTheme.Palette.accent.opacity(0.14))
                                )
                        }

                        if selectedImageData != nil {
                            Button(role: .destructive) {
                                selectedPhotoItem = nil
                                selectedImageData = nil
                                imageLoadErrorMessage = nil
                            } label: {
                                Label("移除图片", systemImage: "trash")
                                    .font(.caption.weight(.semibold))
                            }
                        }

                        Text("建议选择商品主图，列表会自动展示缩略图。")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Palette.tertiaryText)
                    }

                    Spacer(minLength: 0)
                }

                if showsPhotoPermissionWarning {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("相册权限未开启，当前无法选择商品图片。")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Palette.warning)
                        Button {
                            openSystemSettings()
                        } label: {
                            Label("去系统设置开启", systemImage: "gearshape")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.Palette.accent)
                    }
                } else if photoAuthorizationStatus == .notDetermined {
                    Text("首次选择图片时会弹出系统权限请求。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Palette.tertiaryText)
                }

                if let imageLoadErrorMessage {
                    Text(imageLoadErrorMessage)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Palette.warning)
                }
            }
        }
    }

    /// 自动识别结果摘要：优先展示二级品类，便于用户快速判断规则是否命中。
    private var autoDetectedCategorySummary: String {
        categorySummary(
            primary: categoryState.detectedPrimaryCategory,
            secondary: categoryState.detectedSecondaryCategory
        )
    }

    /// 手动覆盖后的摘要：用于明确告诉用户最终保存将采用哪组品类。
    private var manualCategorySummary: String {
        categorySummary(
            primary: categoryState.manualPrimaryCategory,
            secondary: categoryState.manualSecondaryCategory
        )
    }

    /// 自动识别入口按钮标题：未命中时引导用户直接选择品类，命中时引导用户微调。
    private var actionButtonTitle: String {
        categoryState.detectedSecondaryCategory == .other && categoryState.detectedPrimaryCategory == .other
            ? "选择品类"
            : "改一下"
    }

    /// 置信度对应的强调色：高置信度更亮，低置信度更保守。
    private var detectedConfidenceColor: Color {
        switch categoryState.detectedConfidence {
        case .high:
            return AppTheme.Palette.accent
        case .medium:
            return AppTheme.Palette.warning
        case .low:
            return AppTheme.Palette.secondaryText
        }
    }

    /// 是否应展示“相册权限未开启”警告。
    private var showsPhotoPermissionWarning: Bool {
        photoAuthorizationStatus == .denied || photoAuthorizationStatus == .restricted
    }

    /// 表单有效性校验：名称非空、价格可解析且不为负。
    private var isFormValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return false
        }
        guard let cents = parsedPriceCents else {
            return false
        }
        return cents >= 0
    }

    /// 将“元”文本解析为“分”。
    /// 解析失败时返回 `nil`，用于阻止提交。
    private var parsedPriceCents: Int? {
        let normalized = priceYuanText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return 0
        }
        guard let amount = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }
        let amountInCents = NSDecimalNumber(decimal: amount)
            .multiplying(by: NSDecimalNumber(value: 100))
            .intValue
        return max(0, amountInCents)
    }

    /// 明亮输入框样式，避免系统默认的灰色背景。
    private func brightInputField(
        _ placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .foregroundStyle(AppTheme.Palette.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.Palette.inputFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.Palette.cardStroke, lineWidth: 1)
            )
    }

    /// 读取相册图片并压缩到适合本地持久化的尺寸。
    private func loadSelectedPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let rawData = try await item.loadTransferable(type: Data.self) else {
                photoAuthorizationStatus = await currentPhotoAuthorizationStatus()
                imageLoadErrorMessage = showsPhotoPermissionWarning ? "相册权限未开启，请到系统设置授权。" : "图片读取失败，请重新选择。"
                return
            }
            guard let normalizedData = normalizedImageData(from: rawData) else {
                imageLoadErrorMessage = "图片格式不支持，请更换一张图片。"
                return
            }
            selectedImageData = normalizedData
            imageLoadErrorMessage = nil
            photoAuthorizationStatus = await currentPhotoAuthorizationStatus()
        } catch {
            imageLoadErrorMessage = "图片读取失败，请稍后重试。"
            photoAuthorizationStatus = await currentPhotoAuthorizationStatus()
        }
    }

    /// 根据当前名称调度一次去抖后的自动分类，避免输入法逐字更新时反复重算。
    /// 即使用户已经开启手动兜底，也要继续刷新 detected 结果，保证“恢复自动”时拿到的是最新识别值。
    /// - Parameter newValue: `String`，用户最新输入的物品名称。
    private func scheduleCategoryDetection(for newValue: String) {
        categoryDetectionTask?.cancel()

        categoryDetectionTask = Task { @MainActor in
            // 通过极短延迟聚合连续输入，既满足实时反馈，也减少 UI 抖动。
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else {
                return
            }
            applyAutoDetectedCategory(for: newValue)
        }
    }

    /// 立即执行一次自动分类，并把结果写回本地状态。
    /// - Parameter itemName: `String`，当前输入框中的商品名。
    private func applyAutoDetectedCategory(for itemName: String) {
        var state = categoryState
        state.refreshDetectedCategory(for: itemName)
        categoryState = state
    }

    /// 保存前同步收敛一次最新分类，消除“去抖任务尚未执行但用户已点击保存”的竞态。
    /// - Parameter currentName: `String`，点击保存时输入框中的最新名称。
    /// - Returns: `CategorySelection`，用于最终持久化写入的分类结果。
    private func resolveCategorySelectionForSubmit(currentName: String) -> CategorySelection {
        // 主动取消未完成的去抖任务，避免随后又回写一次过时检测结果。
        categoryDetectionTask?.cancel()

        var state = categoryState
        let selection = state.resolveSelectionForSubmit(currentName: currentName)
        categoryState = state
        return selection
    }

    /// 打开手动品类选择弹层。
    /// 若当前尚未覆盖，则先把自动结果拷贝成弹层默认值，减少用户重复输入。
    private func presentCategorySheet() {
        if !categoryState.hasManualCategoryOverride {
            categoryState.manualPrimaryCategory = categoryState.detectedPrimaryCategory
            categoryState.manualSecondaryCategory = categoryState.detectedSecondaryCategory
        }
        isPresentingCategorySheet = true
    }

    /// 恢复为自动识别模式，并立即根据当前名称刷新一次检测结果。
    private func restoreAutoCategorySelection() {
        categoryState.hasManualCategoryOverride = false
        applyAutoDetectedCategory(for: name)
    }

    /// 统一生成品类摘要文案，避免界面多个位置各自拼接导致表达不一致。
    /// - Parameters:
    ///   - primary: `ItemPrimaryCategory`，一级品类。
    ///   - secondary: `ItemSecondaryCategory`，二级品类；若不为 `.other`，优先展示该值。
    /// - Returns: `String`，可直接用于 UI 展示的摘要。
    private func categorySummary(
        primary: ItemPrimaryCategory,
        secondary: ItemSecondaryCategory
    ) -> String {
        if secondary != .other {
            return "\(secondary.addItemDisplayName) · \(secondary.primaryCategory.addItemDisplayName)"
        }
        if primary != .other {
            return "\(primary.addItemDisplayName) · 未细分"
        }
        return "暂未识别，默认归为其他"
    }

    /// 统一图片压缩策略，避免原图直接入库导致体积过大。
    private func normalizedImageData(from rawData: Data) -> Data? {
        ImageDataTransformer.normalizedJPEGData(from: rawData)
    }

    /// 获取当前相册授权状态。
    private func currentPhotoAuthorizationStatus() async -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    /// 跳转系统设置页。
    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

/// 手动品类选择弹层：允许用户按一级/二级品类兜底修正新增页识别结果。
private struct CategoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draftPrimaryCategory: ItemPrimaryCategory
    @State private var draftSecondaryCategory: ItemSecondaryCategory

    let showsResetToAutoAction: Bool
    let onConfirm: (_ primaryCategory: ItemPrimaryCategory, _ secondaryCategory: ItemSecondaryCategory) -> Void
    let onResetToAuto: () -> Void

    init(
        primaryCategory: ItemPrimaryCategory,
        secondaryCategory: ItemSecondaryCategory,
        showsResetToAutoAction: Bool,
        onConfirm: @escaping (_ primaryCategory: ItemPrimaryCategory, _ secondaryCategory: ItemSecondaryCategory) -> Void,
        onResetToAuto: @escaping () -> Void
    ) {
        _draftPrimaryCategory = State(initialValue: primaryCategory)
        _draftSecondaryCategory = State(initialValue: secondaryCategory)
        self.showsResetToAutoAction = showsResetToAutoAction
        self.onConfirm = onConfirm
        self.onResetToAuto = onResetToAuto
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("一级品类") {
                    Picker("一级品类", selection: $draftPrimaryCategory) {
                        ForEach(ItemPrimaryCategory.allCases, id: \.self) { category in
                            Text(category.addItemDisplayName)
                                .tag(category)
                        }
                    }
                }

                Section("二级品类") {
                    Picker("二级品类", selection: $draftSecondaryCategory) {
                        ForEach(availableSecondaryCategories, id: \.self) { category in
                            Text(category.addItemDisplayName)
                                .tag(category)
                        }
                    }
                }

                Section {
                    Text("若二级品类已明确，系统会自动收敛到它对应的一级品类；若选“其他”，则保留你当前选择的一级品类。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if showsResetToAutoAction {
                    Section {
                        Button("恢复自动识别") {
                            onResetToAuto()
                            dismiss()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("选择品类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onConfirm(draftPrimaryCategory, draftSecondaryCategory)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onChange(of: draftPrimaryCategory, initial: false) { _, newPrimary in
                // 当一级品类切换到不匹配的分组时，清空旧的二级品类，避免产生误导性组合。
                guard draftSecondaryCategory != .other else {
                    return
                }
                if draftSecondaryCategory.primaryCategory != newPrimary {
                    draftSecondaryCategory = .other
                }
            }
            .onChange(of: draftSecondaryCategory, initial: false) { _, newSecondary in
                // 一旦用户明确选中二级品类，就同步一级品类到 taxonomy 对应分组，减少冲突状态。
                guard newSecondary != .other else {
                    return
                }
                draftPrimaryCategory = newSecondary.primaryCategory
            }
        }
    }

    /// 当前一级品类下允许选择的二级品类列表。
    /// 始终包含 `.other`，以支持“只选一级品类，不做细分”的手动兜底场景。
    private var availableSecondaryCategories: [ItemSecondaryCategory] {
        let matchedCategories = ItemSecondaryCategory.allCases.filter {
            $0 == .other || $0.primaryCategory == draftPrimaryCategory
        }
        return matchedCategories
    }
}

/// 新增页内部使用的一级品类中文标题映射。
private extension ItemPrimaryCategory {
    var addItemDisplayName: String {
        switch self {
        case .digital:
            return "数码"
        case .office:
            return "办公"
        case .phoneAccessory:
            return "手机配件"
        case .appliance:
            return "家电"
        case .home:
            return "家居日用"
        case .clothing:
            return "服饰穿搭"
        case .beauty:
            return "美妆护肤"
        case .baby:
            return "母婴"
        case .sports:
            return "运动户外"
        case .hobby:
            return "兴趣爱好"
        case .food:
            return "食品饮料"
        case .pet:
            return "宠物"
        case .mobility:
            return "出行代步"
        case .subscription:
            return "订阅会员"
        case .other:
            return "其他"
        }
    }
}

/// 新增页内部使用的二级品类中文标题映射。
private extension ItemSecondaryCategory {
    var addItemDisplayName: String {
        switch self {
        case .ssd:
            return "固态硬盘"
        case .keyboard:
            return "键盘"
        case .monitor:
            return "显示器"
        case .desktopComputer:
            return "台式电脑"
        case .coffeeMachine:
            return "咖啡机"
        case .airFryer:
            return "空气炸锅"
        case .lipstick:
            return "口红"
        case .skincare:
            return "护肤品"
        case .catFood:
            return "猫粮"
        case .tissue:
            return "纸巾"
        case .campingChair:
            return "露营椅"
        case .softwareMembership:
            return "软件会员"
        case .other:
            return "其他"
        }
    }
}

/// 新增页内部使用的置信度中文标题映射。
private extension CopyConfidence {
    var addItemDisplayName: String {
        switch self {
        case .high:
            return "高"
        case .medium:
            return "中"
        case .low:
            return "低"
        }
    }
}

#Preview {
    AddItemScreen { _ in }
}
