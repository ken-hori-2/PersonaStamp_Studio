//
//  AudioSeparator.swift
//  stamp_voice_creator
//
//  Created by 堀内健司 on 2025/11/17.
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
    
    func separate(
        from inputURL: URL,
        to outputURLs: OutputURLs,
        stemType: StemType
    ) -> AsyncThrowingStream<SeparationProgress, Error> {
        AsyncThrowingStream { continuation in
            Task {
                // セキュリティスコープ付きリソースへのアクセスを開始
                let isAccessing = inputURL.startAccessingSecurityScopedResource()
                defer {
                    if isAccessing {
                        inputURL.stopAccessingSecurityScopedResource()
                    }
                }
                
                do {
                    // ファイルの存在確認
                    guard FileManager.default.fileExists(atPath: inputURL.path) else {
                        throw AudioSeparationError.invalidAudioData
                    }
                    
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
                    
                    // STFTでスペクトログラムに変換
                    let spectrogram = performSTFT(audioData: audioData)
                    
                    // モデルの期待形状を確認（最初にモデルを読み込んで形状を確認）
                    let tempModel = try CoreMLModelWrapper(modelURL: modelURL)
                    let modelDescription = tempModel.getModelDescription()
                    guard let inputDescription = modelDescription.inputDescriptionsByName["magnitude"],
                          let multiArrayConstraint = inputDescription.multiArrayConstraint else {
                        throw AudioSeparationError.modelNotFound
                    }
                    
                    let expectedShape = multiArrayConstraint.shape
                    guard expectedShape.count >= 2 else {
                        throw AudioSeparationError.modelNotFound
                    }
                    
                    let expectedTimeFrames = expectedShape[0].intValue
                    let expectedFrequencyBins = expectedShape[1].intValue
                    
                    print("Processing with model shape: [\(expectedTimeFrames), \(expectedFrequencyBins)]")
                    
                    // モデルが期待する形状に合わせてチャンクサイズを設定
                    let chunkSize = expectedTimeFrames
                    let totalChunks = (spectrogram.count + chunkSize - 1) / chunkSize
                    
                    var separatedStems: [[[Float]]] = []
                    
                    for chunkIndex in 0..<totalChunks {
                        let startIndex = chunkIndex * chunkSize
                        let endIndex = min(startIndex + chunkSize, spectrogram.count)
                        let chunk = Array(spectrogram[startIndex..<endIndex])
                        
                        // Core ML推論
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
    
    private func performSTFT(audioData: [Float]) -> [[Float]] {
        let fftSize = frameSize
        // Hannウィンドウを生成
        var window = [Float](repeating: 0, count: fftSize)
        for i in 0..<fftSize {
            window[i] = Float(0.5 * (1.0 - cos(2.0 * Double.pi * Double(i) / Double(fftSize - 1))))
        }
        
        var spectrogram: [[Float]] = []
        
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
            guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
                continue
            }
            
            var realp = [Float](repeating: 0, count: fftSize / 2 + 1)
            var imagp = [Float](repeating: 0, count: fftSize / 2 + 1)
            
            windowedFrame.withUnsafeBufferPointer { inputPtr in
                realp.withUnsafeMutableBufferPointer { realpPtr in
                    imagp.withUnsafeMutableBufferPointer { imagpPtr in
                        var splitComplex = DSPSplitComplex(
                            realp: realpPtr.baseAddress!,
                            imagp: imagpPtr.baseAddress!
                        )
                        
                        inputPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexPtr in
                            vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
                        }
                        
                        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                    }
                }
            }
            
            vDSP_destroy_fftsetup(fftSetup)
            
            // マグニチュードを計算
            var magnitude = [Float](repeating: 0, count: fftSize / 2)
            for i in 0..<fftSize / 2 {
                magnitude[i] = sqrt(realp[i] * realp[i] + imagp[i] * imagp[i])
            }
            
            // 高周波成分をカット（maxFreqまで）
            // モデルが期待する周波数ビン数に合わせる（2048または1024）
            // まずは全周波数ビンを使用
            let freqBinCount = fftSize / 2  // 2048
            let trimmedMagnitude = Array(magnitude[0..<freqBinCount])
            
            spectrogram.append(trimmedMagnitude)
            
            index += hopSize
        }
        
        return spectrogram
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
    
    private func performInverseSTFT(spectrogram: [[Float]]) -> [Float] {
        // 逆STFTの実装（簡略版）
        // 実際の実装では、位相情報も必要
        let fftSize = frameSize
        // Hannウィンドウを生成
        var window = [Float](repeating: 0, count: fftSize)
        for i in 0..<fftSize {
            window[i] = Float(0.5 * (1.0 - cos(2.0 * Double.pi * Double(i) / Double(fftSize - 1))))
        }
        
        var audioData: [Float] = []
        var overlapAdd = [Float](repeating: 0, count: spectrogram.count * hopSize + fftSize)
        
        for (frameIndex, magnitude) in spectrogram.enumerated() {
            // スペクトログラムをフルサイズに復元
            var fullMagnitude = [Float](repeating: 0, count: fftSize / 2)
            for i in 0..<min(magnitude.count, fullMagnitude.count) {
                fullMagnitude[i] = magnitude[i]
            }
            
            // 位相を0として仮定（簡略版）
            var realp = fullMagnitude
            var imagp = [Float](repeating: 0, count: fftSize / 2)
            
            // 逆FFT
            let log2n = vDSP_Length(log2(Double(fftSize)))
            guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
                continue
            }
            
            realp.withUnsafeMutableBufferPointer { realpPtr in
                imagp.withUnsafeMutableBufferPointer { imagpPtr in
                    var splitComplex = DSPSplitComplex(
                        realp: realpPtr.baseAddress!,
                        imagp: imagpPtr.baseAddress!
                    )
                    
                    vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_INVERSE))
                    
                    // 時間領域に変換
                    var timeDomain = [Float](repeating: 0, count: fftSize)
                    realpPtr.baseAddress!.withMemoryRebound(to: Float.self, capacity: fftSize / 2) { realPtr in
                        imagpPtr.baseAddress!.withMemoryRebound(to: Float.self, capacity: fftSize / 2) { imagPtr in
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
            }
            
            vDSP_destroy_fftsetup(fftSetup)
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
        for (index, stemSpectrogram) in separatedStems.enumerated() {
            let audioData = performInverseSTFT(spectrogram: stemSpectrogram)
            
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
                buffer.floatChannelData?[0].update(from: dataPtr.baseAddress!, count: audioData.count)
            }
            
            try audioFile.write(from: buffer)
        }
    }
    
    private func getModelURL(for stemType: StemType) -> URL? {
        // モデルファイルのパスを返す
        let modelName: String
        switch stemType {
        case .two: modelName = "Spleeter2Model"
        case .four: modelName = "Spleeter4.mlmodelc"
        case .five: modelName = "Spleeter5.mlmodelc"
        }
        
        // バンドル内を検索
        if let bundleURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") {
            return bundleURL
        }
        
        // Documentsディレクトリを検索
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let modelURL = documentsURL.appendingPathComponent("\(modelName).mlmodelc")
            if FileManager.default.fileExists(atPath: modelURL.path) {
                return modelURL
            }
        }
        
        return nil
    }
}

/// Core MLモデルのラッパークラス
class CoreMLModelWrapper {
    private let model: MLModel
    
    init(modelURL: URL) throws {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine // または .all, .cpuAndGPU
        self.model = try MLModel(contentsOf: modelURL, configuration: config)
    }
    
    /// モデルの説明を取得
    func getModelDescription() -> MLModelDescription {
        return model.modelDescription
    }
    
    /// 複数のマスクを予測（2stems, 4stems, 5stems用）
    func predictMasks(spectrogram: [[Float]], stemType: StemType) throws -> [[[Float]]] {
        // モデルの期待形状を確認
        let modelDescription = model.modelDescription
        
        // デバッグ: 利用可能な入力名を確認
        let availableInputNames = modelDescription.inputDescriptionsByName.keys
        print("Available input names: \(availableInputNames)")
        
        // 入力名を確認（"magnitude"でない可能性がある）
        let inputName = availableInputNames.first ?? "magnitude"
        guard let inputDescription = modelDescription.inputDescriptionsByName[inputName],
              let multiArrayConstraint = inputDescription.multiArrayConstraint else {
            print("Error: Could not find input description for '\(inputName)'")
            throw AudioSeparationError.invalidAudioData
        }
        
        let expectedShape = multiArrayConstraint.shape
        let expectedRank = expectedShape.count
        
        print("Model expects rank: \(expectedRank), shape: \(expectedShape)")
        print("Model shape constraint: \(multiArrayConstraint)")
        
        // ランク3の場合（通常は [batch, timeFrames, frequencyBins] または [1, timeFrames, frequencyBins]）
        guard expectedRank >= 2 else {
            throw AudioSeparationError.invalidAudioData
        }
        
        let expectedTimeFrames: Int
        let expectedFrequencyBins: Int
        
        if expectedRank == 3 {
            // ランク3の場合: [batch, timeFrames, frequencyBins] または [channels, timeFrames, frequencyBins]
            let batchOrChannels = expectedShape[0].intValue
            expectedTimeFrames = expectedShape[1].intValue
            expectedFrequencyBins = expectedShape[2].intValue
            print("Model expects 3D shape: [\(batchOrChannels), \(expectedTimeFrames), \(expectedFrequencyBins)]")
        } else {
            // ランク2の場合: [timeFrames, frequencyBins]
            expectedTimeFrames = expectedShape[0].intValue
            expectedFrequencyBins = expectedShape[1].intValue
            print("Model expects 2D shape: [\(expectedTimeFrames), \(expectedFrequencyBins)]")
        }
        
        let actualTimeFrames = spectrogram.count
        guard actualTimeFrames > 0 else {
            throw AudioSeparationError.invalidAudioData
        }
        let actualFrequencyBins = spectrogram[0].count
        
        print("Actual spectrogram shape: [\(actualTimeFrames), \(actualFrequencyBins)]")
        
        // スペクトログラムをモデルの期待形状に合わせてリサイズ
        var resizedSpectrogram: [[Float]] = []
        
        // 時間フレームの調整（パディングまたはトリミング）
        for i in 0..<expectedTimeFrames {
            if i < actualTimeFrames {
                var frame = spectrogram[i]
                // 周波数ビンの調整（パディングまたはトリミング）
                if frame.count < expectedFrequencyBins {
                    // パディング（ゼロで埋める）
                    frame.append(contentsOf: [Float](repeating: 0, count: expectedFrequencyBins - frame.count))
                } else if frame.count > expectedFrequencyBins {
                    // トリミング
                    frame = Array(frame[0..<expectedFrequencyBins])
                }
                resizedSpectrogram.append(frame)
            } else {
                // 時間フレームが足りない場合はゼロで埋める
                resizedSpectrogram.append([Float](repeating: 0, count: expectedFrequencyBins))
            }
        }
        
        // 入力配列を作成（モデルの期待するランクに合わせる）
        let inputArray: MLMultiArray
        do {
            if expectedRank == 3 {
                // ランク3の場合: [1, timeFrames, frequencyBins] として作成
                let batchSize = expectedShape[0].intValue
                inputArray = try MLMultiArray(
                    shape: [
                        NSNumber(value: batchSize),
                        NSNumber(value: expectedTimeFrames),
                        NSNumber(value: expectedFrequencyBins)
                    ],
                    dataType: .float32
                )
            } else {
                // ランク2の場合: [timeFrames, frequencyBins]
                inputArray = try MLMultiArray(
                    shape: [
                        NSNumber(value: expectedTimeFrames),
                        NSNumber(value: expectedFrequencyBins)
                    ],
                    dataType: .float32
                )
            }
        } catch {
            print("Failed to create MLMultiArray: \(error)")
            throw AudioSeparationError.bufferCreationFailed
        }
        
        // データをコピー（MLMultiArrayは行優先でデータを格納）
        // ランク2の場合: [timeFrames, frequencyBins] -> [frame0_bin0, frame0_bin1, ..., frame0_binN, frame1_bin0, ...]
        // ランク3の場合: [batch, timeFrames, frequencyBins] -> [batch0_frame0_bin0, batch0_frame0_bin1, ..., batch0_frame0_binN, batch0_frame1_bin0, ...]
        // バッチサイズが1の場合、データの順序は同じ
        var index = 0
        var hasInvalidValue = false
        for frame in resizedSpectrogram {
            for value in frame {
                // NaNやInfinityをチェック
                if value.isNaN || value.isInfinite {
                    hasInvalidValue = true
                    print("Warning: Invalid value found at index \(index): \(value)")
                }
                inputArray[index] = NSNumber(value: value.isNaN ? 0.0 : (value.isInfinite ? (value > 0 ? Float.greatestFiniteMagnitude : -Float.greatestFiniteMagnitude) : value))
                index += 1
            }
        }
        
        if hasInvalidValue {
            print("Warning: Some invalid values were found and replaced")
        }
        
        // デバッグ: 入力配列の形状とサイズを確認
        let expectedCount = expectedRank == 3 
            ? expectedShape[0].intValue * expectedTimeFrames * expectedFrequencyBins
            : expectedTimeFrames * expectedFrequencyBins
        print("Input array shape: \(inputArray.shape), count: \(inputArray.count), expected: \(expectedCount)")
        
        // 入力特徴量を作成（実際の入力名を使用）
        let input = try MLDictionaryFeatureProvider(dictionary: [inputName: MLFeatureValue(multiArray: inputArray)])
        
        if expectedRank == 3 {
            print("Sending input with shape: [\(expectedShape[0].intValue), \(expectedTimeFrames), \(expectedFrequencyBins)]")
        } else {
            print("Sending input with shape: [\(expectedTimeFrames), \(expectedFrequencyBins)]")
        }
        
        // 推論実行
        let prediction = try model.prediction(from: input)
        
        // 出力マスク名を取得
        let outputNames: [String]
        switch stemType {
        case .two:
            outputNames = ["vocalsMask", "instrumentsMask"]
        case .four:
            outputNames = ["vocalsMask", "drumsMask", "bassMask", "otherMask"]
        case .five:
            outputNames = ["vocalsMask", "drumsMask", "bassMask", "pianoMask", "otherMask"]
        }
        
        // 各マスクを取得
        var masks: [[[Float]]] = []
        for outputName in outputNames {
            guard let outputArray = prediction.featureValue(for: outputName)?.multiArrayValue else {
                // 出力名が見つからない場合、モデルの出力名を確認する必要があります
                // ここでは、最初の出力を使用するフォールバック処理
                if let firstOutput = prediction.featureNames.first,
                   let outputArray = prediction.featureValue(for: firstOutput)?.multiArrayValue {
                    let mask = convertMLMultiArrayToSpectrogram(
                        array: outputArray,
                        timeFrames: expectedTimeFrames,
                        frequencyBins: expectedFrequencyBins
                    )
                    masks.append(mask)
                } else {
                    throw AudioSeparationError.invalidAudioData
                }
                continue
            }
            
            let mask = convertMLMultiArrayToSpectrogram(
                array: outputArray,
                timeFrames: expectedTimeFrames,
                frequencyBins: expectedFrequencyBins
            )
            masks.append(mask)
        }
        
        // マスクを元のスペクトログラムの形状に戻す（必要に応じて）
        var adjustedMasks: [[[Float]]] = []
        for mask in masks {
            var adjustedMask: [[Float]] = []
            for (i, maskFrame) in mask.enumerated() {
                if i < actualTimeFrames {
                    // 元の周波数ビン数に合わせて調整
                    if maskFrame.count >= actualFrequencyBins {
                        adjustedMask.append(Array(maskFrame[0..<actualFrequencyBins]))
                    } else {
                        var adjustedFrame = maskFrame
                        adjustedFrame.append(contentsOf: [Float](repeating: 0, count: actualFrequencyBins - maskFrame.count))
                        adjustedMask.append(adjustedFrame)
                    }
                }
            }
            adjustedMasks.append(adjustedMask)
        }
        
        return adjustedMasks
    }
    
    /// MLMultiArrayをスペクトログラム形式に変換
    private func convertMLMultiArrayToSpectrogram(
        array: MLMultiArray,
        timeFrames: Int,
        frequencyBins: Int
    ) -> [[Float]] {
        var result: [[Float]] = []
        var resultIndex = 0
        
        for _ in 0..<timeFrames {
            var frame: [Float] = []
            for _ in 0..<frequencyBins {
                if resultIndex < array.count {
                    frame.append(array[resultIndex].floatValue)
                } else {
                    frame.append(0.0)
                }
                resultIndex += 1
            }
            result.append(frame)
        }
        
        return result
    }
}

enum AudioSeparationError: LocalizedError {
    case modelNotFound
    case bufferCreationFailed
    case invalidAudioData
    case fileWriteFailed
    case fileAccessFailed
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "Core MLモデルが見つかりません。モデルファイルをダウンロードしてください。"
        case .bufferCreationFailed:
            return "オーディオバッファの作成に失敗しました。"
        case .invalidAudioData:
            return "無効なオーディオデータです。ファイルが存在しないか、読み込めません。"
        case .fileWriteFailed:
            return "ファイルの書き込みに失敗しました。"
        case .fileAccessFailed:
            return "ファイルへのアクセスに失敗しました。ファイルの権限を確認してください。"
        }
    }
}

