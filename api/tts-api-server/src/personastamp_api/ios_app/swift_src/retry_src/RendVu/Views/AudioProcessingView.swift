//
//  AudioProcessingView.swift
//  RendVu
//
//  Created on 2025-01-XX.
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct AudioProcessingView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = AudioProcessingViewModel()
    @State private var audioPlayer: AVAudioPlayer?
    
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
                // 説明
                VStack(spacing: 8) {
                    Text("音声ファイルからボーカルを抽出し、無音区間を削除します")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("⚠️ 音源分離処理には数分かかる場合があります")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // ファイル選択ボタン
                Button(action: {
                    viewModel.selectAudioFile()
                }) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 30))
                        Text("音声ファイルを選択")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(viewModel.isProcessing)
                
                // 選択されたファイル表示
                if let selectedFile = viewModel.selectedAudioFile {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("ファイルが選択されました")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(selectedFile.lastPathComponent)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal)
                }
                
                // 音声処理設定
                if viewModel.selectedAudioFile != nil {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("処理設定")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Toggle("🎵 音源分離（ボーカル抽出）", isOn: $viewModel.separateVocals)
                            .font(.subheadline)
                            .disabled(viewModel.isProcessing)
                            .padding(.horizontal)
                        
                        if viewModel.separateVocals {
                            Text("⚠️ 音源分離は重い処理のため、Render.comの無料プランでは動作しない可能性があります")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.horizontal)
                        }
                        
                        Toggle("🔇 無音区間削除", isOn: $viewModel.removeSilence)
                            .font(.subheadline)
                            .disabled(viewModel.isProcessing)
                            .padding(.horizontal)
                        
                        // 分離モデル選択
                        if viewModel.separateVocals {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("分離モデル")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Picker("分離モデル", selection: $viewModel.separationModel) {
                                    Text("htdemucs（推奨）").tag("htdemucs")
                                    Text("htdemucs_ft").tag("htdemucs_ft")
                                    Text("mdx_extra").tag("mdx_extra")
                                    Text("mdx_extra_q").tag("mdx_extra_q")
                                }
                                .pickerStyle(.menu)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                    
                    // 処理実行ボタン
                    Button(action: {
                        Task {
                            await viewModel.processAudio(authManager: authManager)
                        }
                    }) {
                        HStack {
                            if viewModel.isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "wand.and.stars")
                                Text("音声処理を実行")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isProcessing ? Color.gray : Color.green)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .disabled(viewModel.isProcessing)
                }
                
                // 処理結果
                if let processedData = viewModel.processedAudioData {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("処理完了")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        // ボーカル音声がある場合は優先表示
                        if let vocalsData = viewModel.vocalsAudioData {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("🎤 ボーカル音声（推奨）")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                
                                HStack {
                                    Button(action: {
                                        playAudio(data: vocalsData)
                                    }) {
                                        HStack {
                                            Image(systemName: "play.circle.fill")
                                            Text("再生")
                                        }
                                        .font(.subheadline)
                                    }
                                    
                                    Button(action: {
                                        viewModel.vocalsAudioData = vocalsData
                                        viewModel.saveProcessedAudio()
                                    }) {
                                        HStack {
                                            Image(systemName: "square.and.arrow.down")
                                            Text("保存")
                                        }
                                        .font(.subheadline)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            Divider()
                                .padding(.horizontal)
                        }
                        
                        // 処理済み音声
                        VStack(alignment: .leading, spacing: 8) {
                            Text("🎵 処理済み音声")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Button(action: {
                                    playAudio(data: processedData)
                                }) {
                                    HStack {
                                        Image(systemName: "play.circle.fill")
                                        Text("再生")
                                    }
                                    .font(.subheadline)
                                }
                                
                                Button(action: {
                                    viewModel.processedAudioData = processedData
                                    viewModel.saveProcessedAudio()
                                }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.down")
                                        Text("保存")
                                    }
                                    .font(.subheadline)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // リセットボタン
                        Button(action: {
                            viewModel.reset()
                            audioPlayer?.stop()
                            audioPlayer = nil
                        }) {
                            Text("新しいファイルを処理")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                
                // エラーメッセージ
                if let errorMessage = viewModel.errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("エラー")
                                .font(.headline)
                                .foregroundColor(.red)
                        }
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
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
        .navigationTitle("音声処理")
        .navigationBarTitleDisplayMode(.large)
        .alert("保存完了", isPresented: $viewModel.showSaveSuccessAlert) {
            Button("OK") {
                viewModel.showSaveSuccessAlert = false
            }
        } message: {
            Text(viewModel.saveSuccessAlertMessage)
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
                    guard url.startAccessingSecurityScopedResource() else {
                        viewModel.errorMessage = "ファイルへのアクセス権が取得できませんでした"
                        return
                    }
                    defer { url.stopAccessingSecurityScopedResource() }
                    
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
    
    private func playAudio(data: Data) {
        do {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("m4a")
            
            try data.write(to: tempURL)
            audioPlayer = try AVAudioPlayer(contentsOf: tempURL)
            audioPlayer?.play()
        } catch {
            viewModel.errorMessage = "音声の再生に失敗しました: \(error.localizedDescription)"
        }
    }
}

#Preview {
    AudioProcessingView()
        .environmentObject(AuthManager())
}
