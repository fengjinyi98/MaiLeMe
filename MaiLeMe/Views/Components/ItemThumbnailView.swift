//
//  ItemThumbnailView.swift
//  MaiLeMe
//
//  Created by Codex on 2026/3/3.
//

import SwiftUI
import UIKit

/// 通用物品缩略图组件：统一处理有图展示与无图占位。
struct ItemThumbnailView: View {
    let imageData: Data?
    var size: CGFloat = 56
    var cornerRadius: CGFloat = 16 // 多邻国风格：放大圆角
    var placeholderSystemName: String = "photo"

    private var uiImage: UIImage? {
        guard let imageData else { return nil }
        return UIImage(data: imageData)
    }

    var body: some View {
        ZStack {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.Palette.progressTrack)
                Image(systemName: placeholderSystemName)
                    .font(.system(size: size * 0.34, weight: .bold)) // 加粗 icon
                    .foregroundStyle(AppTheme.Palette.tertiaryText)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            // 加粗线框，呼应卡片风格
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(AppTheme.Palette.cardStroke, lineWidth: 2.0)
        )
        .accessibilityHidden(true)
    }
}
