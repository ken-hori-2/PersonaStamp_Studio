//
//  VoiceCloneView.swift
//  RendVu
//
//  Created on 2025-11-23.
//

import SwiftUI
import AVFoundation

struct VoiceCloneView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = VoiceCloneViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 説明
                Text("音声サンプルを録音して、あなたの声をクローンします")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
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
                            .font(.system(size: 50))
                        Text(viewModel.isRecording ? "録音を停止" : "録音を開始")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isRecording ? Color.red : Color.blue)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(viewModel.isProcessing)
                
                // 録音時間表示
                if viewModel.isRecording {
                    Text("録音中: \(viewModel.recordingTimeString)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // モデル名入力
                if viewModel.hasRecordedAudio {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("モデル名")
                            .font(.headline)
                        TextField("例: my_voice", text: $viewModel.modelName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
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
                
                Spacer()
            }
            .navigationTitle("Voice Clone")
            .onAppear {
                viewModel.setupAudioRecorder()
            }
        }
    }
}

#Preview {
    VoiceCloneView()
        .environmentObject(AuthManager())
}

