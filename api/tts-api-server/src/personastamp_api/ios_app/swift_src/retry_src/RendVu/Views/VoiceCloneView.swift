//
//  VoiceCloneView.swift
//  RendVu
//
//  Created on 2025-11-23.
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct VoiceCloneView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = VoiceCloneViewModel()
    
    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    contentView
                }
            } else {
        NavigationView {
                    contentView
                }
            }
        }
    }
    
    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 説明（常に表示）
                Text("音声サンプルを録音またはファイルから選択して、あなたの声をクローンします（最大1分）")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top)
                
                // 録音ボタンとファイル選択ボタン
                HStack(spacing: 12) {
                    // 録音ボタン
                    Button(action: {
                        if viewModel.isRecording {
                            viewModel.stopRecording()
                        } else {
                            viewModel.startRecording()
                        }
                    }) {
                        HStack {
                            Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 30))
                            Text(viewModel.isRecording ? "停止" : "録音")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isRecording ? Color.red : Color.blue)
                        .cornerRadius(10)
                    }
                    .disabled(viewModel.isProcessing)
                    
                    // ファイル選択ボタン
                    Button(action: {
                        viewModel.selectAudioFile()
                    }) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 30))
                            Text("ファイル")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(10)
                    }
                    .disabled(viewModel.isProcessing)
                }
                .padding(.horizontal)
                
                // 録音時間表示
                if viewModel.isRecording {
                    VStack(spacing: 4) {
                        Text("録音中: \(viewModel.recordingTimeString)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("最大1分まで録音できます")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                
                // 選択されたファイル表示
                if viewModel.selectedAudioFile != nil {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("ファイルが選択されました")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // モデル名入力と文字起こし
                if viewModel.hasRecordedAudio {
                    VStack(alignment: .leading, spacing: 16) {
                        // 自動文字起こし設定
                        Toggle("🎤 自動文字起こし（推奨）", isOn: $viewModel.autoTranscribeEnabled)
                            .font(.subheadline)
                        
                        // 文字起こしエリア
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("📝 文字起こし（推奨）")
                                    .font(.headline)
                                if viewModel.isTranscribing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                            Text("音声クローンの精度向上のため、文字起こしの入力をおすすめします")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextEditor(text: $viewModel.transcription)
                                .frame(height: 100)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .disabled(viewModel.isTranscribing)
                            
                            if viewModel.isTranscribing {
                                HStack {
                                    ProgressView()
                                    Text("文字起こし中...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else if !viewModel.transcription.isEmpty {
                                Button(action: {
                                    Task {
                                        await viewModel.transcribeAudio()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("再文字起こし")
                                    }
                                    .font(.caption)
                                }
                            }
                        }
                        
                        // モデル名入力
                    VStack(alignment: .leading, spacing: 8) {
                        Text("モデル名")
                            .font(.headline)
                        TextField("例: my_voice", text: $viewModel.modelName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    .padding(.horizontal)
                    
                    // クローン実行ボタン
                    Button(action: {
                        Task {
                            await viewModel.cloneVoice(authManager: authManager)
                        }
                    }) {
                        HStack {
                            if viewModel.isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "waveform.path")
                                Text("Voice Cloningを実行")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.modelName.isEmpty ? Color.gray : Color.green)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .disabled(viewModel.modelName.isEmpty || viewModel.isProcessing)
                }
                
                // エラーメッセージ
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }
                
                // 成功メッセージ
                if let successMessage = viewModel.successMessage {
                    Text(successMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding()
                }
            }
            .padding(.bottom)
            }
            .navigationTitle("Voice Clone")
        .navigationBarTitleDisplayMode(.large)
        .alert("成功", isPresented: $viewModel.showSuccessAlert) {
            Button("OK") {
                viewModel.showSuccessAlert = false
            }
        } message: {
            Text(viewModel.successAlertMessage)
        }
            .onAppear {
                viewModel.setupAudioRecorder()
        }
        .fileImporter(
            isPresented: $viewModel.showDocumentPicker,
            allowedContentTypes: {
                var types: [UTType] = [.audio, .mpeg4Audio]
                if let m4a = UTType(filenameExtension: "m4a") { types.append(m4a) }
                if let mp3 = UTType(filenameExtension: "mp3") { types.append(mp3) }
                if let wav = UTType(filenameExtension: "wav") { types.append(wav) }
                return types
            }(),
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    // セキュリティスコープ付きURLのアクセス権を取得
                    guard url.startAccessingSecurityScopedResource() else {
                        viewModel.errorMessage = "ファイルへのアクセス権が取得できませんでした"
                        return
                    }
                    defer { url.stopAccessingSecurityScopedResource() }
                    
                    // 一時ディレクトリにコピー
                    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let destinationURL = documentsPath.appendingPathComponent("selected_audio_\(Date().timeIntervalSince1970).\(url.pathExtension)")
                    
                    do {
                        try FileManager.default.copyItem(at: url, to: destinationURL)
                        viewModel.handleSelectedAudioFile(destinationURL)
                    } catch {
                        viewModel.errorMessage = "ファイルのコピーに失敗しました: \(error.localizedDescription)"
                    }
                }
            case .failure(let error):
                viewModel.errorMessage = "ファイル選択に失敗しました: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    VoiceCloneView()
        .environmentObject(AuthManager())
}

