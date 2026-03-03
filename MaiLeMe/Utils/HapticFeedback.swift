//
//  HapticFeedback.swift
//  MaiLeMe
//
//  Created by Codex on 2026/3/3.
//

import UIKit
import AVFoundation

/// 触感反馈工具：统一管理关键操作的震动节奏。
enum HapticFeedback {
    private static let soundPlayer = CelebrationSoundPlayer()
    
    enum CelebrationStep {
        case cardEntry
        case iconBurst
        case textDrop
        case buttonReady
    }
    
    /// 多邻国风格：分步入场的触觉反馈编排
    static func playSequenceStep(step: CelebrationStep) {
        switch step {
        case .cardEntry:
            // 卡片升起时的轻微反馈
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.prepare()
            impact.impactOccurred(intensity: 0.5)
            
        case .iconBurst:
            // 撒花爆出时：强烈的成功震动 + 自定义短促音效
            let notification = UINotificationFeedbackGenerator()
            notification.prepare()
            notification.notificationOccurred(.success)
            soundPlayer.play()
            
        case .textDrop:
            // 文字落下时：软软的提示
            let impact = UIImpactFeedbackGenerator(style: .soft)
            impact.prepare()
            impact.impactOccurred(intensity: 0.7)
            
        case .buttonReady:
            // 最后的 3D 按钮就位：清脆的震动
            let impact = UIImpactFeedbackGenerator(style: .rigid)
            impact.prepare()
            impact.impactOccurred(intensity: 0.8)
        }
    }
    
    /// 3D 按钮被点击时的重物理反馈
    static func buttonTap() {
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.prepare()
        // 模拟按键按下去的阻尼感
        impact.impactOccurred(intensity: 1.0)
    }

    /// 冷静期决策成功反馈：两条路径都提供强烈确认感。
    static func decisionCompleted(isSaved: Bool) {
        let notification = UINotificationFeedbackGenerator()
        notification.prepare()
        notification.notificationOccurred(.success)

        let impact = UIImpactFeedbackGenerator(style: isSaved ? .heavy : .rigid)
        impact.prepare()
        impact.impactOccurred(intensity: isSaved ? 0.95 : 1.0)
        soundPlayer.play()
    }
}

/// 轻量成功音播放器：通过 AVAudioPlayer 播放内置合成的短促 chime 音。
private final class CelebrationSoundPlayer {
    private var audioPlayer: AVAudioPlayer?
    private var sessionPrepared = false

    /// 播放一次成功音效。
    func play() {
        do {
            try prepareSessionIfNeeded()
            if audioPlayer == nil {
                let data = Self.makeChimeWAVData()
                let player = try AVAudioPlayer(data: data)
                player.volume = 0.86
                player.prepareToPlay()
                audioPlayer = player
            }
            audioPlayer?.currentTime = 0
            audioPlayer?.play()
        } catch {
            #if DEBUG
            print("音效播放失败：\(error.localizedDescription)")
            #endif
        }
    }

    /// 首次播放前初始化音频会话。
    private func prepareSessionIfNeeded() throws {
        guard !sessionPrepared else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, options: [.mixWithOthers])
        try session.setActive(true)
        sessionPrepared = true
    }

    /// 动态生成短促“成功提示音”WAV 数据。
    private static func makeChimeWAVData() -> Data {
        let sampleRate: Double = 44_100
        let duration: Double = 0.18
        let sampleCount = Int(sampleRate * duration)
        var pcmData = Data(capacity: sampleCount * 2)

        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate
            let envelope = exp(-10.5 * t)
            let waveA = sin(2 * Double.pi * 1046.5 * t)      // C6
            let waveB = sin(2 * Double.pi * 1568.0 * t) * 0.4 // G6
            let mixed = (waveA + waveB) * 0.5 * envelope
            let scaled = max(-1.0, min(1.0, mixed)) * 0.8
            let sample = Int16(scaled * Double(Int16.max))
            var littleEndian = sample.littleEndian
            withUnsafeBytes(of: &littleEndian) { raw in
                pcmData.append(contentsOf: raw)
            }
        }

        return makeWAVFileData(
            pcmData: pcmData,
            sampleRate: UInt32(sampleRate),
            channels: 1,
            bitsPerSample: 16
        )
    }

    /// 组装标准 PCM WAV 文件头。
    private static func makeWAVFileData(
        pcmData: Data,
        sampleRate: UInt32,
        channels: UInt16,
        bitsPerSample: UInt16
    ) -> Data {
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let subchunk2Size = UInt32(pcmData.count)
        let chunkSize = 36 + subchunk2Size

        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        data.appendUInt32LE(chunkSize)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        data.appendUInt32LE(16)
        data.appendUInt16LE(1) // PCM
        data.appendUInt16LE(channels)
        data.appendUInt32LE(sampleRate)
        data.appendUInt32LE(byteRate)
        data.appendUInt16LE(blockAlign)
        data.appendUInt16LE(bitsPerSample)
        data.append(contentsOf: Array("data".utf8))
        data.appendUInt32LE(subchunk2Size)
        data.append(pcmData)
        return data
    }
}

private extension Data {
    mutating func appendUInt16LE(_ value: UInt16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { raw in
            append(contentsOf: raw)
        }
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { raw in
            append(contentsOf: raw)
        }
    }
}
