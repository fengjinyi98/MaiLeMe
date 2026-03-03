//
//  InteractiveItemImageView.swift
//  MaiLeMe
//
//  Created by Codex on 2026/3/3.
//

import SwiftUI
import PhotosUI

/// 可交互物品图片：点击预览大图，长按更换图片。
struct InteractiveItemImageView: View {
    let imageData: Data?
    let previewTitle: String
    var size: CGFloat = 72
    var cornerRadius: CGFloat = 14
    let onImageUpdated: (Data?) -> Void
    let onError: (String) -> Void

    @State private var isPresentingPreview = false
    @State private var isPresentingPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        ItemThumbnailView(imageData: imageData, size: size, cornerRadius: cornerRadius)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white)
                    .padding(5)
                    .background(Circle().fill(Color.black.opacity(0.58)))
                    .padding(4)
            }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onTapGesture {
                if imageData != nil {
                    isPresentingPreview = true
                } else {
                    isPresentingPicker = true
                }
            }
            .onLongPressGesture(minimumDuration: 0.35) {
                isPresentingPicker = true
            }
            .photosPicker(
                isPresented: $isPresentingPicker,
                selection: $selectedPhotoItem,
                matching: .images
            )
            .onChange(of: selectedPhotoItem, initial: false) { _, item in
                Task {
                    await replaceImage(from: item)
                }
            }
            .sheet(isPresented: $isPresentingPreview) {
                if let imageData {
                    ItemImagePreviewScreen(imageData: imageData, title: previewTitle)
                }
            }
    }

    /// 从相册读取并替换图片。
    private func replaceImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let rawData = try await item.loadTransferable(type: Data.self) else {
                onError("图片读取失败，请重新选择。")
                return
            }
            guard let normalized = ImageDataTransformer.normalizedJPEGData(from: rawData) else {
                onError("图片格式不支持，请更换一张图片。")
                return
            }
            onImageUpdated(normalized)
        } catch {
            onError("更换图片失败，请稍后再试。")
        }
    }
}
