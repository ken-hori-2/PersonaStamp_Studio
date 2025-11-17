//
//  AudioSeparator.swift
//  VoiceCreator
//
//  Created on 2025-01-27.
//

import Foundation
import AVFoundation
import Accelerate
import CoreML

struct SeparationProgress {
    let current: Int
    let total: Int
}

class AudioSeparator {
    private let frameSize: Int = 4096
    private let hopSize: Int = 1024
    private let sampleRate: Double = 44100.0
    private let maxFreq: Int = 22050 // sampleRate / 2
    
    // 元の位相情報を保持（逆STFTで使用）
    private var originalPhases: [[Float]] = []
    
    func separate(
        from inputURL: URL,
        to outputURLs: OutputURLs,
        stemType: StemType
    ) -> AsyncThrowingStream<SeparationProgress, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // モデルの読み込み（実際の実装では、モデルファイルのパスを指定）
                    // ここではプレースホルダーとして実装
                    guard let modelURL = getModelURL(for: stemType) else {
                        throw AudioSeparationError.modelNotFound
                    }
                    
                    // 音源ファイルの読み込み
                    let audioFile = try AVAudioFile(forReading: inputURL)
                    let format = audioFile.processingFormat
                    let frameCount = Int(audioFile.length)
                    
                    // オーディオデータの読み込み
                    guard let buffer = AVAudioPCMBuffer(
                        pcmFormat: format,
                        frameCapacity: AVAudioFrameCount(frameCount)
                    ) else {
                        throw AudioSeparationError.bufferCreationFailed
                    }
                    
                    try audioFile.read(into: buffer)
                    
                    guard let floatChannelData = buffer.floatChannelData else {
                        throw AudioSeparationError.invalidAudioData
                    }
                    
                    // モノラルに変換（ステレオの場合は平均を取る）
                    let audioData: [Float]
                    if format.channelCount > 1 {
                        let leftChannel = Array(UnsafeBufferPointer(
                            start: floatChannelData[0],
                            count: frameCount
                        ))
                        let rightChannel = Array(UnsafeBufferPointer(
                            start: floatChannelData[1],
                            count: frameCount
                        ))
                        audioData = zip(leftChannel, rightChannel).map { ($0 + $1) / 2.0 }
                    } else {
                        audioData = Array(UnsafeBufferPointer(
                            start: floatChannelData[0],
                            count: frameCount
                        ))
                    }
                    
                    // STFTでスペクトログラムに変換（位相情報も保持）
                    let (spectrogram, phases) = performSTFTWithPhase(audioData: audioData)
                    originalPhases = phases
                    
                    // チャンクに分割して処理
                    let chunkSize = 512 // 固定サイズのチャンク
                    let totalChunks = (spectrogram.count + chunkSize - 1) / chunkSize
                    
                    var separatedStems: [[[Float]]] = []
                    
                    for chunkIndex in 0..<totalChunks {
                        let startIndex = chunkIndex * chunkSize
                        let endIndex = min(startIndex + chunkSize, spectrogram.count)
                        let chunk = Array(spectrogram[startIndex..<endIndex])
                        
                        // Core ML推論（プレースホルダー）
                        // 実際の実装では、モデルを読み込んで推論を実行
                        let chunkStems = try await performInference(
                            spectrogram: chunk,
                            modelURL: modelURL,
                            stemType: stemType
                        )
                        
                        if separatedStems.isEmpty {
                            separatedStems = chunkStems
                        } else {
                            for i in 0..<separatedStems.count {
                                separatedStems[i].append(contentsOf: chunkStems[i])
                            }
                        }
                        
                        continuation.yield(SeparationProgress(
                            current: chunkIndex + 1,
                            total: totalChunks
                        ))
                    }
                    
                    // 逆STFTで波形に変換
                    let outputFormat = AVAudioFormat(
                        commonFormat: .pcmFormatFloat32,
                        sampleRate: sampleRate,
                        channels: 1,
                        interleaved: false
                    )!
                    
                    // 各ステムを保存
                    try await saveStems(
                        separatedStems: separatedStems,
                        outputURLs: outputURLs,
                        format: outputFormat
                    )
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func performSTFTWithPhase(audioData: [Float]) -> (magnitude: [[Float]], phase: [[Float]]) {
        var magnitudeSpectrogram: [[Float]] = []
        var phaseSpectrogram: [[Float]] = []
        
        performSTFT(audioData: audioData, magnitude: &magnitudeSpectrogram, phase: &phaseSpectrogram)
        return (magnitudeSpectrogram, phaseSpectrogram)
    }
    
    private func performSTFT(audioData: [Float]) -> [[Float]] {
        var magnitude: [[Float]] = []
        var phase: [[Float]] = []
        performSTFT(audioData: audioData, magnitude: &magnitude, phase: &phase)
        return magnitude
    }
    
    private func performSTFT(audioData: [Float], magnitude: inout [[Float]], phase: inout [[Float]]) {
        let fftSize = frameSize
        let window = vDSP.window(ofType: Float.self, usingSequence: .hann, count: fftSize, isHalfWindow: false)
        
        // ゼロパディング
        let padding = fftSize / 2
        let paddedData = [Float](repeating: 0, count: padding) + audioData + [Float](repeating: 0, count: padding)
        
        var index = 0
        while index + fftSize <= paddedData.count {
            // フレームを取得
            let frame = Array(paddedData[index..<index + fftSize])
            
            // ウィンドウを適用
            let windowedFrame = vDSP.multiply(window, frame)
            
            // FFT
            let log2n = vDSP_Length(log2(Double(fftSize)))
            let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
            
            var realp = [Float](repeating: 0, count: fftSize / 2)
            var imagp = [Float](repeating: 0, count: fftSize / 2)
            
            windowedFrame.withUnsafeBufferPointer { inputPtr in
                var splitComplex = DSPSplitComplex(
                    realp: UnsafeMutablePointer(mutating: realp),
                    imagp: UnsafeMutablePointer(mutating: imagp)
                )
                
                inputPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexPtr in
                    vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
                }
                
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
            }
            
            vDSP_destroy_fftsetup(fftSetup)
            
            // マグニチュードと位相を計算
            var magnitudeFrame = [Float](repeating: 0, count: fftSize / 2)
            var phaseFrame = [Float](repeating: 0, count: fftSize / 2)
            for i in 0..<fftSize / 2 {
                let real = realp[i]
                let imag = imagp[i]
                magnitudeFrame[i] = sqrt(real * real + imag * imag)
                phaseFrame[i] = atan2(imag, real)
            }
            
            // 高周波成分をカット（maxFreqまで）
            let freqBinCount = min(fftSize / 2, maxFreq * fftSize / Int(sampleRate))
            let trimmedMagnitude = Array(magnitudeFrame[0..<freqBinCount])
            let trimmedPhase = Array(phaseFrame[0..<freqBinCount])
            
            magnitude.append(trimmedMagnitude)
            phase.append(trimmedPhase)
            
            index += hopSize
        }
    }
    
    private func performInference(
        spectrogram: [[Float]],
        modelURL: URL,
        stemType: StemType
    ) async throws -> [[[Float]]] {
        // Core MLモデルを読み込んで推論を実行
        let model = try CoreMLModelWrapper(modelURL: modelURL)
        let masks = try model.predictMasks(spectrogram: spectrogram, stemType: stemType)
        
        // マスクを適用して各ステムを分離
        var separatedStems: [[[Float]]] = []
        for mask in masks {
            let separated = zip(spectrogram, mask).map { (magnitude, maskValue) in
                zip(magnitude, maskValue).map { $0 * $1 }
            }
            separatedStems.append(separated)
        }
        
        return separatedStems
    }
    
    private func performInverseSTFT(spectrogram: [[Float]], phases: [[Float]]? = nil) -> [Float] {
        let fftSize = frameSize
        let window = vDSP.window(ofType: Float.self, usingSequence: .hann, count: fftSize, isHalfWindow: false)
        
        var audioData: [Float] = []
        let estimatedLength = spectrogram.count * hopSize + fftSize
        var overlapAdd = [Float](repeating: 0, count: estimatedLength)
        
        // 位相情報を使用（利用可能な場合）
        let usePhases = phases != nil && phases!.count == spectrogram.count
        
        for (frameIndex, magnitude) in spectrogram.enumerated() {
            // スペクトログラムをフルサイズに復元
            var fullMagnitude = [Float](repeating: 0, count: fftSize / 2)
            for i in 0..<min(magnitude.count, fullMagnitude.count) {
                fullMagnitude[i] = magnitude[i]
            }
            
            // 位相情報を取得
            var fullPhase = [Float](repeating: 0, count: fftSize / 2)
            if usePhases, let phaseFrame = phases?[frameIndex] {
                for i in 0..<min(phaseFrame.count, fullPhase.count) {
                    fullPhase[i] = phaseFrame[i]
                }
            }
            // 位相が利用できない場合は0（実部のみ）
            
            // 複素数に変換
            var realp = [Float](repeating: 0, count: fftSize / 2)
            var imagp = [Float](repeating: 0, count: fftSize / 2)
            for i in 0..<fftSize / 2 {
                realp[i] = fullMagnitude[i] * cos(fullPhase[i])
                imagp[i] = fullMagnitude[i] * sin(fullPhase[i])
            }
            
            // 逆FFT
            let log2n = vDSP_Length(log2(Double(fftSize)))
            let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
            
            var splitComplex = DSPSplitComplex(
                realp: UnsafeMutablePointer(mutating: realp),
                imagp: UnsafeMutablePointer(mutating: imagp)
            )
            
            vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_INVERSE))
            vDSP_destroy_fftsetup(fftSetup)
            
            // 時間領域に変換
            var timeDomain = [Float](repeating: 0, count: fftSize)
            splitComplex.realp.withMemoryRebound(to: Float.self, capacity: fftSize / 2) { realPtr in
                splitComplex.imagp.withMemoryRebound(to: Float.self, capacity: fftSize / 2) { imagPtr in
                    for i in 0..<fftSize / 2 {
                        timeDomain[i * 2] = realPtr[i]
                        timeDomain[i * 2 + 1] = imagPtr[i]
                    }
                }
            }
            
            // ウィンドウを適用
            let windowed = vDSP.multiply(window, timeDomain)
            
            // オーバーラップ・アッド
            let offset = frameIndex * hopSize
            for i in 0..<windowed.count {
                if offset + i < overlapAdd.count {
                    overlapAdd[offset + i] += windowed[i]
                }
            }
        }
        
        // パディングを除去
        let padding = fftSize / 2
        if overlapAdd.count > padding * 2 {
            audioData = Array(overlapAdd[padding..<overlapAdd.count - padding])
        } else {
            audioData = overlapAdd
        }
        
        return audioData
    }
    
    private func saveStems(
        separatedStems: [[[Float]]],
        outputURLs: OutputURLs,
        format: AVAudioFormat
    ) async throws {
        let stemCount = separatedStems.count
        
        for (index, stemSpectrogram) in separatedStems.enumerated() {
            // 元の位相情報を使用して逆STFTを実行
            let audioData = performInverseSTFT(spectrogram: stemSpectrogram, phases: originalPhases)
            
            // 出力URLを取得
            let outputURL: URL
            switch outputURLs {
            case .two(let vocals, let instruments):
                outputURL = index == 0 ? vocals : instruments
            case .four(let vocals, let drums, let bass, let other):
                switch index {
                case 0: outputURL = vocals
                case 1: outputURL = drums
                case 2: outputURL = bass
                default: outputURL = other
                }
            case .five(let vocals, let drums, let bass, let piano, let other):
                switch index {
                case 0: outputURL = vocals
                case 1: outputURL = drums
                case 2: outputURL = bass
                case 3: outputURL = piano
                default: outputURL = other
                }
            }
            
            // オーディオファイルに保存
            guard let audioFile = try? AVAudioFile(forWriting: outputURL, settings: format.settings) else {
                throw AudioSeparationError.fileWriteFailed
            }
            
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(audioData.count)
            ) else {
                throw AudioSeparationError.bufferCreationFailed
            }
            
            buffer.frameLength = AVAudioFrameCount(audioData.count)
            audioData.withUnsafeBufferPointer { dataPtr in
                buffer.floatChannelData?[0].assign(from: dataPtr.baseAddress!, count: audioData.count)
            }
            
            try audioFile.write(from: buffer)
        }
    }
    
    private func getModelURL(for stemType: StemType) -> URL? {
        // モデルファイルのパスを返す
        // 実際の実装では、アプリバンドル内またはダウンロード済みのモデルファイルを指定
        let modelName: String
        switch stemType {
        case .two: modelName = "Spleeter2.mlmodelc"
        case .four: modelName = "Spleeter4.mlmodelc"
        case .five: modelName = "Spleeter5.mlmodelc"
        }
        
        // バンドル内を検索
        if let bundleURL = Bundle.main.url(forResource: modelName.replacingOccurrences(of: ".mlmodelc", with: ""), withExtension: "mlmodelc") {
            return bundleURL
        }
        
        // Documentsディレクトリを検索
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let modelURL = documentsURL.appendingPathComponent(modelName)
            if FileManager.default.fileExists(atPath: modelURL.path) {
                return modelURL
            }
        }
        
        return nil
    }
}

enum AudioSeparationError: LocalizedError {
    case modelNotFound
    case bufferCreationFailed
    case invalidAudioData
    case fileWriteFailed
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "Core MLモデルが見つかりません。モデルファイルをダウンロードしてください。"
        case .bufferCreationFailed:
            return "オーディオバッファの作成に失敗しました。"
        case .invalidAudioData:
            return "無効なオーディオデータです。"
        case .fileWriteFailed:
            return "ファイルの書き込みに失敗しました。"
        }
    }
}

