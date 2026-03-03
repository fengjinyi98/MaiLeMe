//
//  AddItemScreen.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import SwiftUI
import PhotosUI
import UIKit

/// 新增待购物品页面。
struct AddItemScreen: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var priceYuanText: String = ""
    @State private var cooldownDays: Int = 7
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var imageLoadErrorMessage: String?

    /// 保存回调：由父页面处理持久化。
    let onSubmit: (_ name: String, _ wishPriceCents: Int, _ cooldownDays: Int, _ coverImageData: Data?) -> Void

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
                        onSubmit(trimmedName, cents, cooldownDays, selectedImageData)
                        dismiss()
                    }
                    .disabled(!isFormValid)
                    .fontWeight(.semibold)
                    .foregroundStyle(isFormValid ? AppTheme.Palette.accent : AppTheme.Palette.tertiaryText)
                }
            }
            .onChange(of: selectedPhotoItem) { _, item in
                Task {
                    await loadSelectedPhoto(from: item)
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

                if let imageLoadErrorMessage {
                    Text(imageLoadErrorMessage)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Palette.warning)
                }
            }
        }
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
                    .fill(Color.white.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.Palette.cardStroke, lineWidth: 1)
            )
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

    /// 读取相册图片并压缩到适合本地持久化的尺寸。
    private func loadSelectedPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let rawData = try await item.loadTransferable(type: Data.self) else {
                imageLoadErrorMessage = "图片读取失败，请重新选择。"
                return
            }
            guard let normalizedData = normalizedImageData(from: rawData) else {
                imageLoadErrorMessage = "图片格式不支持，请更换一张图片。"
                return
            }
            selectedImageData = normalizedData
            imageLoadErrorMessage = nil
        } catch {
            imageLoadErrorMessage = "图片读取失败，请稍后重试。"
        }
    }

    /// 统一图片压缩策略，避免原图直接入库导致体积过大。
    private func normalizedImageData(from rawData: Data) -> Data? {
        ImageDataTransformer.normalizedJPEGData(from: rawData)
    }
}

#Preview {
    AddItemScreen { _, _, _, _ in }
}
