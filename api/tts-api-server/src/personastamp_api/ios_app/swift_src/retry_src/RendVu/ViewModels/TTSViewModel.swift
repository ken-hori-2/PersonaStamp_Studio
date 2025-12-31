//
//  TTSViewModel.swift
//  RendVu
//
//  Created on 2025-11-23.
//

import Foundation
import Combine
@preconcurrency import AVFoundation

@MainActor
class TTSViewModel: ObservableObject {
    @Published var text = ""
    @Published var selectedModelId: String? = nil
    @Published var format: String = "mp3"
    @Published var speed: Double = 1.0
    @Published var volume: Int = 0
    @Published var availableModels: [VoiceModel] = []
    @Published var isGenerating = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published var showSaveSuccessAlert = false
    @Published var saveSuccessAlertMessage = ""
    @Published var isLoadingHistory = false
    @Published var history: [TTSHistoryItem] = []
    
    private var audioPlayer: AVAudioPlayer?
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var audioPlayerNode: AVAudioPlayerNode?
    private let historyFolderName = "RendVuTTS"
    
    init() {
        do {
            try configureAudioSession()
        } catch {
            print("Audio session setup failed: \(error.localizedDescription)")
        }
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
                format: format,
                speed: speed,
                volume: volume,
                idToken: idToken
            )
            
            // データが空でないことを確認
            guard !audioData.isEmpty else {
                errorMessage = "音声データが空です。フォーマット（\(format)）が正しく処理されなかった可能性があります。"
                isGenerating = false
                return
            }
            
            // 音声を再生
            try playAudio(data: audioData, format: format)
            
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
            // 履歴アイテムのフォーマットを使用
            let itemFormat = item.format.lowercased()
            try playAudio(data: data, format: itemFormat)
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
            
            // データが空でないことを確認
            guard !data.isEmpty else {
                errorMessage = "音声データが空です"
                return
            }
            
            let fileURL = localFileURL(for: item)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: fileURL, options: Data.WritingOptions.atomic)
            
            // ファイルが正しく保存されたことを確認
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                errorMessage = "ファイルの保存に失敗しました"
                return
            }
            
            infoMessage = """
保存しました: \(item.file_name)
「ファイル」アプリ >「このiPhone内」> Re:ndVu > \(historyFolderName) で確認できます。
"""
            saveSuccessAlertMessage = """
保存しました！

ファイル名: \(item.file_name)

「ファイル」アプリ >「このiPhone内」> Re:ndVu > \(historyFolderName) で確認できます。
"""
            showSaveSuccessAlert = true
        } catch {
            errorMessage = "保存に失敗しました: \(error.localizedDescription)"
        }
    }
    
    private func playAudio(data: Data, format: String) throws {
        // データが空でないことを確認
        guard !data.isEmpty else {
            throw NSError(domain: "AudioPlayback", code: -1, userInfo: [NSLocalizedDescriptionKey: "音声データが空です"])
        }
        
        // 一時ファイルに保存してから再生（フォーマットに関係なく動作するように）
        let fileExtension = format.lowercased() == "wav" ? "wav" : "mp3"
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        
        do {
            // オーディオセッションを再設定
            try configureAudioSession()
            
            // データを一時ファイルに書き込む
            try data.write(to: tempURL)
            
            // ファイルが正しく書き込まれたことを確認
            guard FileManager.default.fileExists(atPath: tempURL.path) else {
                throw NSError(domain: "AudioPlayback", code: -1, userInfo: [NSLocalizedDescriptionKey: "一時ファイルの作成に失敗しました"])
            }
            
            // ファイルサイズを確認
            let fileSize = try FileManager.default.attributesOfItem(atPath: tempURL.path)[.size] as? Int64 ?? 0
            guard fileSize > 0 else {
                throw NSError(domain: "AudioPlayback", code: -1, userInfo: [NSLocalizedDescriptionKey: "一時ファイルが空です"])
            }
            
            // WAV形式の場合、Fish Audio SDKが生成する形式がiOSでサポートされていない可能性があるため、
            // WAV形式を選択した場合はエラーメッセージを表示してMP3形式を推奨
            if format.lowercased() == "wav" {
                throw NSError(domain: "AudioPlayback", code: -1, userInfo: [NSLocalizedDescriptionKey: "WAV形式は現在サポートされていません。MP3形式を使用してください。"])
            }
            
            // MP3形式でAVAudioPlayerを使用
            try playAudioWithPlayer(url: tempURL)
            
            // 再生完了後に一時ファイルを削除（音声の長さを考慮して少し長めに待つ）
            // 実際の再生時間は非同期で処理されるため、十分な時間を確保
            DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
                try? FileManager.default.removeItem(at: tempURL)
            }
        } catch let error as NSError {
            // エラー時も一時ファイルを削除
            try? FileManager.default.removeItem(at: tempURL)
            // 既にNSErrorの場合はそのまま再スロー
            if error.domain == "AudioPlayback" {
                throw error
            }
            // その他のエラーは詳細を付けて再スロー
            throw NSError(domain: "AudioPlayback", code: -1, userInfo: [NSLocalizedDescriptionKey: "音声の再生に失敗しました: \(error.localizedDescription)"])
        }
    }
    
    private func playAudioWithPlayer(url: URL) throws {
        // 既存のプレーヤーを停止
        audioPlayer?.stop()
        audioPlayer = nil
        
        // ファイルの存在とサイズを確認
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw NSError(domain: "AudioPlayback", code: -1, userInfo: [NSLocalizedDescriptionKey: "音声ファイルが見つかりません"])
        }
        
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        guard fileSize > 0 else {
            throw NSError(domain: "AudioPlayback", code: -1, userInfo: [NSLocalizedDescriptionKey: "音声ファイルが空です（サイズ: \(fileSize) bytes）"])
        }
        
        // AVAudioPlayerで再生（MP3とWAVの両方をサポート）
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
        } catch let error as NSError {
            // より詳細なエラー情報を提供
            let errorMessage = "音声ファイルの読み込みに失敗しました: \(error.localizedDescription) (コード: \(error.code), ドメイン: \(error.domain))"
            throw NSError(domain: "AudioPlayback", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        guard let player = audioPlayer else {
            throw NSError(domain: "AudioPlayback", code: -1, userInfo: [NSLocalizedDescriptionKey: "音声プレーヤーの初期化に失敗しました"])
        }
        
        // プレーヤーが有効か確認
        let duration = player.duration
        guard duration > 0 else {
            // ファイル形式の情報を取得してエラーメッセージに含める
            let formatInfo = "ファイルサイズ: \(fileSize) bytes, 再生時間: \(duration)秒"
            throw NSError(domain: "AudioPlayback", code: -1, userInfo: [NSLocalizedDescriptionKey: "音声ファイルが無効です（長さが0）。\(formatInfo)。ファイル形式がサポートされていない可能性があります。"])
        }
        
        // 再生の準備
        guard player.prepareToPlay() else {
            throw NSError(domain: "AudioPlayback", code: -1, userInfo: [NSLocalizedDescriptionKey: "音声の再生準備に失敗しました。ファイル形式がサポートされていない可能性があります。"])
        }
        
        // 再生を開始
        guard player.play() else {
            throw NSError(domain: "AudioPlayback", code: -1, userInfo: [NSLocalizedDescriptionKey: "音声の再生に失敗しました。オーディオセッションの設定を確認してください。"])
        }
    }
    
    private func playAudioWithEngine(url: URL) throws {
        // 既存のエンジンを停止
        audioEngine?.stop()
        audioPlayerNode?.stop()
        audioEngine = nil
        audioPlayerNode = nil
        audioFile = nil
        
        // まずAVAudioFileで読み込みを試みる
        var file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch let error as NSError {
            // AVAudioFileの初期化に失敗した場合、詳細なエラー情報を提供
            let errorMessage = "音声ファイルの読み込みに失敗しました: \(error.localizedDescription) (コード: \(error.code))"
            throw NSError(domain: "AudioPlayback", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        // ファイルが有効か確認
        let fileLength = file.length
        guard fileLength > 0 else {
            // ファイルの詳細情報を取得
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            let formatInfo = "ファイルサイズ: \(fileSize) bytes, フレーム数: \(fileLength)"
            throw NSError(domain: "AudioPlayback", code: -1, userInfo: [NSLocalizedDescriptionKey: "音声ファイルが無効です（長さが0）。\(formatInfo)"])
        }
        
        // ファイル形式の情報を取得
        let processingFormat = file.processingFormat
        
        // AVAudioEngineを初期化
        let engine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        
        // エンジンにプレーヤーノードを接続
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: processingFormat)
        
        // エンジンを開始
        do {
            try engine.start()
        } catch {
            throw NSError(domain: "AudioPlayback", code: -1, userInfo: [NSLocalizedDescriptionKey: "オーディオエンジンの開始に失敗しました: \(error.localizedDescription)"])
        }
        
        // 音声を再生
        playerNode.scheduleFile(file, at: nil) { [weak self] in
            // 再生完了後の処理
            DispatchQueue.main.async { [weak self] in
                self?.audioEngine?.stop()
                self?.audioPlayerNode?.stop()
                self?.audioEngine = nil
                self?.audioPlayerNode = nil
                self?.audioFile = nil
            }
        }
        
        // プレーヤーノードを開始
        playerNode.play()
        
        // インスタンスを保持
        audioEngine = engine
        audioPlayerNode = playerNode
        audioFile = file
    }
    
    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true, options: [])
    }
    
    private func localFileURL(for item: TTSHistoryItem) -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = documents.appendingPathComponent(historyFolderName, isDirectory: true)
        return directory.appendingPathComponent(item.file_name)
    }
}

