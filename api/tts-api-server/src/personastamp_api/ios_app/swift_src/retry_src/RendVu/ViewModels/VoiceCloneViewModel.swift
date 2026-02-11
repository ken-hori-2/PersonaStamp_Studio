//
//  VoiceCloneViewModel.swift
//  RendVu
//
//  Created on 2025-11-23.
//

import Foundation
import AVFoundation
import Combine
import AVFAudio
import Speech

@MainActor
class VoiceCloneViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var hasRecordedAudio = false
    @Published var modelName = ""
    @Published var transcription = ""
    @Published var isTranscribing = false
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var showSuccessAlert = false
    @Published var successAlertMessage = ""
    @Published var recordingTimeString = "00:00"
    @Published var autoTranscribeEnabled = true
    @Published var selectedAudioFile: URL?
    @Published var showDocumentPicker = false
    
    private var audioRecorder: AVAudioRecorder?
    private var audioURL: URL?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    
    func setupAudioRecorder() {
        // マイクの使用許可をリクエスト（iOS 17.0以降の新しいAPI）
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                if !granted {
                    Task { @MainActor [weak self] in
                        self?.errorMessage = "マイクの使用許可が必要です"
                    }
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                if !granted {
                    Task { @MainActor [weak self] in
                        self?.errorMessage = "マイクの使用許可が必要です"
                    }
                }
            }
        }
    }
    
    func startRecording() {
        // 既存のファイル選択をクリア
        if let existingURL = audioURL, existingURL.path.contains("selected_audio_") {
            try? FileManager.default.removeItem(at: existingURL)
        }
        selectedAudioFile = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true)
        } catch {
            errorMessage = "録音の準備に失敗しました: \(error.localizedDescription)"
            return
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
        audioURL = audioFilename
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            isRecording = true
            hasRecordedAudio = false
            recordingStartTime = Date()
            
            // タイマー開始
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self.updateRecordingTime()
                }
            }
        } catch {
            errorMessage = "録音の開始に失敗しました: \(error.localizedDescription)"
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        hasRecordedAudio = true
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // 自動文字起こしが有効な場合、文字起こしを実行
        if autoTranscribeEnabled {
            Task {
                await transcribeAudio()
            }
        }
    }
    
    func transcribeAudio() async {
        guard let audioURL = audioURL else { return }
        
        // 音声認識の許可を確認
        let currentStatus = SFSpeechRecognizer.authorizationStatus()
        let authorizationStatus: SFSpeechRecognizerAuthorizationStatus
        
        if currentStatus == .notDetermined {
            // 許可をリクエスト
            authorizationStatus = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
        } else {
            authorizationStatus = currentStatus
        }
        
        guard authorizationStatus == .authorized else {
            errorMessage = "音声認識の許可が必要です。設定から許可してください。"
            return
        }
        
        let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "日本語の音声認識が利用できません"
            return
        }
        
        isTranscribing = true
        errorMessage = nil
        
        do {
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.shouldReportPartialResults = false
            
            // 非同期で音声認識を実行
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                var recognitionTask: SFSpeechRecognitionTask?
                
                recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                    if let error = error {
                        recognitionTask?.cancel()
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    if let result = result, result.isFinal {
                        let transcriptionText = result.bestTranscription.formattedString
                        recognitionTask?.cancel()
                        continuation.resume(returning: transcriptionText)
                    }
                }
                
                // タイムアウト処理（30秒）
                Task {
                    try? await Task.sleep(nanoseconds: 30_000_000_000)
                    if recognitionTask?.state != .completed && recognitionTask?.state != .canceling {
                        recognitionTask?.cancel()
                        continuation.resume(throwing: NSError(domain: "TranscriptionTimeout", code: -1, userInfo: [NSLocalizedDescriptionKey: "文字起こしがタイムアウトしました"]))
                    }
                }
            }
            
            if !result.isEmpty {
                transcription = result
            } else {
                errorMessage = "文字起こし結果が空でした。手動で入力してください。"
            }
        } catch {
            errorMessage = "文字起こしに失敗しました: \(error.localizedDescription)"
        }
        
        isTranscribing = false
    }
    
    private func updateRecordingTime() {
        guard let startTime = recordingStartTime else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        recordingTimeString = String(format: "%02d:%02d", minutes, seconds)
        
        // 1分（60秒）を超えたら自動停止
        if elapsed >= 60.0 {
            stopRecording()
            errorMessage = "録音時間は最大1分までです。1分で自動停止しました。"
        }
    }
    
    func selectAudioFile() {
        showDocumentPicker = true
    }
    
    func handleSelectedAudioFile(_ url: URL) {
        // ファイルの長さをチェック（最大1分）
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
            
            if duration > 60.0 {
                errorMessage = "選択した音声ファイルは1分を超えています（\(String(format: "%.1f", duration))秒）。1分以内の音声ファイルを選択してください。"
                return
            }
            
            // 既存の録音ファイルをクリア
            if let existingURL = audioURL, existingURL.path.contains("recording_") {
                try? FileManager.default.removeItem(at: existingURL)
            }
            
            selectedAudioFile = url
            audioURL = url
            hasRecordedAudio = true
            errorMessage = nil
            
            // 自動文字起こしが有効な場合、文字起こしを実行
            if autoTranscribeEnabled {
                Task {
                    await transcribeAudio()
                }
            }
        } catch {
            errorMessage = "音声ファイルの読み込みに失敗しました: \(error.localizedDescription)"
        }
    }
    
    func cloneVoice(authManager: AuthManager) async {
        guard let audioURL = audioURL,
              let idToken = authManager.idToken else {
            errorMessage = "認証トークンまたは音声データが見つかりません"
            return
        }
        
        guard !modelName.isEmpty else {
            errorMessage = "モデル名を入力してください"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let audioData = try Data(contentsOf: audioURL)
            let transcriptionText = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
            let response = try await APIClient.shared.cloneVoice(
                audioData: audioData,
                referenceName: modelName,
                transcription: transcriptionText.isEmpty ? nil : transcriptionText,
                idToken: idToken
            )
            
            successMessage = "Voice Cloningが完了しました！モデルID: \(response.model_id)"
            successAlertMessage = "Voice Cloningが完了しました！\n\nモデルID: \(response.model_id)\n\nこのモデルを使用してTTSを生成できます。"
            showSuccessAlert = true
            modelName = ""
            transcription = ""
            hasRecordedAudio = false
            selectedAudioFile = nil
            
            // 録音ファイルを削除（ファイル選択の場合は削除しない）
            if let url = self.audioURL {
                // 録音ファイルの場合のみ削除
                if url.path.contains("recording_") || url.path.contains("selected_audio_") {
                    try? FileManager.default.removeItem(at: url)
                }
            }
            self.audioURL = nil
            
        } catch {
            errorMessage = "エラー: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
}

