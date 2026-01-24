//
//  TTSStampView.swift
//  stamp_creator
//
//  TTS機能を使ってスタンプ画像を作成するビュー
//

import SwiftUI
import AVFoundation
import Photos
import CoreMedia
import AVKit

struct TTSStampView: View {
    @State private var selectedImage: UIImage?
    @State private var textInput: String = ""
    @State private var showingImagePicker = false
    @State private var isGenerating = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var showingSaveAlert = false
    @State private var audioURL: URL?
    @State private var audioEngine: AVAudioEngine?
    @State private var audioPlayerNode: AVAudioPlayerNode?
    @State private var isPlaying = false
    @State private var isSaving = false
    @FocusState private var isTextEditorFocused: Bool
    @State private var generateButtonOpacity: Double = 1.0
    @State private var generateButtonTextOpacity: Double = 1.0
    @State private var pulseTimer: Timer?
    
    // AVSpeechSynthesizerを保持（解放を防ぐため）
    @State private var synthesizerHolder = SynthesizerHolder()
    
    
    var body: some View {
        ZStack {
            backgroundView
                .onTapGesture {
                    // 背景をタップしたときにキーボードを閉じる
                    isTextEditorFocused = false
                }
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        // 画像表示エリア
                        if let image = selectedImage {
                            VStack(spacing: 12) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 400)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
                            )
                            .padding(.horizontal)
                            .transition(.scale.combined(with: .opacity))
                            
                            // 画像変更ボタン
                            Button(action: {
                                showingImagePicker = true
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.title3)
                                    Text("Change Image")
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white.opacity(0.9))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .padding(.horizontal)
                        } else {
                            placeholderView
                                .onTapGesture {
                                    isTextEditorFocused = false
                                }
                        }
                        
                        // テキスト入力エリア（画像選択後のみ表示＝キーボード・Done が正常に動く状態にしてから出す）
                        if selectedImage != nil {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "text.bubble")
                                        .font(.title3)
                                        .foregroundColor(.white.opacity(0.8))
                                    Text("Text Input")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                    Spacer()
                                    if !textInput.isEmpty {
                                        Text("\(textInput.count) chars")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                                .padding(.horizontal)
                                
                                ZStack(alignment: .topLeading) {
                                    if textInput.isEmpty {
                                        Text("Enter text for TTS...")
                                            .foregroundColor(.white.opacity(0.4))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 20)
                                    }
                                    
                                    TextEditor(text: $textInput)
                                        .frame(minHeight: 120)
                                        .scrollContentBackground(.hidden)
                                        .padding(12)
                                        .background(Color.clear)
                                        .foregroundColor(.white)
                                        .focused($isTextEditorFocused)
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(
                                                    isTextEditorFocused 
                                                        ? LinearGradient(
                                                            colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                        : LinearGradient(
                                                            colors: [Color.white.opacity(0.3)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                    lineWidth: isTextEditorFocused ? 2 : 1
                                                )
                                        )
                                        .shadow(
                                            color: isTextEditorFocused 
                                                ? Color.blue.opacity(0.3)
                                                : Color.black.opacity(0.2),
                                            radius: isTextEditorFocused ? 12 : 8,
                                            x: 0,
                                            y: 4
                                        )
                                )
                                .padding(.horizontal)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isTextEditorFocused)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // テキスト入力エリア全体をタップ可能にする
                                }
                            }
                        }
                        
                        // 画像選択後のボタンエリア（text inputの下）
                        if selectedImage != nil {
                            actionButtonsAreaInScroll
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
        }
        .navigationTitle("TTS Stamp")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isTextEditorFocused = false
                }
                .foregroundColor(.blue)
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
        .alert(alertTitle, isPresented: $showingSaveAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - 背景ビュー
    
    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.08, blue: 0.18),
                Color(red: 0.15, green: 0.12, blue: 0.28)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - プレースホルダービュー
    
    private var placeholderView: some View {
        Button(action: {
            showingImagePicker = true
        }) {
            VStack(spacing: 20) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.pulse, options: .repeating)
                
                Text("Select Image")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Select an image to create a TTS stamp")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
            )
            .padding(.horizontal)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var actionButtonsAreaInScroll: some View {
        VStack(spacing: 14) {
            // TTS生成ボタン
            Button(action: {
                generateTTS()
            }) {
                HStack(spacing: 12) {
                    if isGenerating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "waveform.path")
                            .font(.title2)
                            .opacity(isGenerating || textInput.isEmpty ? 1.0 : generateButtonTextOpacity)
                    }
                    Text(isGenerating ? "Generating..." : "Generate TTS")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .opacity(isGenerating || textInput.isEmpty ? 1.0 : generateButtonTextOpacity)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: isGenerating || textInput.isEmpty
                                    ? [Color.gray.opacity(0.5), Color.gray.opacity(0.5)]
                                    : [Color.blue.opacity(0.9), Color.purple.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    isGenerating || textInput.isEmpty
                                        ? LinearGradient(
                                            colors: [Color.gray.opacity(0.3)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                        : LinearGradient(
                                            colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(
                            color: isGenerating || textInput.isEmpty
                                ? Color.clear
                                : Color.blue.opacity(0.3),
                            radius: 12,
                            x: 0,
                            y: 4
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isGenerating || textInput.isEmpty)
            .padding(.horizontal, 20)
            .opacity(isGenerating || textInput.isEmpty ? 1.0 : generateButtonOpacity)
            .onAppear {
                startPulseAnimation()
            }
            .onChange(of: isGenerating) { oldValue, newValue in
                if newValue || textInput.isEmpty {
                    stopPulseAnimation()
                } else {
                    startPulseAnimation()
                }
            }
            .onChange(of: textInput) { oldValue, newValue in
                if isGenerating || newValue.isEmpty {
                    stopPulseAnimation()
                } else {
                    startPulseAnimation()
                }
            }
            .onDisappear {
                stopPulseAnimation()
            }
            
            // 音声再生ボタン
            if audioURL != nil {
                Button(action: {
                    playAudio()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title2)
                            .symbolEffect(.bounce, value: isPlaying)
                        Text(isPlaying ? "Pause Audio" : "Play Audio")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                            LinearGradient(
                                colors: [
                                    Color.mint.opacity(0.85),
                                    Color.cyan.opacity(0.85)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                            .shadow(color: .mint.opacity(0.4), radius: 12, x: 0, y: 6)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // 保存ボタン
            if audioURL != nil {
                Button(action: {
                    saveStamp()
                }) {
                    HStack(spacing: 12) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.title2)
                        }
                        Text(isSaving ? "Saving..." : "Save Stamp")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: isSaving
                                        ? [Color.gray.opacity(0.5), Color.gray.opacity(0.5)]
                                        : [Color.indigo.opacity(0.9), Color.purple.opacity(0.9)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(
                                color: isSaving
                                    ? Color.clear
                                    : Color.indigo.opacity(0.5),
                                radius: 12,
                                x: 0,
                                y: 6
                            )
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isSaving)
                .padding(.horizontal, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - TTS生成
    
    private func generateTTS() {
        guard !textInput.isEmpty else {
            alertTitle = "Error"
            alertMessage = "Please enter text"
            showingAlert = true
            return
        }
        
        isGenerating = true
        
        Task {
            do {
                let url = try await synthesizeSpeech(text: textInput)
                await MainActor.run {
                    audioURL = url
                    isGenerating = false
                    alertTitle = "Success"
                    alertMessage = "TTS audio generated successfully"
                    showingAlert = true
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    alertTitle = "Error"
                    alertMessage = "Failed to generate TTS: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func synthesizeSpeech(text: String) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            // 非同期コンテキストで実行
            Task {
                // AVAudioSessionを設定
                do {
                    let audioSession = AVAudioSession.sharedInstance()
                    // playAndRecordカテゴリを使用（録音も可能にする）
                    try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                    print("✅ [TTS] Audio session configured")
                } catch {
                    print("❌ [TTS] Failed to set up audio session: \(error)")
                    continuation.resume(throwing: error)
                    return
                }
                
                // synthesizerを保持（StateObjectから取得）
                let synthesizer = synthesizerHolder.synthesizer
                
                // synthesizerの設定を変更
                synthesizer.usesApplicationAudioSession = true
                
                let utterance = AVSpeechUtterance(string: text)
                
                // 利用可能な日本語の声を確認
                let availableVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("ja") }
                if let japaneseVoice = availableVoices.first {
                    utterance.voice = japaneseVoice
                    print("🔊 [TTS] Using voice: \(japaneseVoice.name), language: \(japaneseVoice.language)")
                } else {
                    utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
                    print("⚠️ [TTS] Using default Japanese voice")
                }
                
                utterance.rate = 0.5
                utterance.pitchMultiplier = 1.0
                utterance.volume = 1.0
                
                // 一時ファイルのURLを作成（CAF形式で保存）
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("caf")
                
                print("🔊 [TTS] Starting speech synthesis for text: \(text.prefix(50))...")
                
                // 共有状態を管理するためのクラス
                class BufferHandler {
                    var audioFile: AVAudioFile?
                    var isFirstBuffer = true
                    var hasError = false
                    var bufferCount = 0
                    var totalFrames: AVAudioFrameCount = 0
                    var isFinished = false
                    var emptyBufferCount = 0
                    var lastBufferTime = Date()
                    let tempURL: URL
                    let continuation: CheckedContinuation<URL, Error>
                    
                    init(tempURL: URL, continuation: CheckedContinuation<URL, Error>) {
                        self.tempURL = tempURL
                        self.continuation = continuation
                    }
                }
                
                let handler = BufferHandler(tempURL: tempURL, continuation: continuation)
                
                // デリゲートを設定して完了を検知
                let delegate = TTSDelegate { finished in
                    handler.isFinished = finished
                    print("🔊 [TTS] Speech synthesis finished: \(finished)")
                }
                synthesizer.delegate = delegate
                
                // 少し待ってからwriteを呼び出す（セッションの準備を待つ）
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機
                
                // MainActorでwriteメソッドを呼び出す
                await MainActor.run {
                    print("🔊 [TTS] Calling write method...")
                    
                    // synthesizerの設定を確認
                    print("🔊 [TTS] Synthesizer usesApplicationAudioSession: \(synthesizer.usesApplicationAudioSession)")
                    print("🔊 [TTS] Utterance text: \(utterance.speechString)")
                    print("🔊 [TTS] Utterance voice: \(utterance.voice?.name ?? "nil")")
                    
                    synthesizer.write(utterance) { (buffer: AVAudioBuffer?) in
                        // コールバック内の処理を非同期で実行
                        Task {
                            print("🔊 [TTS] Buffer received: \(buffer != nil ? "Yes" : "No")")
                            
                            // バッファがnilの場合はスキップ
                            guard let buffer = buffer else {
                                print("⚠️ [TTS] Buffer is nil")
                                return
                            }
                            
                            guard let pcmBuffer = buffer as? AVAudioPCMBuffer else {
                                print("⚠️ [TTS] Buffer is not PCM buffer")
                                return
                            }
                            
                            print("🔊 [TTS] PCM Buffer - frameLength: \(pcmBuffer.frameLength), format: \(pcmBuffer.format)")
                            
                            // バッファが空の場合はスキップ（ただし、完了検知のためカウント）
                            guard pcmBuffer.frameLength > 0 else {
                                print("⚠️ [TTS] Buffer frameLength is 0 (empty buffer)")
                                handler.emptyBufferCount += 1
                                // 連続して空バッファが来た場合は完了とみなす
                                if handler.emptyBufferCount >= 2 {
                                    print("✅ [TTS] Received \(handler.emptyBufferCount) empty buffers, synthesis likely complete")
                                    handler.isFinished = true
                                }
                                return
                            }
                            
                            // 有効なバッファが来た場合は空バッファカウントをリセット
                            handler.emptyBufferCount = 0
                            handler.lastBufferTime = Date()
                            
                            do {
                                if handler.isFirstBuffer {
                                    // 初回バッファでファイルを作成
                                    let format = pcmBuffer.format
                                    print("🔊 [TTS] Creating audio file with format: \(format)")
                                    handler.audioFile = try AVAudioFile(forWriting: handler.tempURL, settings: format.settings)
                                    handler.isFirstBuffer = false
                                    print("✅ [TTS] Audio file created at: \(handler.tempURL.path)")
                                }
                                
                                guard let file = handler.audioFile else {
                                    print("⚠️ [TTS] Audio file is nil")
                                    return
                                }
                                
                                try file.write(from: pcmBuffer)
                                handler.bufferCount += 1
                                handler.totalFrames += pcmBuffer.frameLength
                                print("✅ [TTS] Buffer \(handler.bufferCount) written - frames: \(pcmBuffer.frameLength), total: \(handler.totalFrames)")
                            } catch {
                                print("❌ [TTS] Error writing buffer: \(error)")
                                if handler.isFirstBuffer && !handler.hasError {
                                    handler.hasError = true
                                    handler.continuation.resume(throwing: error)
                                }
                            }
                        }
                    }
                }
                
                // 完了を待機（より効率的に）
                // 音声の長さに基づいて待機時間を計算（最低3秒、最大10秒）
                let estimatedDuration = Double(text.count) * 0.15 // 見積もり
                let maxWaitTime = min(max(estimatedDuration + 2.0, 3.0), 10.0)
                
                print("🔊 [TTS] Waiting up to \(maxWaitTime) seconds for completion...")
                
                // 完了を待機（定期的にチェック）
                let startTime = Date()
                while !handler.isFinished && Date().timeIntervalSince(startTime) < maxWaitTime {
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2秒待機
                    
                    // 最後のバッファから一定時間経過した場合も完了とみなす
                    if handler.bufferCount > 0 && Date().timeIntervalSince(handler.lastBufferTime) > 0.5 {
                        print("✅ [TTS] No new buffers for 0.5 second, synthesis likely complete")
                        handler.isFinished = true
                        break
                    }
                }
                
                // 追加の待機（最後のバッファを確実に処理）
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3秒追加待機
                
                // 結果を返す
                if !handler.hasError && handler.bufferCount > 0 && handler.totalFrames > 0 {
                    if FileManager.default.fileExists(atPath: handler.tempURL.path) {
                        let fileSize = (try? FileManager.default.attributesOfItem(atPath: handler.tempURL.path)[.size] as? Int64) ?? 0
                        if fileSize > 0 {
                            print("✅ [TTS] Audio file completed - size: \(fileSize) bytes")
                            continuation.resume(returning: handler.tempURL)
                        } else {
                            print("⚠️ [TTS] Audio file is empty")
                            continuation.resume(throwing: NSError(domain: "TTSStamp", code: 4, userInfo: [NSLocalizedDescriptionKey: "Audio file is empty"]))
                        }
                    } else {
                        print("⚠️ [TTS] Audio file was not created")
                        continuation.resume(throwing: NSError(domain: "TTSStamp", code: 4, userInfo: [NSLocalizedDescriptionKey: "Audio file was not created"]))
                    }
                } else if !handler.hasError {
                    print("❌ [TTS] No audio data generated - Buffer count: \(handler.bufferCount), Total frames: \(handler.totalFrames)")
                    continuation.resume(throwing: NSError(domain: "TTSStamp", code: 3, userInfo: [NSLocalizedDescriptionKey: "No audio data was generated. Buffer count: \(handler.bufferCount), Total frames: \(handler.totalFrames)"]))
                }
            }
        }
    }
    
    // MARK: - 音声再生
    
    private func playAudio() {
        guard let url = audioURL else { return }
        
        if isPlaying {
            // 停止
            audioEngine?.stop()
            audioPlayerNode?.stop()
            audioEngine = nil
            audioPlayerNode = nil
            isPlaying = false
        } else {
            // 再生（AVAudioEngineを使用 - PCM形式を直接再生可能）
            do {
                // ファイルの存在確認
                guard FileManager.default.fileExists(atPath: url.path) else {
                    alertTitle = "Error"
                    alertMessage = "Audio file not found"
                    showingAlert = true
                    return
                }
                
                print("🔊 [Play] Opening audio file: \(url.path)")
                
                let audioFile = try AVAudioFile(forReading: url)
                let audioFormat = audioFile.processingFormat
                let audioFrameCount = UInt32(audioFile.length)
                
                print("🔊 [Play] Audio format: \(audioFormat), frame count: \(audioFrameCount)")
                
                guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: audioFrameCount) else {
                    alertTitle = "Error"
                    alertMessage = "Failed to create audio buffer"
                    showingAlert = true
                    return
                }
                
                try audioFile.read(into: audioBuffer)
                
                print("✅ [Play] Audio buffer created: \(audioBuffer.frameLength) frames")
                
                let engine = AVAudioEngine()
                let playerNode = AVAudioPlayerNode()
                
                engine.attach(playerNode)
                engine.connect(playerNode, to: engine.mainMixerNode, format: audioFormat)
                
                try engine.start()
                playerNode.scheduleBuffer(audioBuffer) {
                    DispatchQueue.main.async {
                        self.isPlaying = false
                        self.audioEngine = nil
                        self.audioPlayerNode = nil
                    }
                }
                
                playerNode.play()
                
                audioEngine = engine
                audioPlayerNode = playerNode
                isPlaying = true
                
                print("✅ [Play] Audio playback started")
            } catch {
                print("❌ [Play] Error: \(error)")
                alertTitle = "Error"
                alertMessage = "Failed to play audio: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
    
    // MARK: - スタンプ保存
    
    private func saveStamp() {
        guard let image = selectedImage,
              let audio = audioURL else {
            alertTitle = "Error"
            alertMessage = "Image and audio are required"
            showingSaveAlert = true
            return
        }
        
        isSaving = true
        
        Task {
            do {
                // 画像と音声を組み合わせた動画ファイルを作成
                let video = try await createVideoWithImageAndAudio(image: image, audioURL: audio)
                
                // 動画をフォトライブラリに保存
                try await saveVideoToPhotoLibrary(videoURL: video)
                
                await MainActor.run {
                    isSaving = false
                    alertTitle = "Success"
                    alertMessage = "Saved successfully"
                    showingSaveAlert = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    alertTitle = "Error"
                    alertMessage = "Failed to save: \(error.localizedDescription)"
                    showingSaveAlert = true
                }
            }
        }
    }
    
    // MARK: - 動画作成
    
    private func createVideoWithImageAndAudio(image: UIImage, audioURL: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    // 音声ファイルの存在確認
                    guard FileManager.default.fileExists(atPath: audioURL.path) else {
                        print("❌ [Video] Audio file does not exist at: \(audioURL.path)")
                        continuation.resume(throwing: NSError(domain: "TTSStamp", code: 1, userInfo: [NSLocalizedDescriptionKey: "Audio file does not exist"]))
                        return
                    }
                    
                    print("✅ [Video] Audio file exists at: \(audioURL.path)")
                    
                    // 音声の長さを取得
                    let audioAsset = AVAsset(url: audioURL)
                    
                    // 音声アセットが読み込めるか確認
                    let isReadable = try await audioAsset.load(.isReadable)
                    guard isReadable else {
                        print("❌ [Video] Audio asset is not readable")
                        continuation.resume(throwing: NSError(domain: "TTSStamp", code: 1, userInfo: [NSLocalizedDescriptionKey: "Audio asset is not readable"]))
                        return
                    }
                    
                    let audioDuration = try await audioAsset.load(.duration)
                    var duration = CMTimeGetSeconds(audioDuration)
                    
                    print("✅ [Video] Audio duration: \(duration) seconds")
                    
                    guard duration > 0 else {
                        continuation.resume(throwing: NSError(domain: "TTSStamp", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid audio duration"]))
                        return
                    }
                    
                    // 動画の長さは音声の長さに合わせる（制限なし）
                    let videoDuration = duration
                    
                    // 動画のサイズを設定（画像のサイズを使用、ただし最大1920x1080に制限）
                    var videoSize = image.size
                    let maxSize: CGFloat = 1920
                    if videoSize.width > maxSize || videoSize.height > maxSize {
                        let scale = min(maxSize / videoSize.width, maxSize / videoSize.height)
                        videoSize = CGSize(width: videoSize.width * scale, height: videoSize.height * scale)
                    }
                    
                    // サイズを整数に丸める
                    videoSize = CGSize(width: round(videoSize.width), height: round(videoSize.height))
                    
                    print("✅ [Video] Video size: \(videoSize)")
                    print("✅ [Video] Video duration: \(videoDuration)s (audio: \(duration)s)")
                    
                    // 動画ファイルのURLを作成
                    let outputURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("mov")
                    
                    print("✅ [Video] Output URL: \(outputURL.path)")
                    
                    // 既存のファイルを削除
                    if FileManager.default.fileExists(atPath: outputURL.path) {
                        try? FileManager.default.removeItem(at: outputURL)
                    }
                    
                    // 動画ライターをセットアップ
                    guard let videoWriter = try? AVAssetWriter(outputURL: outputURL, fileType: .mov) else {
                        continuation.resume(throwing: NSError(domain: "TTSStamp", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create video writer"]))
                        return
                    }
                    
                    // ビデオ入力設定
                    let videoSettings: [String: Any] = [
                        AVVideoCodecKey: AVVideoCodecType.h264,
                        AVVideoWidthKey: videoSize.width,
                        AVVideoHeightKey: videoSize.height,
                        AVVideoCompressionPropertiesKey: [
                            AVVideoAverageBitRateKey: 6000000
                        ]
                    ]
                    
                    let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                    videoInput.expectsMediaDataInRealTime = false
                    
                    let sourcePixelBufferAttributes: [String: Any] = [
                        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                        kCVPixelBufferWidthKey as String: videoSize.width,
                        kCVPixelBufferHeightKey as String: videoSize.height
                    ]
                    
                    let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                        assetWriterInput: videoInput,
                        sourcePixelBufferAttributes: sourcePixelBufferAttributes
                    )
                    
                    guard videoWriter.canAdd(videoInput) else {
                        continuation.resume(throwing: NSError(domain: "TTSStamp", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot add video input"]))
                        return
                    }
                    videoWriter.add(videoInput)
                    
                    // オーディオ入力設定
                    let audioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
                    
                    if let audioTrack = audioTracks.first {
                        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
                        audioInput.expectsMediaDataInRealTime = false
                        
                        guard videoWriter.canAdd(audioInput) else {
                            continuation.resume(throwing: NSError(domain: "TTSStamp", code: 4, userInfo: [NSLocalizedDescriptionKey: "Cannot add audio input"]))
                            return
                        }
                        videoWriter.add(audioInput)
                        
                        // 動画の書き込みを開始
                        guard videoWriter.startWriting() else {
                            continuation.resume(throwing: NSError(domain: "TTSStamp", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to start writing: \(videoWriter.error?.localizedDescription ?? "Unknown error")"]))
                            return
                        }
                        
                        videoWriter.startSession(atSourceTime: .zero)
                        
                        print("✅ [Video] Session started")
                        
                        // オーディオトラックを追加（セッション開始後）
                        let audioReader = try AVAssetReader(asset: audioAsset)
                        let audioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
                        audioReader.add(audioOutput)
                        
                        guard audioReader.startReading() else {
                            continuation.resume(throwing: NSError(domain: "TTSStamp", code: 9, userInfo: [NSLocalizedDescriptionKey: "Failed to start audio reading"]))
                            return
                        }
                        
                        print("✅ [Video] Audio reader started")
                        
                        // 静止画像を1フレームだけ書き込む（音声の長さ分表示される）
                        // 画像は動かないので、1フレームだけ書き込めば十分
                        print("✅ [Video] Writing single video frame (static image)")
                        
                        guard let cgImage = image.cgImage else {
                            continuation.resume(throwing: NSError(domain: "TTSStamp", code: 8, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage"]))
                            return
                        }
                        
                        // 最初のフレーム（時刻0）だけを書き込む
                        let presentationTime = CMTime.zero
                        
                        // videoInputが準備できるまで待機
                        var waitCount = 0
                        while !videoInput.isReadyForMoreMediaData && waitCount < 100 {
                            try await Task.sleep(nanoseconds: 10_000_000) // 0.01秒待機
                            waitCount += 1
                        }
                        
                        if waitCount >= 100 {
                            print("⚠️ [Video] Timeout waiting for video input")
                            continuation.resume(throwing: NSError(domain: "TTSStamp", code: 6, userInfo: [NSLocalizedDescriptionKey: "Timeout waiting for video input"]))
                            return
                        }
                        
                        guard let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool else {
                            print("❌ [Video] Pixel buffer pool is nil")
                            continuation.resume(throwing: NSError(domain: "TTSStamp", code: 6, userInfo: [NSLocalizedDescriptionKey: "Pixel buffer pool is nil"]))
                            return
                        }
                        
                        var pixelBuffer: CVPixelBuffer?
                        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pixelBuffer)
                        
                        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
                            print("❌ [Video] Failed to create pixel buffer, status: \(status)")
                            continuation.resume(throwing: NSError(domain: "TTSStamp", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to create pixel buffer"]))
                            return
                        }
                        
                        // 画像をピクセルバッファに描画
                        CVPixelBufferLockBaseAddress(buffer, [])
                        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
                        
                        let context = CGContext(
                            data: CVPixelBufferGetBaseAddress(buffer),
                            width: Int(videoSize.width),
                            height: Int(videoSize.height),
                            bitsPerComponent: 8,
                            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
                        )
                        
                        guard let ctx = context else {
                            print("❌ [Video] Failed to create context")
                            continuation.resume(throwing: NSError(domain: "TTSStamp", code: 8, userInfo: [NSLocalizedDescriptionKey: "Failed to create context"]))
                            return
                        }
                        
                        // 画像を描画
                        ctx.draw(cgImage, in: CGRect(origin: .zero, size: videoSize))
                        
                        // 最初のフレーム（時刻0）を追加
                        let appendResult1 = pixelBufferAdaptor.append(buffer, withPresentationTime: CMTime.zero)
                        if !appendResult1 {
                            print("⚠️ [Video] Failed to append pixel buffer at start")
                        }
                        print("✅ [Video] First video frame written at 0s")
                        
                        // オーディオデータを書き込んで、実際の音声の長さを取得
                        print("✅ [Video] Writing audio data to determine actual duration")
                        var audioSampleCount = 0
                        var lastAudioTime: CMTime = .zero
                        
                        while audioInput.isReadyForMoreMediaData {
                            if let sampleBuffer = audioOutput.copyNextSampleBuffer() {
                                let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                                let sampleDuration = CMSampleBufferGetDuration(sampleBuffer)
                                let sampleEndTime = CMTimeAdd(presentationTime, sampleDuration)
                                
                                // すべての音声サンプルを書き込む（制限なし）
                                audioInput.append(sampleBuffer)
                                audioSampleCount += 1
                                
                                // 最後の音声サンプルの終了時刻を記録
                                if CMTimeCompare(sampleEndTime, lastAudioTime) > 0 {
                                    lastAudioTime = sampleEndTime
                                }
                            } else {
                                audioInput.markAsFinished()
                                print("✅ [Video] Audio data written (\(audioSampleCount) samples), last audio time: \(CMTimeGetSeconds(lastAudioTime))s")
                                break
                            }
                        }
                        
                        // 実際の音声の長さを取得
                        let actualAudioEndTime = CMTimeGetSeconds(lastAudioTime) > 0 ? CMTimeGetSeconds(lastAudioTime) : duration
                        print("✅ [Video] Actual audio end time: \(actualAudioEndTime)s (original: \(duration)s)")
                        
                        // 動画の最後のフレームを、実際の音声の終了時刻に合わせる
                        let endTime = CMTime(seconds: actualAudioEndTime, preferredTimescale: 600)
                        let appendResult2 = pixelBufferAdaptor.append(buffer, withPresentationTime: endTime)
                        if !appendResult2 {
                            print("⚠️ [Video] Failed to append pixel buffer at end")
                        } else {
                            print("✅ [Video] Last video frame written at \(actualAudioEndTime)s")
                        }
                        
                        print("✅ [Video] Video frames: start at 0s, end at \(actualAudioEndTime)s (audio: \(duration)s)")
                        
                        // ビデオフレームの書き込み完了
                        videoInput.markAsFinished()
                        print("✅ [Video] Video input marked as finished")
                        
                        // markAsFinished()が呼ばれた後は、すぐにfinishWritingを呼べる
                        // ただし、少し待機して内部処理を完了させる
                        print("✅ [Video] All inputs marked as finished, waiting briefly...")
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機
                        
                        print("✅ [Video] Calling finishWriting...")
                        
                        // 動画の書き込みを完了
                        videoWriter.finishWriting {
                            print("✅ [Video] finishWriting completed")
                            if let error = videoWriter.error {
                                print("❌ [Video] Error: \(error.localizedDescription)")
                                continuation.resume(throwing: error)
                            } else {
                                print("✅ [Video] Video file created successfully at: \(outputURL.path)")
                                let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
                                print("✅ [Video] Video file size: \(fileSize) bytes")
                                continuation.resume(returning: outputURL)
                            }
                        }
                    } else {
                        continuation.resume(throwing: NSError(domain: "TTSStamp", code: 10, userInfo: [NSLocalizedDescriptionKey: "No audio track found"]))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func saveVideoToPhotoLibrary(videoURL: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        
        guard status == .authorized || status == .limited else {
            throw NSError(domain: "TTSStamp", code: 11, userInfo: [NSLocalizedDescriptionKey: "Photo library access permission is required"])
        }
        
        try await PHPhotoLibrary.shared().performChanges {
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .video, fileURL: videoURL, options: nil)
        }
    }
    
    // MARK: - 点滅アニメーション
    
    private func startPulseAnimation() {
        stopPulseAnimation()
        guard !isGenerating && !textInput.isEmpty else { return }
        
        // 最初は明るい状態から始め、少し遅延してから点滅を開始
        generateButtonOpacity = 1.0
        generateButtonTextOpacity = 1.0
        
        // 0.5秒後に点滅を開始
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard !self.isGenerating && !self.textInput.isEmpty else { return }
            withAnimation(.easeInOut(duration: 1.2)) {
                self.generateButtonOpacity = 0.7
                self.generateButtonTextOpacity = 0.4
            }
            
            self.pulseTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
                guard !self.isGenerating && !self.textInput.isEmpty else {
                    self.stopPulseAnimation()
                    return
                }
                withAnimation(.easeInOut(duration: 1.2)) {
                    self.generateButtonOpacity = self.generateButtonOpacity == 0.7 ? 1.0 : 0.7
                    self.generateButtonTextOpacity = self.generateButtonTextOpacity == 0.4 ? 1.0 : 0.4
                }
            }
        }
    }
    
    private func stopPulseAnimation() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        generateButtonOpacity = 1.0
        generateButtonTextOpacity = 1.0
    }
    
    // MARK: - リセット処理
    
    private func resetAll() {
        selectedImage = nil
        textInput = ""
        audioURL = nil
        isGenerating = false
        isPlaying = false
        stopPulseAnimation()
        
        // 音声再生を停止
        audioEngine?.stop()
        audioPlayerNode?.stop()
        audioEngine = nil
        audioPlayerNode = nil
        
        // キーボードを閉じる
        isTextEditorFocused = false
    }
}

// MARK: - Synthesizer Holder

class SynthesizerHolder {
    let synthesizer = AVSpeechSynthesizer()
    
    init() {
        // synthesizerの設定
        synthesizer.usesApplicationAudioSession = false
    }
}

// MARK: - TTS Delegate

@available(iOS 13.0, *)
class TTSDelegate: NSObject, AVSpeechSynthesizerDelegate {
    private let onFinish: (Bool) -> Void
    
    init(onFinish: @escaping (Bool) -> Void) {
        self.onFinish = onFinish
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // 音声生成が完了したことを通知
        onFinish(true)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // キャンセルされた場合
        onFinish(false)
    }
}


