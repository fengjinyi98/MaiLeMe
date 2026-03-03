//
//  ConfettiView.swift
//  MaiLeMe
//
//  Created by Codex on 2026/3/3.
//

import SwiftUI

/// 彩带动画发射器（稳定版）：避免依赖 onChange 时序导致真机不触发。
struct ConfettiView: View {
    @State private var animate = false
    @State private var seeds: [ConfettiSeed] = ConfettiSeed.generate(count: 56)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(seeds) { seed in
                    ConfettiParticle(seed: seed, canvasSize: geometry.size, animate: animate)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            // 重置并下一帧启动，确保每次出现都能稳定触发动画。
            animate = false
            seeds = ConfettiSeed.generate(count: 56)
            DispatchQueue.main.async {
                animate = true
            }
        }
    }
}

/// 单个彩带粒子的随机种子，动画时只读，不在运行中修改。
private struct ConfettiSeed: Identifiable {
    let id = UUID()
    let xTravel: CGFloat
    let yDropMultiplier: CGFloat
    let endRotation: Double
    let duration: Double
    let delay: Double
    let size: CGFloat
    let widthRatio: CGFloat
    let color: Color
    let shape: ShapeKind

    enum ShapeKind: Int, CaseIterable {
        case circle
        case rect
        case capsule
    }

    /// 生成一批随机粒子参数。
    static func generate(count: Int) -> [ConfettiSeed] {
        let palette: [Color] = [.red, .blue, .green, .yellow, .orange, .pink, .purple]
        return (0..<count).map { _ in
            ConfettiSeed(
                xTravel: .random(in: -360...360),
                yDropMultiplier: .random(in: 0.72...0.96),
                endRotation: .random(in: 420...1220),
                duration: .random(in: 1.35...2.45),
                delay: .random(in: 0...0.22),
                size: .random(in: 6...13),
                widthRatio: .random(in: 1.0...1.8),
                color: palette.randomElement() ?? .blue,
                shape: ShapeKind.allCases.randomElement() ?? .rect
            )
        }
    }
}

/// 彩带粒子视图。
private struct ConfettiParticle: View {
    let seed: ConfettiSeed
    let canvasSize: CGSize
    let animate: Bool

    private var startX: CGFloat { canvasSize.width / 2 }
    private var startY: CGFloat { max(32, canvasSize.height * 0.32) }
    private var endX: CGFloat { startX + seed.xTravel }
    private var endY: CGFloat { canvasSize.height * seed.yDropMultiplier + 120 }

    @ViewBuilder
    private var particleShape: some View {
        switch seed.shape {
        case .circle:
            Circle().fill(seed.color)
        case .rect:
            RoundedRectangle(cornerRadius: 2, style: .continuous).fill(seed.color)
        case .capsule:
            Capsule(style: .continuous).fill(seed.color)
        }
    }

    var body: some View {
        particleShape
            .frame(width: seed.size * seed.widthRatio, height: seed.size)
            .position(x: animate ? endX : startX, y: animate ? endY : startY)
            .rotationEffect(Angle(degrees: animate ? seed.endRotation : 0))
            .scaleEffect(animate ? 1 : 0.35)
            .opacity(animate ? 0 : 1)
            .animation(
                Animation.easeIn(duration: seed.duration).delay(seed.delay),
                value: animate
            )
    }
}

/*
 原版本实现保留注释说明：
 - 旧实现依赖 onChange 和初始化时 Geometry 尺寸，真机上偶发彩带不触发。
 - 当前实现改为“种子驱动 + 一次性布尔切换动画”，触发更稳定。
*/
