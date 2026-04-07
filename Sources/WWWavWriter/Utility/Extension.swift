//
//  Extension.swift
//  WWWavWriter
//
//  Created by William.Weng on 2026/4/7.
//

import UIKit

// MARK: - [Int16]
public extension Collection where Element == Int16, Self.Index == Int {

    /// 把整個 Int16 序列轉成小端位元組的 Data（例如，供 WAV PCB16 檔案用）
    /// - Returns: Data
    func samplesData() -> Data {
        let little = map { $0.littleEndian }
        return little.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}

// MARK: - [Float]
public extension Collection where Element == Float, Self.Index == Int {
    
    /// 把整個 Float 序列轉成原始位元組的 Data（小端位元組順序，若在小端 CPU 上）
    /// - Returns: 一個包含所有 Float 位元組的 Data
    func samplesData() -> Data {
        let little = map { $0 }
        return little.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}

// MARK: - [Double]
public extension Collection where Element == Double, Self.Index == Int {

    /// 把整個 Double 序列轉成原始位元組的 Data（小端位元組順序，若在小端 CPU 上）
    /// - Returns: 一個包含所有 Double 位元組的 Data
    func samplesData() -> Data {
        let little = map { $0 }
        return little.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}

// MARK: - Data
extension Data {
    
    /// [加上 UTF-8 編碼的字串內容（ASCII 範圍內的字元）](https://zh.wikipedia.org/zh-tw/ASCII)
    /// - Parameter string: 要追加的字串，其 UTF-8 位元組會被寫入 Data
    mutating func appendASCII(_ string: String) {
        append(contentsOf: string.utf8)
    }
    
    /// [以小端（little-endian）格式追加一個 16 位元整數](https://blog.gtwang.org/programming/difference-between-big-endian-and-little-endian-implementation-in-c/)
    /// - Parameter value: 要寫入的 UInt16 值
    mutating func appendLE(_ value: UInt16) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }
    
    /// [以小端（little-endian）格式追加一個 32 位元整數](https://zh.wikipedia.org/zh-tw/字节序)
    /// - Parameter value: 要寫入的 UInt32 值
    mutating func appendLE(_ value: UInt32) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }
}
