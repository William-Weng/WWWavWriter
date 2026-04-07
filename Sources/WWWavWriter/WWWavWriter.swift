//
//  WWWavWriter.swift
//  WWWavWriter
//
//  Created by William.Weng on 2026/4/7.
//

import Foundation

// MARK: - PCM to Wav
public enum WWWavWriter {}

// MARK: - 公開函式
public extension WWWavWriter {
    
    /// 把純 PCM 資料包裹成「一個完整、可用、標準的 WAV 檔案內容」
    /// - Parameters:
    ///   - audioData: 音訊資料
    ///   - config: 相關設定值
    /// - Returns: Data
    static func makeData(audioData: Data, config: Config) throws -> Data {
        
        let dataSize = UInt32(audioData.count)
        let blockAlign32 = try blockAlign32Size(with: audioData, config: config)
        let byteRate64 = try byteRate64Size(with: blockAlign32, config: config)
        let useExtensible = shouldUseExtensible(config: config)
        let fmtChunkSize: UInt32 = useExtensible ? 40 : 16
        let totalSize64 = try totalSize64Size(audioData: audioData, fmtChunkSize: fmtChunkSize)
        
        var wavData = combineWavData(audioData: audioData, config: config, useExtensible: useExtensible, totalSize64: totalSize64, fmtChunkSize: fmtChunkSize, byteRate64: byteRate64, blockAlign32: blockAlign32)
        wavData.appendASCII("data")
        wavData.appendLE(dataSize)
        wavData.append(audioData)
        
        return wavData
    }
    
    /// 根據 WavType，把 raw PCM 位元組資料封裝成對應格式的 WAVE 檔案內容（用來統一呼叫 PCM16 / Float32 的封裝邏輯，避免在上層用 if/switch 直接呼叫不同函式）
    /// - Parameters:
    ///   - wavType: 要封裝的 WAV 格式（PCM16(Data) 或 Float32(Data)）
    ///   - sampleRate: 音訊取樣率
    ///   - channels: 聲道數量
    /// - Returns: 一個標準 WAVE 格式的 Data，可直接寫成 .wav 或傳給音訊 API
    static func makeData(wavType: WavType, sampleRate: UInt32, channels: UInt16) throws -> Data {
        switch wavType {
        case .PCM16(let pcmData): return try makePCM16WavData(pcmData: pcmData, sampleRate: sampleRate, channels: channels)
        case .Float32(let pcmData): return try makeFloat32WavData(pcmData: pcmData, sampleRate: sampleRate, channels: channels)
        }
    }
    
    /// 根據 SamplesType，動態選擇樣本格式與 WAV 封裝方式
    /// 用一個 enum 來同時包含「PCM16」與「Float32」樣本陣列，避免在呼叫端用泛型 T
    /// - Parameters:
    ///   - samplesType: 包含樣本陣列與類型的 SamplesType（例如 .PCM16([Int16])、.Float32([Float32])）
    ///   - sampleRate: 音訊取樣率
    ///   - channels: 聲道數量
    /// - Returns: 一個對應格式的 WAVE 檔案 Data，可直接寫成 .wav 或交給 API
    static func makeData(samplesType: SamplesType, sampleRate: UInt32, channels: UInt16) throws -> Data {
        switch samplesType {
        case .PCM16(let samples): return try makePCM16WavData(samples: samples, sampleRate: sampleRate, channels: channels)     // 輸入是 [Int16]，封裝成 16 位整數 PCM WAV
        case .Float32(let samples): return try makeFloat32WavData(samples: samples, sampleRate: sampleRate, channels: channels) // 輸入是 [Float32]，封裝成 32 位 IEEE 浮點 WAV
        }
    }
}

// MARK: - 小工具
private extension WWWavWriter {
    
    /// 取樣值的合法性檢查
    /// - Parameters:
    ///   - bitsPerSample: UInt16
    ///   - format: AudioFormat
    /// - Returns: Bool
    static func isValid(bitsPerSample: UInt16, for format: AudioFormat) -> Bool {
        switch format {
        case .pcmInteger: return [8, 16, 24, 32].contains(bitsPerSample)
        case .ieeeFloat: return [32, 64].contains(bitsPerSample)
        }
    }
    
    /// 當 聲道數 > 2 / PCM 位數 > 16 / IEEE 浮點位數 > 32 時，就改用 WAVEFORMAT_EXTENSIBLE（WAVEFORMATEXTENSIBLE），否則用舊的標準格式
    /// - Parameter config: Config
    /// - Returns: Bool
    static func shouldUseExtensible(config: Config) -> Bool {
        
        if (config.channels > 2) { return true }
        if (config.audioFormat == .pcmInteger) && (config.bitsPerSample > 16) { return true }
        if (config.audioFormat == .ieeeFloat) && (config.bitsPerSample > 32) { return true }
        
        return false
    }
    
    /// 計算 WAV / 音訊的 block size（每個 frame 的位元組數，即 blockAlign），用於計算 AvgBytesPerSec、資料長度對齊判斷等
    /// - Parameters:
    ///   - audioData: 音訊資料本體
    ///   - config: 音訊格式設定
    /// - Returns: blockAlign 的 UInt32 值
    static func blockAlign32Size(with audioData: Data, config: Config) throws -> UInt32 {
        
        // 1. 先用 checkWavData 做完整的合法性檢查
        if let error = checkWavData(with: audioData, config: config) { throw error }
        
        // 2. 計算「每樣本」佔幾個位元組
        let bytesPerSample = UInt32(config.bitsPerSample / 8)
        
        // 3. 計算 blockAlign：每個 frame 的位元組數
        let blockAlign32 = UInt32(config.channels) * bytesPerSample
        
        // 4. 保證結果在 UInt16 範圍內（WAV 規範常以 16 bit 為上限）
        guard blockAlign32 > 0, blockAlign32 <= UInt32(UInt16.max) else { throw CustomError.integerOverflow }
        
        // 5. 檢查資料總長度是否為 blockAlign 的整數倍（對齊錯誤）
        guard audioData.count % Int(blockAlign32) == 0 else { throw CustomError.invalidDataAlignment }
        
        return blockAlign32
    }
    
    /// 用已經打好包的 PCM 16‑bit 位元組資料，直接組成標準 16 位整數 PCM WAV 檔案（例如：你已經拿到 Int16 的 raw Data）
    /// - Parameters:
    ///   - pcmData: Int16 格式的 raw PCM 位元組資料（每樣本 2 bytes）
    ///   - sampleRate: 取樣率（例如 44100、48000 Hz）
    ///   - channels: 聲道數量（1: mono, 2: stereo 等）
    /// - Returns: 一個標準 WAVE 格式的 Data（可直接寫成 .wav）
    static func makePCM16WavData(pcmData: Data, sampleRate: UInt32, channels: UInt16) throws -> Data {
        let config = Config(sampleRate: sampleRate, channels: channels, bitsPerSample: 16, audioFormat: .pcmInteger)
        return try makeData(audioData: pcmData, config: config)
    }
    
    /// 用已經打好包的 IEEE 32‑bit 浮點 PCM 資料，組成標準 32 位浮點 WAV 檔案（例如：你已經拿到 Float32 的 raw Data）
    /// - Parameters:
    ///   - pcmData: Float32 格式的 raw PCM 位元組資料（每樣本 4 bytes）
    ///   - sampleRate: 取樣率（例如 44100、48000 Hz）
    ///   - channels: 聲道數量
    /// - Returns: 一個 32 位浮點 WAV 檔案的 Data（含 WAVE header）
    static func makeFloat32WavData(pcmData: Data, sampleRate: UInt32, channels: UInt16) throws -> Data {
        let config = Config(sampleRate: sampleRate, channels: channels, bitsPerSample: 32, audioFormat: .ieeeFloat)
        return try makeData(audioData: pcmData, config: config)
    }
    
    /// 用 [Int16] 陣列直接生成標準 16 位整數 PCM WAV 檔案（方便從 Swift 原生整數陣列轉成 wav）
    /// - Parameters:
    ///   - samples: Int16 格式的音訊樣本陣列
    ///   - sampleRate: 取樣率
    ///   - channels: 聲道數量
    /// - Returns: 一個 WAVE 格式的 Data（可直接寫成 .wav 或傳給其他 API）
    static func makePCM16WavData(samples: [Int16], sampleRate: UInt32, channels: UInt16) throws -> Data {
        let pcmData = samples.samplesData()                                                         // 1. 把 [Int16] 陣列轉成 raw PCM 位元組資料（每 Int16 用 2 bytes）
        return try makePCM16WavData(pcmData: pcmData, sampleRate: sampleRate, channels: channels)   // 2. 呼叫上一層，用 Raw Data 來產生 WAVE
    }
    
    /// 用 [Float32] 陣列直接生成標準 32 位浮點 WAV 檔案（方便從 Swift 原生浮點陣列轉成 wav）
    /// - Parameters:
    ///   - samples: Float32（Float）格式的音訊樣本陣列，範圍通常是 -1.0 ~ 1.0
    ///   - sampleRate: 取樣率（例如 44100、48000 Hz）
    ///   - channels: 聲道數量（1: mono, 2: stereo 等）
    /// - Returns: 一個 32 位浮點 WAVE 格式的 Data（可直接寫成 .wav 或傳給其他 API）
    static func makeFloat32WavData(samples: [Float32], sampleRate: UInt32, channels: UInt16) throws -> Data {
        let pcmData = samples.samplesData()                                                             // 1. 把 [Float32] 陣列轉成 raw PCM 位元組資料（每 Float32 用 4 bytes）
        return try makeFloat32WavData(pcmData: pcmData, sampleRate: sampleRate, channels: channels)   // 2. 呼叫上一層，用 Raw Data 來產生 WAVE
    }
    
    /// 計算 WAV 標準的 AvgBytesPerSec（每秒位元組數，即 byteRate），公式：byteRate = sampleRate × blockAlign，用於 fmt chunk 裡的 AvgBytesPerSec / byteRate 欄位
    /// - Parameters:
    ///   - blockAlign32: 一個 frame 的位元組數（channels × bytesPerSample）
    ///   - config: 音訊格式設定（包含 sampleRate）
    /// - Returns: AvgBytesPerSec（UInt64 精度，再被截成 UInt32 寫入 header）
    static func byteRate64Size(with blockAlign32: UInt32, config: Config) throws -> UInt64 {
        let byteRate64 = UInt64(config.sampleRate) * UInt64(blockAlign32)
        guard byteRate64 <= UInt64(UInt32.max) else { throw CustomError.integerOverflow }
        return byteRate64
    }
    
    /// 計算 WAV 檔案的 RIFF chunk size（對應 RIFF header 裡的 36 位元組之後的所有資料長度），也就是：文件總長 - 8 = RIFF chunkSize，這裡用 UInt64 先算出總長，再檢查是否會超過 UInt32 表示範圍
    /// - Parameters:
    ///   - audioData: data chunk 的實際音訊資料
    ///   - fmtChunkSize: fmt chunk 的大小（通常 16, 18, 40 等）
    /// - Returns: RIFF chunk size（UInt64，寫入 header 時再轉成 UInt32）
    static func totalSize64Size(audioData: Data, fmtChunkSize: UInt32) throws -> UInt64 {
        let totalSize64 = UInt64(12 + 8) + UInt64(fmtChunkSize) + UInt64(8) + UInt64(audioData.count)
        guard totalSize64 <= UInt64(UInt32.max) + 8 else { throw CustomError.integerOverflow }
        return totalSize64
    }
    
    /// 初步檢查音訊的資訊與設定參數有沒有問題
    /// - Parameters:
    ///   - audioData: 音訊資料本體（例如從 PCM Buffer 或 raw Data 來的）
    ///   - config: 音訊格式設定（取樣率、聲道、位數等）
    /// - Returns: 如果有錯，回傳 CustomError；沒錯則回傳 nil
    static func checkWavData(with audioData: Data, config: Config) -> CustomError? {
        
        guard !audioData.isEmpty else { return CustomError.emptyAudioData }
        guard audioData.count <= Int(UInt32.max) else { return CustomError.integerOverflow }
        guard config.sampleRate > 0 else { return CustomError.invalidSampleRate }
        guard config.channels > 0 else { return CustomError.invalidChannelCount }
        guard config.bitsPerSample % 8 == 0 else { return CustomError.invalidBitsPerSample }
        guard isValid(bitsPerSample: config.bitsPerSample, for: config.audioFormat) else { return CustomError.invalidBitsPerSample }
        
        return nil
    }
    
    /// 負責組合 WAVE header + fmt chunk 的資料（不含 data chunk）
    /// - Parameters:
    ///   - audioData: Data
    ///   - config: Config
    ///   - useExtensible: Bool
    ///   - totalSize64: UInt64
    ///   - fmtChunkSize: UInt32
    ///   - byteRate64: UInt64
    ///   - blockAlign32: UInt32
    /// - Returns: Data
    static func combineWavData(audioData: Data, config: Config, useExtensible: Bool, totalSize64: UInt64, fmtChunkSize: UInt32, byteRate64: UInt64, blockAlign32: UInt32) -> Data {
        
        let riffChunkSize = UInt32(totalSize64 - 8)
        let dataSize = UInt32(audioData.count)
        let byteRate = UInt32(byteRate64)
        let blockAlign = UInt16(blockAlign32)
        
        var wavData = Data(capacity: Int(totalSize64))
        
        wavData.appendASCII("RIFF")
        wavData.appendLE(riffChunkSize)
        wavData.appendASCII("WAVE")
        wavData.appendASCII("fmt ")
        wavData.appendLE(fmtChunkSize)
        
        if (useExtensible) {
            
            let resolvedMask = config.channelMask ?? defaultChannelMask(for: config.channels)
                                                                        // WAVEFORMATEXTENSIBLE 的前半段（WAVEFORMAT 擴展版通用欄位）
            wavData.appendLE(Constants.waveFormatExtensible)            // wFormatTag = WAVE_FORMAT_EXTENSIBLE
            wavData.appendLE(config.channels)                           // nChannels
            wavData.appendLE(config.sampleRate)                         // nSamplesPerSec
            wavData.appendLE(byteRate)                                  // nAvgBytesPerSec
            wavData.appendLE(blockAlign)                                // nBlockAlign
            wavData.appendLE(config.bitsPerSample)                      // wBitsPerSample
                                                                        // 額外欄位：cbSize + bitsPerSample（作為 EffectiveBitsPerSample？）
            wavData.appendLE(UInt16(22))                                // cbSize: WAVEFORMATEXTENSIBLE 預期 extra 22 位元組
            wavData.appendLE(config.bitsPerSample)                      // TBD：實際要看你在那裡是 EffectiveBitsPerSample 還是別的
            wavData.appendLE(resolvedMask)                              // dwChannelMask
            
            wavData.append(waveSubFormatGUID(for: config.audioFormat))  // GUID SubFormat
            
            return wavData
        }
        
        wavData.appendLE(config.audioFormat.rawValue)                   // wFormatTag (PCM / IEEE Float)
        wavData.appendLE(config.channels)
        wavData.appendLE(config.sampleRate)
        wavData.appendLE(byteRate)
        wavData.appendLE(blockAlign)
        wavData.appendLE(config.bitsPerSample)
        
        return wavData
    }
    
    /// [預設聲道的編號轉換 (單聲道 / 立體聲)](https://musictech.tw/history-of-stereo-961d54426b14)
    /// - Parameter channels: UInt16
    /// - Returns: UInt32
    static func defaultChannelMask(for channels: UInt16) -> UInt32 {
        
        switch channels {
        case 1: return 0x00000004   // FC（中央 / 單聲道)
        case 2: return 0x00000003   // FL + FR（左前 + 右前 / 立體聲）
        case 3: return 0x00000007   // FL + FR + FC（左前 + 右前 + 中央）
        case 4: return 0x00000107   // FL + FR + FC + BC（左前 + 右前 + 中央 + 後中）
        case 5: return 0x00000037   // FL + FR + FC + BL + BR（左前 + 右前 + 中央 + 左後環繞 + 右後環繞）
        case 6: return 0x0000003F   // FL + FR + FC + LFE + BL + BR（5.1 標準）
        case 7: return 0x0000007F   // FL + FR + FC + LFE + BL + BR + BC（5.1 + 後中）
        case 8: return 0x0000063F   // FL + FR + FC + LFE + BL + BR + SL + SR（7.1 標準）
        default: return 0
        }
    }
    
    /// AudioFormat定義的音訊格式 => Windows / WAV 規範的 SubFormat GUID 二進位資料 (0000-0010-8000-00aa00389b71)
    /// - Parameter format: AudioFormat
    /// - Returns: Data
    static func waveSubFormatGUID(for format: AudioFormat) -> Data {
        
        var data = Data()
        
        data.appendLE(format.rawValue)
        data.appendLE(UInt16(0x0000))
        data.appendLE(UInt16(0x0010))
        data.append(contentsOf: [0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71, 0x00, 0x00])
        
        return data
    }
}
