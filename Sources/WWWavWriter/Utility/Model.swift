//
//  Model.swift
//  WWWavWriter
//
//  Created by William.Weng on 2026/4/7.
//

import Foundation

// MARK: - 模型
public extension WWWavWriter {
    
    /// 音訊相關設定
    struct Config: Sendable {
        
        let sampleRate:    UInt32
        let channels:      UInt16
        let bitsPerSample: UInt16
        let audioFormat:   AudioFormat
        let channelMask:   UInt32?
        
        /// 初始化
        /// - Parameters:
        ///   - sampleRate: 音訊取樣頻率（例如 44100、48000 Hz）
        ///   - channels: 聲道數量（例如 1、2、5、6、7、8 等）
        ///   - bitsPerSample: 每樣本位數，例如 8/16/24/32 (PCM)、32/64 (IEEE Float)
        ///   - audioFormat: 音訊資料格式：pcmInteger 或 ieeeFloat
        ///   - channelMask: 聲道配置遮罩（例如 5.1 / 7.1 mask，可為 nil 表示不特別指定)
        public init(sampleRate: UInt32, channels: UInt16, bitsPerSample: UInt16, audioFormat: AudioFormat, channelMask: UInt32? = nil) {
            self.sampleRate = sampleRate
            self.channels = channels
            self.bitsPerSample = bitsPerSample
            self.audioFormat = audioFormat
            self.channelMask = channelMask
        }
    }
}
