//
//  ItemImagePreviewScreen.swift
//  MaiLeMe
//
//  Created by Codex on 2026/3/3.
//

import SwiftUI
import UIKit

/// 图片大图预览页：用于详情页点击缩略图后的全屏查看。
struct ItemImagePreviewScreen: View {
    @Environment(\.dismiss) private var dismiss

    let imageData: Data
    let title: String

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    private var uiImage: UIImage? {
        UIImage(data: imageData)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .padding(20)
                    .scaleEffect(scale)
                    .gesture(magnificationGesture)
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            if scale > 1.02 {
                                scale = 1
                                lastScale = 1
                            } else {
                                scale = 2
                                lastScale = 2
                            }
                        }
                    }
            } else {
                Text("图片加载失败")
                    .foregroundStyle(Color.white.opacity(0.85))
            }

            VStack {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.white.opacity(0.92))
                        .lineLimit(1)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.white.opacity(0.9))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                Text("双击可缩放")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.65))
                    .padding(.bottom, 22)
            }
        }
    }

    /// 缩放手势：支持连续放大缩小并限制范围。
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), 4)
            }
            .onEnded { _ in
                lastScale = scale
            }
    }
}
