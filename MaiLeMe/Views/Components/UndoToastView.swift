//
//  UndoToastView.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import SwiftUI

/// 删除后的底部撤销提示条。
struct UndoToastView: View {
    let title: String
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash.fill")
                .foregroundStyle(AppTheme.Palette.warning)

            Text(title)
                .font(.subheadline)
                .lineLimit(2)
                .foregroundStyle(AppTheme.Palette.primaryText)

            Spacer(minLength: 0)

            Button("撤销") {
                onUndo()
            }
            .buttonStyle(SolidActionButtonStyle(tint: AppTheme.Palette.cooling))

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.Palette.secondaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.95),
                            Color.white.opacity(0.88)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.Palette.cardStroke, lineWidth: 1)
        )
        .shadow(color: AppTheme.Palette.cardShadow, radius: 14, x: 0, y: 8)
        .padding(.horizontal, 16)
    }
}
