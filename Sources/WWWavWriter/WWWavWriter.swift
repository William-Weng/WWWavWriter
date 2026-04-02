import Foundation

public enum WWWavWriter {

    // MARK: - Public Types

    public enum AudioFormat: UInt16, Sendable {
        case pcmInteger = 0x0001
        case ieeeFloat  = 0x0003
    }

    public enum WriterError: Error, Sendable {
        case emptyAudioData
        case invalidSampleRate
        case invalidChannelCount
        case invalidBitsPerSample
        case invalidDataAlignment
        case integerOverflow
    }

    public struct Config: Sendable {
        public let sampleRate: UInt32
        public let channels: UInt16
        public let bitsPerSample: UInt16
        public let audioFormat: AudioFormat
        public let channelMask: UInt32?

        public init(
            sampleRate: UInt32,
            channels: UInt16,
            bitsPerSample: UInt16,
            audioFormat: AudioFormat,
            channelMask: UInt32? = nil
        ) {
            self.sampleRate = sampleRate
            self.channels = channels
            self.bitsPerSample = bitsPerSample
            self.audioFormat = audioFormat
            self.channelMask = channelMask
        }
    }

    // MARK: - Public API

    public static func makeWavData(audioData: Data, config: Config) throws -> Data {
        guard !audioData.isEmpty else { throw WriterError.emptyAudioData }
        guard config.sampleRate > 0 else { throw WriterError.invalidSampleRate }
        guard config.channels > 0 else { throw WriterError.invalidChannelCount }
        guard isValid(bitsPerSample: config.bitsPerSample, for: config.audioFormat) else {
            throw WriterError.invalidBitsPerSample
        }
        guard config.bitsPerSample % 8 == 0 else {
            throw WriterError.invalidBitsPerSample
        }

        let bytesPerSample = UInt32(config.bitsPerSample / 8)
        let blockAlign32 = UInt32(config.channels) * bytesPerSample

        guard blockAlign32 > 0, blockAlign32 <= UInt32(UInt16.max) else {
            throw WriterError.integerOverflow
        }
        guard audioData.count % Int(blockAlign32) == 0 else {
            throw WriterError.invalidDataAlignment
        }

        let byteRate64 = UInt64(config.sampleRate) * UInt64(blockAlign32)
        guard byteRate64 <= UInt64(UInt32.max) else {
            throw WriterError.integerOverflow
        }

        let useExtensible = shouldUseExtensible(config: config)
        let fmtChunkSize: UInt32 = useExtensible ? 40 : 16
        let totalSize64 = UInt64(12 + 8) + UInt64(fmtChunkSize) + UInt64(8) + UInt64(audioData.count)

        guard totalSize64 <= UInt64(UInt32.max) + 8 else {
            throw WriterError.integerOverflow
        }
        guard audioData.count <= Int(UInt32.max) else {
            throw WriterError.integerOverflow
        }

        let riffChunkSize = UInt32(totalSize64 - 8)
        let dataSize = UInt32(audioData.count)
        let byteRate = UInt32(byteRate64)
        let blockAlign = UInt16(blockAlign32)

        var out = Data(capacity: Int(totalSize64))

        out.appendASCII("RIFF")
        out.appendLE(riffChunkSize)
        out.appendASCII("WAVE")

        out.appendASCII("fmt ")
        out.appendLE(fmtChunkSize)

        if useExtensible {
            let resolvedMask = config.channelMask ?? defaultChannelMask(for: config.channels)

            out.appendLE(Constants.waveFormatExtensible)
            out.appendLE(config.channels)
            out.appendLE(config.sampleRate)
            out.appendLE(byteRate)
            out.appendLE(blockAlign)
            out.appendLE(config.bitsPerSample)

            out.appendLE(UInt16(22))
            out.appendLE(config.bitsPerSample)
            out.appendLE(resolvedMask)
            out.append(waveSubFormatGUID(for: config.audioFormat))
        } else {
            out.appendLE(config.audioFormat.rawValue)
            out.appendLE(config.channels)
            out.appendLE(config.sampleRate)
            out.appendLE(byteRate)
            out.appendLE(blockAlign)
            out.appendLE(config.bitsPerSample)
        }

        out.appendASCII("data")
        out.appendLE(dataSize)
        out.append(audioData)

        return out
    }

    public static func writeWavFile(audioData: Data, config: Config, to url: URL) throws {
        let wavData = try makeWavData(audioData: audioData, config: config)
        try wavData.write(to: url, options: .atomic)
    }

    public static func makePCM16WavData(
        pcmData: Data,
        sampleRate: UInt32,
        channels: UInt16
    ) throws -> Data {
        let config = Config(
            sampleRate: sampleRate,
            channels: channels,
            bitsPerSample: 16,
            audioFormat: .pcmInteger
        )
        return try makeWavData(audioData: pcmData, config: config)
    }

    public static func makeFloat32WavData(
        pcmData: Data,
        sampleRate: UInt32,
        channels: UInt16
    ) throws -> Data {
        let config = Config(
            sampleRate: sampleRate,
            channels: channels,
            bitsPerSample: 32,
            audioFormat: .ieeeFloat
        )
        return try makeWavData(audioData: pcmData, config: config)
    }

    public static func makePCM16WavData(
        samples: [Int16],
        sampleRate: UInt32,
        channels: UInt16
    ) throws -> Data {
        try makePCM16WavData(
            pcmData: dataFromInt16Samples(samples),
            sampleRate: sampleRate,
            channels: channels
        )
    }

    public static func writePCM16WavFile(
        samples: [Int16],
        sampleRate: UInt32,
        channels: UInt16,
        to url: URL
    ) throws {
        let wav = try makePCM16WavData(
            samples: samples,
            sampleRate: sampleRate,
            channels: channels
        )
        try wav.write(to: url, options: .atomic)
    }

    public static func dataFromUInt8Samples(_ samples: [UInt8]) -> Data {
        Data(samples)
    }

    public static func dataFromInt16Samples(_ samples: [Int16]) -> Data {
        var little = samples.map(\.littleEndian)
        return little.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    public static func dataFromInt32Samples(_ samples: [Int32]) -> Data {
        var little = samples.map(\.littleEndian)
        return little.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    public static func dataFromFloat32Samples(_ samples: [Float]) -> Data {
        samples.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    public static func dataFromFloat64Samples(_ samples: [Double]) -> Data {
        samples.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    public static func dataFrom24BitPCMBytes(_ bytes: [UInt8]) -> Data {
        Data(bytes)
    }
}

// MARK: - Private Helpers

private extension WWWavWriter {

    enum Constants {
        static let waveFormatExtensible: UInt16 = 0xFFFE
    }

    static func isValid(bitsPerSample: UInt16, for format: AudioFormat) -> Bool {
        switch format {
        case .pcmInteger:
            return [8, 16, 24, 32].contains(bitsPerSample)
        case .ieeeFloat:
            return [32, 64].contains(bitsPerSample)
        }
    }

    static func shouldUseExtensible(config: Config) -> Bool {
        if config.channels > 2 { return true }
        if config.audioFormat == .pcmInteger && config.bitsPerSample > 16 { return true }
        if config.audioFormat == .ieeeFloat && config.bitsPerSample > 32 { return true }
        return false
    }

    static func defaultChannelMask(for channels: UInt16) -> UInt32 {
        switch channels {
        case 1: return 0x00000004
        case 2: return 0x00000003
        case 3: return 0x00000007
        case 4: return 0x00000107
        case 5: return 0x00000037
        case 6: return 0x0000003F
        case 7: return 0x0000007F
        case 8: return 0x0000063F
        default: return 0
        }
    }

    static func waveSubFormatGUID(for format: AudioFormat) -> Data {
        var data = Data()
        data.appendLE(format.rawValue)
        data.appendLE(UInt16(0x0000))
        data.appendLE(UInt16(0x0010))
        data.append(contentsOf: [0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71, 0x00, 0x00])
        return data
    }
}

// MARK: - Data Helpers

private extension Data {

    mutating func appendASCII(_ string: String) {
        append(contentsOf: string.utf8)
    }

    mutating func appendLE(_ value: UInt16) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }

    mutating func appendLE(_ value: UInt32) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }
}
