//
//  AudioSeparationViewModel.swift
//  VoiceCreator
//
//  Created on 2025-01-27.
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

enum StemType: String, CaseIterable {
    case two = "2stems"
    case four = "4stems"
    case five = "5stems"
}

@MainActor
class AudioSeparationViewModel: ObservableObject {
    @Published var selectedFile: URL?
    @Published var selectedStemType: StemType = .two
    @Published var isProcessing = false
    @Published var currentProgress = 0
    @Published var totalProgress = 0
    @Published var errorMessage: String?
    @Published var isCompleted = false
    @Published var showFilePicker = false
    @Published var outputURLs: OutputURLs?
    
    private let audioSeparator = AudioSeparator()
    
    var canProcess: Bool {
        selectedFile != nil
    }
    
    func selectAudioFile() {
        showFilePicker = true
    }
    
    func handleSelectedFile(url: URL) {
        selectedFile = url
        errorMessage = nil
        isCompleted = false
        outputURLs = nil
    }
    
    func separateAudio() async {
        guard let inputURL = selectedFile else {
            errorMessage = "音源ファイルが選択されていません"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        isCompleted = false
        currentProgress = 0
        totalProgress = 0
        
        do {
            // 出力ディレクトリの準備
            let outputDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("audio_separation_\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
            
            // 出力URLの生成
            let outputURLs = createOutputURLs(in: outputDir, stemType: selectedStemType)
            
            // 音源分離の実行
            for try await progress in audioSeparator.separate(
                from: inputURL,
                to: outputURLs,
                stemType: selectedStemType
            ) {
                currentProgress = progress.current
                totalProgress = progress.total
            }
            
            self.outputURLs = outputURLs
            isCompleted = true
            errorMessage = nil
            
        } catch {
            errorMessage = "エラー: \(error.localizedDescription)"
            isCompleted = false
        }
        
        isProcessing = false
    }
    
    private func createOutputURLs(in directory: URL, stemType: StemType) -> OutputURLs {
        switch stemType {
        case .two:
            return OutputURLs.two(
                vocals: directory.appendingPathComponent("vocals.wav"),
                instruments: directory.appendingPathComponent("instruments.wav")
            )
        case .four:
            return OutputURLs.four(
                vocals: directory.appendingPathComponent("vocals.wav"),
                drums: directory.appendingPathComponent("drums.wav"),
                bass: directory.appendingPathComponent("bass.wav"),
                other: directory.appendingPathComponent("other.wav")
            )
        case .five:
            return OutputURLs.five(
                vocals: directory.appendingPathComponent("vocals.wav"),
                drums: directory.appendingPathComponent("drums.wav"),
                bass: directory.appendingPathComponent("bass.wav"),
                piano: directory.appendingPathComponent("piano.wav"),
                other: directory.appendingPathComponent("other.wav")
            )
        }
    }
}

enum OutputURLs {
    case two(vocals: URL, instruments: URL)
    case four(vocals: URL, drums: URL, bass: URL, other: URL)
    case five(vocals: URL, drums: URL, bass: URL, piano: URL, other: URL)
    
    var allURLs: [URL] {
        switch self {
        case .two(let vocals, let instruments):
            return [vocals, instruments]
        case .four(let vocals, let drums, let bass, let other):
            return [vocals, drums, bass, other]
        case .five(let vocals, let drums, let bass, let piano, let other):
            return [vocals, drums, bass, piano, other]
        }
    }
}

