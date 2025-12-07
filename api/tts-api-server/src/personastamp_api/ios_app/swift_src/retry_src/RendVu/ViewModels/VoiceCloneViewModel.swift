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

@MainActor
class VoiceCloneViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var hasRecordedAudio = false
    @Published var modelName = ""
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var recordingTimeString = "00:00"
    
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
    }
    
    private func updateRecordingTime() {
        guard let startTime = recordingStartTime else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        recordingTimeString = String(format: "%02d:%02d", minutes, seconds)
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
            let response = try await APIClient.shared.cloneVoice(
                audioData: audioData,
                referenceName: modelName,
                idToken: idToken
            )
            
            successMessage = "Voice Cloningが完了しました！モデルID: \(response.model_id)"
            modelName = ""
            hasRecordedAudio = false
            
            // 録音ファイルを削除
            try? FileManager.default.removeItem(at: audioURL)
            self.audioURL = nil
            
        } catch {
            errorMessage = "エラー: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
}

