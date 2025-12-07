//
//  TTSViewModel.swift
//  RendVu
//
//  Created on 2025-11-23.
//

import Foundation
import Combine
import AVFoundation

@MainActor
class TTSViewModel: ObservableObject {
    @Published var text = ""
    @Published var selectedModelId: String? = nil
    @Published var speed: Double = 1.0
    @Published var volume: Int = 0
    @Published var availableModels: [VoiceModel] = []
    @Published var isGenerating = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published var isLoadingHistory = false
    @Published var history: [TTSHistoryItem] = []
    
    private var audioPlayer: AVAudioPlayer?
    private let historyFolderName = "RendVuTTS"
    
    init() {
        configureAudioSession()
    }
    
    func loadModels(authManager: AuthManager) async {
        guard let idToken = authManager.idToken else { return }
        
        do {
            let models = try await APIClient.shared.getVoiceModels(idToken: idToken)
            availableModels = models
        } catch {
            errorMessage = "モデルの読み込みに失敗しました: \(error.localizedDescription)"
        }
    }
    
    func loadHistory(authManager: AuthManager) async {
        guard let idToken = authManager.idToken else { return }
        isLoadingHistory = true
        defer { isLoadingHistory = false }
        
        do {
            let items = try await APIClient.shared.fetchTTSHistory(idToken: idToken)
            history = items
        } catch {
            errorMessage = "履歴の取得に失敗しました: \(error.localizedDescription)"
        }
    }
    
    func generateTTS(authManager: AuthManager) async {
        guard let idToken = authManager.idToken else {
            errorMessage = "認証トークンが見つかりません"
            return
        }
        
        guard !text.isEmpty else {
            errorMessage = "テキストを入力してください"
            return
        }
        
        isGenerating = true
        errorMessage = nil
        
        do {
            let audioData = try await APIClient.shared.generateTTS(
                text: text,
                modelId: selectedModelId,
                format: "mp3",
                speed: speed,
                volume: volume,
                idToken: idToken
            )
            
            // 音声を再生
            try playAudio(data: audioData)
            
            await loadHistory(authManager: authManager)
            
        } catch {
            errorMessage = "エラー: \(error.localizedDescription)"
        }
        
        isGenerating = false
    }
    
    func playHistory(
        item: TTSHistoryItem,
        authManager: AuthManager
    ) async {
        guard let idToken = authManager.idToken else { return }
        do {
            let data = try await APIClient.shared.downloadTTSHistory(
                historyId: item.id,
                idToken: idToken
            )
            try playAudio(data: data)
        } catch {
            errorMessage = "履歴の再生に失敗しました: \(error.localizedDescription)"
        }
    }
    
    func saveHistoryToFiles(
        item: TTSHistoryItem,
        authManager: AuthManager
    ) async {
        guard let idToken = authManager.idToken else { return }
        do {
            let data = try await APIClient.shared.downloadTTSHistory(
                historyId: item.id,
                idToken: idToken
            )
            
            let fileURL = localFileURL(for: item)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: fileURL, options: Data.WritingOptions.atomic)
            
            infoMessage = """
保存しました: \(item.file_name)
「ファイル」アプリ >「このiPhone内」> RendVu > \(historyFolderName) で確認できます。
"""
        } catch {
            errorMessage = "保存に失敗しました: \(error.localizedDescription)"
        }
    }
    
    private func playAudio(data: Data) throws {
        audioPlayer = try AVAudioPlayer(data: data)
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
    }
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch {
            print("Audio session setup failed: \(error.localizedDescription)")
        }
    }
    
    private func localFileURL(for item: TTSHistoryItem) -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = documents.appendingPathComponent(historyFolderName, isDirectory: true)
        return directory.appendingPathComponent(item.file_name)
    }
}

