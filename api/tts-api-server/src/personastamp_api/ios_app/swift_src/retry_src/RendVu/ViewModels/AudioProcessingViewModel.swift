//
//  AudioProcessingViewModel.swift
//  RendVu
//
//  Created on 2025-01-XX.
//

import Foundation
import AVFoundation
import Combine
import UniformTypeIdentifiers

@MainActor
class AudioProcessingViewModel: ObservableObject {
    @Published var selectedAudioFile: URL?
    @Published var showDocumentPicker = false
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var processedAudioData: Data?
    @Published var vocalsAudioData: Data?
    @Published var showSaveSuccessAlert = false
    @Published var saveSuccessAlertMessage = ""
    
    // 音声処理設定
    // 注意: 音源分離は重い処理のため、Render.comの無料プランでは動作しない可能性があります
    @Published var separateVocals = false  // デフォルトを無効化（無料プラン対応）
    @Published var removeSilence = true
    @Published var separationModel = "htdemucs"
    @Published var silenceThresh: Float = -40.0
    @Published var minSilenceLen = 500
    @Published var keepSilence = 200
    
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
            
            selectedAudioFile = url
            errorMessage = nil
            processedAudioData = nil
            vocalsAudioData = nil
        } catch {
            errorMessage = "音声ファイルの読み込みに失敗しました: \(error.localizedDescription)"
        }
    }
    
    func processAudio(authManager: AuthManager) async {
        guard let audioURL = selectedAudioFile,
              let idToken = authManager.idToken else {
            errorMessage = "認証トークンまたは音声データが見つかりません"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let audioData = try Data(contentsOf: audioURL)
            
            let processResponse = try await APIClient.shared.processAudio(
                audioData: audioData,
                separateVocals: separateVocals,
                removeSilence: removeSilence,
                separationModel: separationModel,
                silenceThresh: silenceThresh,
                minSilenceLen: minSilenceLen,
                keepSilence: keepSilence,
                idToken: idToken
            )
            
            // 処理済み音声データを保存
            if let processedData = Data(base64Encoded: processResponse.output_audio_base64) {
                processedAudioData = processedData
            }
            
            // ボーカル音声データを保存（音源分離した場合）
            if let vocalsBase64 = processResponse.vocals_audio_base64,
               let vocalsData = Data(base64Encoded: vocalsBase64) {
                vocalsAudioData = vocalsData
            }
            
            successMessage = processResponse.message
        } catch {
            // エラーの種類に応じて適切なメッセージを表示
            if let apiError = error as? APIError {
                switch apiError {
                case .httpError(let code):
                    if code == 502 {
                        errorMessage = "サーバーが一時的に利用できません（502 Bad Gateway）。\n\n音源分離処理には時間がかかるため、サーバーのタイムアウトが発生している可能性があります。\n\n対処方法：\n・しばらく待ってから再度お試しください\n・ファイルサイズを小さくする\n・音源分離を無効にして無音区間削除のみを試す"
                    } else if code == 503 {
                        errorMessage = "サーバーが一時的に過負荷です（503 Service Unavailable）。\n\nしばらく待ってから再度お試しください。"
                    } else if code == 504 {
                        errorMessage = "サーバーの処理がタイムアウトしました（504 Gateway Timeout）。\n\n音源分離処理には時間がかかるため、もう一度お試しください。"
                    } else {
                        errorMessage = apiError.localizedDescription
                    }
                default:
                    errorMessage = apiError.localizedDescription
                }
            } else if let urlError = error as? URLError, urlError.code == .timedOut {
                errorMessage = "音声処理がタイムアウトしました。\n\n音源分離処理には時間がかかることがあります。もう一度お試しください。"
            } else {
                errorMessage = "音声処理に失敗しました: \(error.localizedDescription)"
            }
        }
        
        isProcessing = false
    }
    
    func saveProcessedAudio() {
        guard let audioData = vocalsAudioData ?? processedAudioData else {
            errorMessage = "保存する音声データがありません"
            return
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "processed_audio_\(Date().timeIntervalSince1970).m4a"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try audioData.write(to: fileURL, options: .atomic)
            saveSuccessAlertMessage = """
保存しました！

ファイル名: \(fileName)

「ファイル」アプリ >「このiPhone内」> Re:ndVu で確認できます。
"""
            showSaveSuccessAlert = true
        } catch {
            errorMessage = "保存に失敗しました: \(error.localizedDescription)"
        }
    }
    
    func reset() {
        selectedAudioFile = nil
        processedAudioData = nil
        vocalsAudioData = nil
        errorMessage = nil
        successMessage = nil
    }
}
