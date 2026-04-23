# WWWavWriter

[![Swift-5.7](https://img.shields.io/badge/Swift-5.7-orange.svg?style=flat)](https://developer.apple.com/swift/) [![iOS-16.0](https://img.shields.io/badge/iOS-16.0-pink.svg?style=flat)](https://developer.apple.com/swift/) ![TAG](https://img.shields.io/github/v/tag/William-Weng/WWWavWriter) [![Swift Package Manager-SUCCESS](https://img.shields.io/badge/Swift_Package_Manager-SUCCESS-blue.svg?style=flat)](https://developer.apple.com/swift/) [![LICENSE](https://img.shields.io/badge/LICENSE-MIT-yellow.svg?style=flat)](https://developer.apple.com/swift/)

### [Introduction](https://swiftpackageindex.com/William-Weng)
> [A lightweight Swift Package for wrapping raw PCM or float audio data into WAV files.](https://www.youtube.com/watch?v=wn71QBApCRg)
> 一個簡單的PCM轉WAV的小工具。

## [Features](https://zonble.github.io/understanding_audio_files/pcm/)

- Pure Swift + Foundation
- Supports PCM integer: 8 / 16 / 24 / 32-bit
- Supports IEEE float: 32 / 64-bit
- Supports mono, stereo, and multichannel
- Automatically uses WAVE_FORMAT_EXTENSIBLE when needed
- Stateless API, suitable for concurrent use

## Installation

### Swift Package Manager

```swift
.package(url: "https://github.com/William-Weng/WWWavWriter.git", from: "1.1.0")
```

## API

### Function

|Function|Description|
|-|-|
|makeData(audioData:config:)|Takes raw PCM audio data and a configuration (sampleRate, channels, bitsPerSample, audioFormat, optional channelMask) and encapsulates them into a complete, standard WAVE file content Data. Internally, it calculates blockAlign, byteRate, decides whether to use WAVEFORMAT or WAVEFORMATEXTENSIBLE, and returns a Data that can be written directly as a .wav file.|
|makeData(wavType:sampleRate:channels:)|Construct WAV content from PCM audio data based on a given WavType (e.g. .PCM16, .Float32), sample rate, and number of channels. This function delegates to lower‑level makePCM16WavData / makeFloat32WavData, providing a unified entry point where the WAV format is chosen dynamically at runtime.|
|makeData(samplesType:sampleRate:channels:)|Construct WAV content from sample data wrapped in a SamplesType (e.g. .PCM16([Int16]), .Float32([Float]), .Float64([Double])). Using the associated sample array and its type, it calls the corresponding makePCM16WavData / makeFloat32WavData / makeFloat64WavData internally, so that one function can handle multiple numeric types and WAV formats.|

## Usage

### Int16 PCM samples to WAV

```swift
import WWWavWriter

let samples: [Int16] = [0, 1000, -1000, 2000, -2000, 0]
let wavData = try WWWavWriter.makeData(samplesType: .PCM16(samples), sampleRate: 16_000, channels: 1)
```

### Float32 samples to WAV

```swift
import WWWavWriter

let samples: [Float] = [0.0, 0.25, -0.25, 0.5]
let pcmData = samples.samplesData()
let wavData = try WWWavWriter.makeData(wavType: .Float32(pcmData), sampleRate: 48_000, channels: 1)
```

### Raw data with custom config

```swift
import WWWavWriter

let rawPCMBytes: [UInt8] = [0x00, 0x00, 0xE8, 0x03, 0x18, 0xFC, 0xD0, 0x07]
let pcmData = Data(rawPCMBytes)
let config = WWWavWriter.Config(sampleRate: 16_000, channels: 1, bitsPerSample: 16, audioFormat: .pcmInteger)
let wavData = try WWWavWriter.makeData(audioData: pcmData, config: config)
```

## Demo

```swift
import UIKit
import WWWavWriter

final class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        int16ToWav()
        float32ToWav()
        rawDataToWav()
    }
}

private extension ViewController {
    
    func int16ToWav() {
        
        do {
            let samples: [Int16] = [0, 1000, -1000, 2000, -2000, 0]
            let wavData = try WWWavWriter.makeData(samplesType: .PCM16(samples), sampleRate: 16_000, channels: 1)
            let fileURL = demoOutputURL(fileName: "demo-int16.wav")
            try wavData.write(to: fileURL, options: .atomic)
            print("Saved Int16 WAV to:", fileURL.path)
        } catch {
            print("Write Int16 WAV failed:", error)
        }
    }
    
    func float32ToWav() {
        
        do {
            let samples: [Float] = [0.0, 0.25, -0.25, 0.5]
            let pcmData = samples.samplesData()
            let wavData = try WWWavWriter.makeData(wavType: .Float32(pcmData), sampleRate: 48_000, channels: 1)
            let fileURL = demoOutputURL(fileName: "demo-float32.wav")
            try wavData.write(to: fileURL, options: .atomic)
            print("Saved Float32 WAV to:", fileURL.path)
        } catch {
            print("Write Float32 WAV failed:", error)
        }
    }
    
    func rawDataToWav() {
        
        do {
            let rawPCMBytes: [UInt8] = [0x00, 0x00, 0xE8, 0x03, 0x18, 0xFC, 0xD0, 0x07]
            let pcmData = Data(rawPCMBytes)
            let config = WWWavWriter.Config(sampleRate: 16_000, channels: 1, bitsPerSample: 16, audioFormat: .pcmInteger)
            let wavData = try WWWavWriter.makeData(audioData: pcmData, config: config)
            let fileURL = demoOutputURL(fileName: "demo-rawdata.wav")
            try wavData.write(to: fileURL, options: .atomic)
            print("Saved RawData WAV to:", fileURL.path)
        } catch {
            print("Write RawData WAV failed:", error)
        }
    }
    
    func demoOutputURL(fileName: String) -> URL {
        URL.documentsDirectory.appending(path: fileName)
    }
}
```

This will generate:

- `demo-int16.wav`
- `demo-float32.wav`
- `demo-rawdata.wav`

## Notes

- Input audio data must already match the declared format.
- Stereo and multichannel data must be interleaved.
- This package wraps audio into WAV; it does not resample or convert sample formats.
