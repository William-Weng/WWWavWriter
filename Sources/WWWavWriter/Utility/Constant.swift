//
//  File.swift
//  WWWavWriter
//
//  Created by iOS on 2026/4/7.
//

import Foundation

// MARK: - 常數值
extension WWWavWriter {
    
    enum Constants {
        static let waveFormatExtensible: UInt16 = 0xFFFE    // [WAVE_FORMAT_EXTENSIBLE](https://blog.csdn.net/wenluderen/article/details/123015084)
    }
}

// MARK: - 常數值
public extension WWWavWriter {
    
    /// 音訊格式 (整數PCM / IEEE浮點)
    enum AudioFormat: UInt16, Sendable {
        case pcmInteger = 0x0001    // WAVE_FORMAT_PCM
        case ieeeFloat  = 0x0003    // WAVE_FORMAT_IEEE_FLOAT
    }
    
    /// 表示要封裝成哪一種 WAVE 檔案類型
    enum WavType {
        case PCM16(_ pcmData: Data)     // 16 位整數 PCM WAV（bitsPerSample = 16, audioFormat = .pcmInteger）
        case Float32(_ pcmData: Data)   // 32 位 IEEE 浮點 WAV（bitsPerSample = 32, audioFormat = .ieeeFloat）
    }
    
    /// 表示要封裝成哪一種 WAVE 檔案類型 (方便Swift處理)
    enum SamplesType {
        case PCM16(_ samples: [Int16])      // 16 位整數 PCM WAV（bitsPerSample = 16, audioFormat = .pcmInteger）
        case Float32(_ samples: [Float32])  // 32 位 IEEE 浮點 WAV（bitsPerSample = 32, audioFormat = .ieeeFloat）
    }
    
    /// 自定義錯誤
    enum CustomError: Error, Sendable {
        case emptyAudioData         // 沒有音訊資料，傳入的音訊 Buffer / Data 為空
        case invalidSampleRate      // 取樣率（sample rate）不合法，例如 0 或超出合理範圍
        case invalidChannelCount    // 聲道數量不合法，例如 0 或超出格式允許的最大聲道數
        case invalidBitsPerSample   // 每樣本位數（bitsPerSample）不合法，不符合該格式允許的位數（例如 4、99 等）
        case invalidDataAlignment   // 音訊資料對齊不正確，例如大小不符合 frame size 的整數倍，或未對齊到指定位元組邊界
        case integerOverflow        // 整數運算溢出，例如在計算位元率、資料長度時發生 overflow
    }
}
