//
//  ContentView.swift
//  VoiceCreator
//
//  Created on 2025-01-27.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var viewModel = AudioSeparationViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // ファイル選択セクション
                VStack(alignment: .leading, spacing: 12) {
                    Text("音源ファイル")
                        .font(.headline)
                    
                    if let selectedFile = viewModel.selectedFile {
                        HStack {
                            Image(systemName: "music.note")
                            Text(selectedFile.lastPathComponent)
                                .lineLimit(1)
                            Spacer()
                            Button("変更") {
                                viewModel.selectAudioFile()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        Button(action: {
                            viewModel.selectAudioFile()
                        }) {
                            HStack {
                                Image(systemName: "folder")
                                Text("音源ファイルを選択")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                }
                
                // モデル選択セクション
                VStack(alignment: .leading, spacing: 12) {
                    Text("分離タイプ")
                        .font(.headline)
                    
                    Picker("分離タイプ", selection: $viewModel.selectedStemType) {
                        Text("2stems (ボーカル・伴奏)").tag(StemType.two)
                        Text("4stems (ボーカル・ドラム・ベース・その他)").tag(StemType.four)
                        Text("5stems (ボーカル・ドラム・ベース・ピアノ・その他)").tag(StemType.five)
                    }
                    .pickerStyle(.menu)
                }
                
                // 実行ボタン
                Button(action: {
                    Task {
                        await viewModel.separateAudio()
                    }
                }) {
                    HStack {
                        if viewModel.isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(viewModel.isProcessing ? "処理中..." : "音源分離を実行")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.canProcess ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(!viewModel.canProcess || viewModel.isProcessing)
                
                // 進捗表示
                if viewModel.isProcessing {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("進捗: \(viewModel.currentProgress)/\(viewModel.totalProgress)")
                            .font(.subheadline)
                        ProgressView(value: Double(viewModel.currentProgress), total: Double(viewModel.totalProgress))
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // エラーメッセージ
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // 成功メッセージ
                if viewModel.isCompleted {
                    VStack(spacing: 12) {
                        Text("✅ 音源分離が完了しました！")
                            .foregroundColor(.green)
                        
                        if let outputURLs = viewModel.outputURLs {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("出力ファイル:")
                                    .font(.headline)
                                
                                ForEach(outputURLs.allURLs, id: \.self) { url in
                                    HStack {
                                        Image(systemName: "doc")
                                        Text(url.lastPathComponent)
                                            .font(.caption)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("音源分離")
            .fileImporter(
                isPresented: $viewModel.showFilePicker,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        viewModel.handleSelectedFile(url: url)
                    }
                case .failure(let error):
                    viewModel.errorMessage = "ファイル選択エラー: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

