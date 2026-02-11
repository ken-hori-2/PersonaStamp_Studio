//
//  TTSView.swift
//  RendVu
//
//  Created on 2025-11-23.
//

import SwiftUI
import AVFoundation

struct TTSView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = TTSViewModel()
    @FocusState private var isTextEditorFocused: Bool
    @State private var showEmotionPicker = false
    @State private var selectedEmotionTag: EmotionTag?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("テキスト入力")) {
                    TextEditor(text: $viewModel.text)
                        .frame(height: 150)
                        .focused($isTextEditorFocused)
                    
                    // 文字数カウント表示
                    HStack {
                        Spacer()
                        Text("\(viewModel.text.count)/30")
                            .font(.caption)
                            .foregroundColor(viewModel.text.count > 30 ? .red : .secondary)
                    }
                    
                    // 感情タグ挿入ボタン
                    Button(action: {
                        showEmotionPicker = true
                    }) {
                        HStack {
                            Image(systemName: "face.smiling")
                            Text("感情タグを挿入")
                        }
                        .font(.subheadline)
                    }
                    
                    // 使用中の感情タグ表示
                    Group {
                        let usedTags = EmotionTagHelper.extractTags(from: viewModel.text)
                        if !usedTags.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("使用中の感情タグ:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(usedTags) { tag in
                                            Text(tag.name)
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.blue.opacity(0.2))
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("設定")) {
                    Picker("声モデル", selection: $viewModel.selectedModelId) {
                        Text("デフォルト").tag(nil as String?)
                        ForEach(viewModel.availableModels) { model in
                            Text(model.reference_name).tag(model.id as String?)
                        }
                    }
                    
                    Picker("出力形式", selection: $viewModel.format) {
                        Text("MP3").tag("mp3")
                        // WAV形式はFish Audio SDKが生成する形式がiOSでサポートされていないため、一時的に無効化
                        // Text("WAV").tag("wav")
                    }
                    
                    VStack(alignment: .leading) {
                        Text("速度: \(viewModel.speed, specifier: "%.1f")")
                        Slider(value: $viewModel.speed, in: 0.5...2.0, step: 0.1)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("音量: \(viewModel.volume)")
                        Slider(value: Binding(
                            get: { Double(viewModel.volume) },
                            set: { viewModel.volume = Int($0) }
                        ), in: -20...20, step: 1)
                    }
                }
                
                Section {
                    Button(action: {
                        Task {
                            await viewModel.generateTTS(authManager: authManager)
                        }
                    }) {
                        HStack {
                            if viewModel.isGenerating {
                                ProgressView()
                            } else {
                                Image(systemName: "play.circle.fill")
                                Text("音声生成")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(viewModel.text.isEmpty || viewModel.isGenerating)
                }
                
                Section(header: Text("最新の生成履歴 (最大10件)")) {
                    if viewModel.isLoadingHistory && viewModel.history.isEmpty {
                        ProgressView("読み込み中…")
                    } else if viewModel.history.isEmpty {
                        Text("まだ履歴がありません")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.history) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.text)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                Text("生成日: \(item.created_at)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack {
                                    Button {
                                        Task {
                                            await viewModel.playHistory(item: item, authManager: authManager)
                                        }
                                    } label: {
                                        Label("再生", systemImage: "play.circle")
                                    }
                                    
                                    Button {
                                        Task {
                                            await viewModel.saveHistoryToFiles(item: item, authManager: authManager)
                                        }
                                    } label: {
                                        Label("保存", systemImage: "square.and.arrow.down")
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                if let infoMessage = viewModel.infoMessage {
                    Section {
                        Text(infoMessage)
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("TTS")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") {
                        isTextEditorFocused = false
                    }
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadModels(authManager: authManager)
                    await viewModel.loadHistory(authManager: authManager)
                }
            }
            .refreshable {
                await viewModel.loadHistory(authManager: authManager)
            }
            .sheet(isPresented: $showEmotionPicker) {
                EmotionPickerView(
                    selectedTag: $selectedEmotionTag,
                    text: $viewModel.text,
                    isPresented: $showEmotionPicker
                )
            }
            .alert("保存完了", isPresented: $viewModel.showSaveSuccessAlert) {
                Button("OK") {
                    viewModel.showSaveSuccessAlert = false
                }
            } message: {
                Text(viewModel.saveSuccessAlertMessage)
            }
        }
    }
}

#Preview {
    TTSView()
        .environmentObject(AuthManager())
}

