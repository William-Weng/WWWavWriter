//
//  ViewController.swift
//  Example
//
//  Created by William.Weng on 2025/10/29.
//

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
