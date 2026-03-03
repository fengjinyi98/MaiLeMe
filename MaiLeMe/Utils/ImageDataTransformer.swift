//
//  ImageDataTransformer.swift
//  MaiLeMe
//
//  Created by Codex on 2026/3/3.
//

import Foundation
import UIKit

/// 图片数据转换器：统一负责缩放与压缩策略，避免原图直接入库导致体积过大。
enum ImageDataTransformer {
    /// 将原始图片数据标准化为适合本地存储的 JPEG 数据。
    static func normalizedJPEGData(
        from rawData: Data,
        maxDimension: CGFloat = 1280,
        preferredCompressionQuality: CGFloat = 0.82,
        fallbackCompressionQuality: CGFloat = 0.68,
        preferredMaxBytes: Int = 2_500_000
    ) -> Data? {
        guard let image = UIImage(data: rawData) else {
            return nil
        }

        let resized = image.scaledToFit(maxDimension: maxDimension)
        if let preferred = resized.jpegData(compressionQuality: preferredCompressionQuality),
           preferred.count <= preferredMaxBytes {
            return preferred
        }
        return resized.jpegData(compressionQuality: fallbackCompressionQuality)
    }
}

private extension UIImage {
    /// 按最长边等比缩放，控制存储开销并提升列表渲染性能。
    func scaledToFit(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension, maxDimension > 0 else {
            return self
        }

        let scale = maxDimension / longestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
