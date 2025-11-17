//
//  CoreMLModelWrapper.swift
//  VoiceCreator
//
//  Created on 2025-01-27.
//

import Foundation
import CoreML

/// Core MLモデルのラッパークラス
/// 実際のモデルファイルに合わせて、このクラスを生成・修正してください
class CoreMLModelWrapper {
    private let model: MLModel
    
    init(modelURL: URL) throws {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine // または .all, .cpuAndGPU
        self.model = try MLModel(contentsOf: modelURL, configuration: config)
    }
    
    /// スペクトログラムからマスクを予測
    func predict(spectrogram: [[Float]]) throws -> [[Float]] {
        // スペクトログラムをMLMultiArrayに変換
        // 形状: [time_frames, frequency_bins]
        let timeFrames = spectrogram.count
        guard timeFrames > 0 else {
            throw AudioSeparationError.invalidAudioData
        }
        let frequencyBins = spectrogram[0].count
        
        guard let inputArray = try? MLMultiArray(
            shape: [NSNumber(value: timeFrames), NSNumber(value: frequencyBins)],
            dataType: .float32
        ) else {
            throw AudioSeparationError.bufferCreationFailed
        }
        
        // データをコピー
        var index = 0
        for frame in spectrogram {
            for value in frame {
                inputArray[index] = NSNumber(value: value)
                index += 1
            }
        }
        
        // 入力特徴量を作成
        let input = try MLDictionaryFeatureProvider(dictionary: ["magnitude": MLFeatureValue(multiArray: inputArray)])
        
        // 推論実行
        let prediction = try model.prediction(from: input)
        
        // 出力を取得（モデルに応じて出力名を変更）
        // 2stemsの場合: "vocalsMask", "instrumentsMask"
        // 4stemsの場合: "vocalsMask", "drumsMask", "bassMask", "otherMask"
        // 5stemsの場合: "vocalsMask", "drumsMask", "bassMask", "pianoMask", "otherMask"
        guard let outputArray = prediction.featureValue(for: "vocalsMask")?.multiArrayValue else {
            throw AudioSeparationError.invalidAudioData
        }
        
        // MLMultiArrayを[[Float]]に変換
        var result: [[Float]] = []
        var resultIndex = 0
        for _ in 0..<timeFrames {
            var frame: [Float] = []
            for _ in 0..<frequencyBins {
                frame.append(outputArray[resultIndex].floatValue)
                resultIndex += 1
            }
            result.append(frame)
        }
        
        return result
    }
    
    /// 複数のマスクを予測（2stems, 4stems, 5stems用）
    func predictMasks(spectrogram: [[Float]], stemType: StemType) throws -> [[[Float]]] {
        let timeFrames = spectrogram.count
        guard timeFrames > 0 else {
            throw AudioSeparationError.invalidAudioData
        }
        let frequencyBins = spectrogram[0].count
        
        // 入力配列を作成
        guard let inputArray = try? MLMultiArray(
            shape: [NSNumber(value: timeFrames), NSNumber(value: frequencyBins)],
            dataType: .float32
        ) else {
            throw AudioSeparationError.bufferCreationFailed
        }
        
        // データをコピー
        var index = 0
        for frame in spectrogram {
            for value in frame {
                inputArray[index] = NSNumber(value: value)
                index += 1
            }
        }
        
        // 入力特徴量を作成
        let input = try MLDictionaryFeatureProvider(dictionary: ["magnitude": MLFeatureValue(multiArray: inputArray)])
        
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
                throw AudioSeparationError.invalidAudioData
            }
            
            // MLMultiArrayを[[Float]]に変換
            var mask: [[Float]] = []
            var resultIndex = 0
            for _ in 0..<timeFrames {
                var frame: [Float] = []
                for _ in 0..<frequencyBins {
                    frame.append(outputArray[resultIndex].floatValue)
                    resultIndex += 1
                }
                mask.append(frame)
            }
            masks.append(mask)
        }
        
        return masks
    }
}

