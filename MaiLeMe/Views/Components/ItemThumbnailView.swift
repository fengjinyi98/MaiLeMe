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
    var cornerRadius: CGFloat = 12
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
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .foregroundStyle(AppTheme.Palette.tertiaryText)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(AppTheme.Palette.cardStroke, lineWidth: 0.8)
        )
        .accessibilityHidden(true)
    }
}
