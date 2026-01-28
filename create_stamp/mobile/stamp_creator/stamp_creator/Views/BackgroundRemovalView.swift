//
//  BackgroundRemovalView.swift
//  stamp_creator
//
//  背景除去ビュー
//

import SwiftUI
import VisionKit
import Photos

struct BackgroundRemovalView: View {
    @Environment(\.colorScheme) var colorScheme
    
    // 画像関連
    @State private var selectedImage: UIImage?
    @State private var processedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingExtractedImage = false
    
    // UI状態
    @State private var isProcessing = false
    @State private var showAlert = false
    @State private var alertTitle = String(localized: "Info")
    @State private var alertMessage = ""
    
    // ImageAnalysis関連
    @StateObject private var viewModel: ImageAnalysisViewModel = ImageAnalysisViewModel()
    @State private var detectedSubjects: Set<ImageAnalysisInteraction.Subject> = []
    
    // 背景除去ボタン表示用
    @State private var showRemoveBackgroundButton = false
    @State private var longPressLocation: CGPoint? // 画像ビュー内の座標（ズーム前）
    @State private var longPressLocationInScrollView: CGPoint? // ScrollView内の座標（拡大時用）
    @State private var zoomScale: CGFloat = 1.0
    @State private var scrollOffset: CGPoint = .zero
    @State private var imageViewFrame: CGRect = .zero
    @State private var removeButtonOpacity: Double = 1.0
    @State private var removeButtonTextOpacity: Double = 1.0
    @State private var pulseTimer: Timer?
    
    var body: some View {
        ZStack {
            backgroundView
            mainContentView
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showingExtractedImage) {
            if let extractedImage = processedImage {
                ExtractedImageView(
                    image: extractedImage,
                    onSave: {
                        saveToPhotoLibrary()
                    },
                    onDismiss: {
                        showingExtractedImage = false
                    }
                )
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            if let image = newValue {
                loadImage(image)
            }
        }
    }
    
    // MARK: - View Components
    
    private var backgroundView: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color(red: 0.08, green: 0.08, blue: 0.18),
                    Color(red: 0.15, green: 0.12, blue: 0.28)
                ]
                : [
                    Color(red: 0.95, green: 0.95, blue: 0.97),
                    Color(red: 0.98, green: 0.98, blue: 1.0)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    imageDisplayArea
                }
                .padding(.bottom, 8) // ボタンエリアとの間隔を小さく
            }
            .simultaneousGesture(
                // 画面のどこでもタップしたら選択解除（画像ビューのタップと同時に処理）
                TapGesture().onEnded {
                    handleScreenTap()
                }
            )
            
        }
        .navigationTitle("Remove Background")
        .navigationBarTitleDisplayMode(.large)
    }
    
    @ViewBuilder
    private var imageDisplayArea: some View {
        if let image = selectedImage {
            originalImageView(image: image)
        } else {
            placeholderView
        }
    }
    
    private func originalImageView(image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Long press to select subject, tap to deselect"))
                .font(.caption2)
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .primary.opacity(0.6))
                .padding(.horizontal)
            
            // 拡大縮小可能な画像ビュー（画面全体を最大限活用）
            GeometryReader { geometry in
                ZStack {
                    ZoomableImageView(
                        image: image,
                        onLongPress: { location in
                            handleLongPress(at: location)
                        },
                        onTap: { location in
                            handleTap(at: location)
                        },
                        onLongPressInScrollView: { locationInScrollView in
                            // ScrollView内の座標を保存（拡大時用）
                            longPressLocationInScrollView = locationInScrollView
                        },
                        onZoomChanged: { scale, offset, frame in
                            zoomScale = scale
                            scrollOffset = offset
                            imageViewFrame = frame
                        }
                    )
                    .frame(maxHeight: .infinity)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    )
                    .environmentObject(viewModel)
                    
                    // 背景除去ボタンを長押し位置の近くに表示
                    if showRemoveBackgroundButton {
                        removeBackgroundButtonOverlay(in: geometry)
                    }
                }
            }
            .frame(minHeight: 500) // 最小高さを設定しつつ、可能な限り大きく
            .padding(.horizontal)
            
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
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .primary.opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        colorScheme == .dark 
                                            ? Color.white.opacity(0.2) 
                                            : Color.black.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                    )
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal)
        }
    }
    
    // 背景除去ボタンのオーバーレイ（長押し位置の近くに表示）
    private func removeBackgroundButtonOverlay(in geometry: GeometryProxy) -> some View {
        let padding: CGFloat = 12
        let imageViewHeight = geometry.size.height
        let imageViewWidth = geometry.size.width
        
        // 長押し位置をSwiftUIビュー座標に変換
        // ScrollView内の座標が利用可能な場合はそれを使用（拡大時）
        // そうでない場合は画像ビュー内の座標を使用（通常時）
        let locationInSwiftUI: CGPoint
        if let locationInScrollView = longPressLocationInScrollView {
            // 拡大時: ScrollView内の座標を直接使用
            // ScrollViewはpadding(12)で囲まれているので、その分を加算
            locationInSwiftUI = CGPoint(
                x: padding + locationInScrollView.x,
                y: padding + locationInScrollView.y
            )
        } else if let location = longPressLocation {
            // 通常時: 画像ビュー内の座標を使用
            locationInSwiftUI = CGPoint(
                x: padding + location.x,
                y: padding + location.y
            )
        } else {
            // フォールバック
            locationInSwiftUI = CGPoint(x: padding, y: padding)
        }
        
        // ボタンのサイズ
        let buttonWidth: CGFloat = 140
        let buttonHeight: CGFloat = 44
        
        // 長押し位置の少し上（-20px）にボタンを配置（横軸はそのまま）
        // 画面端からはみ出さないように調整
        let buttonX = min(max(locationInSwiftUI.x, padding + buttonWidth / 2), imageViewWidth - padding - buttonWidth / 2)
        let buttonY = min(max(locationInSwiftUI.y - 20, padding + buttonHeight / 2), imageViewHeight - padding - buttonHeight / 2)
        
        return Button(action: {
            showRemoveBackgroundButton = false
            longPressLocation = nil
            longPressLocationInScrollView = nil
            removeBackground()
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Image(systemName: "wand.and.stars")
                        .font(.title2)
                        .opacity(isProcessing ? 0 : 1)
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    }
                }
                .frame(width: 26, height: 26)
                Text(isProcessing ? "Processing..." : "Remove Background")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .opacity(isProcessing ? 1.0 : removeButtonTextOpacity)
            }
            .foregroundColor(.white) // ボタンは常に白（背景が青・紫のグラデーションのため）
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: isProcessing
                                ? [Color.gray.opacity(0.5), Color.gray.opacity(0.5)]
                                : [Color.blue.opacity(0.9), Color.purple.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                isProcessing
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
                        color: isProcessing
                            ? Color.clear
                            : Color.blue.opacity(0.3),
                        radius: 12,
                        x: 0,
                        y: 4
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isProcessing)
        .position(x: buttonX, y: buttonY)
        .opacity(isProcessing ? 1.0 : removeButtonOpacity)
        .onAppear {
            startPulseAnimation()
        }
        .onChange(of: isProcessing) { oldValue, newValue in
            if newValue {
                stopPulseAnimation()
            } else {
                startPulseAnimation()
            }
        }
        .onDisappear {
            stopPulseAnimation()
        }
    }
    
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
                
                Text(String(localized: "Select Image"))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                
                Text(String(localized: "Select an image to remove its background"))
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .primary.opacity(0.7))
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
    
    // MARK: - 画像読み込み処理
    
    func loadImage(_ image: UIImage) {
        print("🟢 [画像読み込み] 開始: サイズ=\(image.size)")
        
        // 向き修正
        if let fixedImage: UIImage = image.fixedOrientation() {
            selectedImage = fixedImage
            print("✅ [画像読み込み] 向き修正完了: サイズ=\(fixedImage.size)")
        } else {
            selectedImage = image
            print("⚠️ [画像読み込み] 向き修正失敗、元画像を使用")
        }
        
        processedImage = nil
        detectedSubjects = []
        viewModel.interaction.highlightedSubjects = []
        
        // 画像解析を実行
        Task { @MainActor in
            do {
                guard let image = selectedImage else { return }
                try await viewModel.analyzeImage(image)
                detectedSubjects = viewModel.detectedSubjects
                print("✅ [画像解析] 検出された被写体数: \(detectedSubjects.count)")
            } catch {
                print("❌ [画像解析] エラー: \(error.localizedDescription)")
                alertTitle = String(localized: "Error")
                alertMessage = String(format: String(localized: "failed_to_analyze_image"), error.localizedDescription)
                showAlert = true
            }
        }
    }
    
    // MARK: - タップ処理
    
    func handleTap(at location: CGPoint) {
        print("🟢 [ContentView] タップ処理開始: 位置=\(location)")
        Task { @MainActor in
            // ImageAnalysisInteractionのsubject(at:)を使用
            if let tappedSubject = await viewModel.interaction.subject(at: location) {
                print("✅ [ContentView] 被写体を検出: bounds=\(tappedSubject.bounds)")
                
                // タップで選択解除
                if viewModel.interaction.highlightedSubjects.contains(tappedSubject) {
                    viewModel.interaction.highlightedSubjects.remove(tappedSubject)
                    print("🟢 [ContentView] 選択解除")
                    processedImage = nil
                    showingExtractedImage = false
                    showRemoveBackgroundButton = false
                    longPressLocation = nil
                    longPressLocationInScrollView = nil
                }
            } else {
                // 被写体以外をタップした場合は選択解除
                print("⚠️ [ContentView] 被写体が見つかりませんでした")
                viewModel.interaction.highlightedSubjects = []
                processedImage = nil
                showingExtractedImage = false
                showRemoveBackgroundButton = false
                longPressLocation = nil
                longPressLocationInScrollView = nil
            }
        }
    }
    
    // 画面全体のタップ処理（画像外をタップした時）
    private func handleScreenTap() {
        // 選択されている被写体がある場合、選択解除
        if !viewModel.interaction.highlightedSubjects.isEmpty {
            viewModel.interaction.highlightedSubjects = []
            processedImage = nil
            showingExtractedImage = false
            showRemoveBackgroundButton = false
            longPressLocation = nil
            longPressLocationInScrollView = nil
        }
    }
    
    func handleLongPress(at location: CGPoint) {
        print("🟢 [ContentView] 長押し処理開始: 位置=\(location)")
        Task { @MainActor in
            // 再度長押ししている時は一度ボタンを消す
            if showRemoveBackgroundButton {
                showRemoveBackgroundButton = false
                longPressLocation = nil
                longPressLocationInScrollView = nil
            }
            
            // ImageAnalysisInteractionのsubject(at:)を使用
            if let tappedSubject = await viewModel.interaction.subject(at: location) {
                print("✅ [ContentView] 被写体を検出: bounds=\(tappedSubject.bounds)")
                
                // 長押しで選択
                viewModel.interaction.highlightedSubjects = [tappedSubject]
                print("🟢 [ContentView] 選択: \(tappedSubject.bounds)")
                
                // 長押し位置を保存（画像ビュー内の座標）
                longPressLocation = location
                // longPressLocationInScrollViewはonLongPressInScrollViewコールバックで設定される
                
                // 背景除去ボタンを表示
                showRemoveBackgroundButton = true
            } else {
                print("⚠️ [ContentView] 被写体が見つかりませんでした")
                showRemoveBackgroundButton = false
                longPressLocation = nil
                longPressLocationInScrollView = nil
            }
        }
    }
    
    // MARK: - 背景除去処理
    
    func removeBackground() {
        guard selectedImage != nil else {
            print("❌ [背景除去] 画像が選択されていません")
            alertTitle = "Error"
            alertMessage = "Please select an image"
            showAlert = true
            return
        }
        
        guard !viewModel.interaction.highlightedSubjects.isEmpty else {
            print("❌ [背景除去] 被写体が選択されていません")
            alertTitle = String(localized: "Error")
            alertMessage = String(localized: "Please long press to select a subject")
            showAlert = true
            return
        }
        
        print("🟢 [背景除去] 開始: 選択された被写体数=\(viewModel.interaction.highlightedSubjects.count)")
        
        isProcessing = true
        processedImage = nil
        
        Task { @MainActor in
            do {
                let extractedImage = try await viewModel.extractImage(for: viewModel.interaction.highlightedSubjects)
                processedImage = extractedImage
                isProcessing = false
                print("✅ [背景除去] 完了: サイズ=\(extractedImage.size)")
                
                // ポップアップで表示
                showingExtractedImage = true
            } catch {
                print("❌ [背景除去] エラー: \(error.localizedDescription)")
                isProcessing = false
                alertTitle = String(localized: "Error")
                alertMessage = String(format: String(localized: "failed_to_remove_background"), error.localizedDescription)
                showAlert = true
            }
        }
    }
    
    // MARK: - 保存処理
    
    func saveToPhotoLibrary() {
        guard let image = processedImage else { return }
        
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized || status == .limited {
                guard let cgImage = image.cgImage else {
                    DispatchQueue.main.async {
                        self.alertMessage = String(localized: "Failed to get image")
                        self.showAlert = true
                    }
                    return
                }
                
                let mutableData = NSMutableData()
                guard let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil) else {
                    DispatchQueue.main.async {
                        self.alertMessage = String(localized: "Failed to generate PNG data")
                        self.showAlert = true
                    }
                    return
                }
                
                CGImageDestinationAddImage(destination, cgImage, nil)
                guard CGImageDestinationFinalize(destination) else {
                    DispatchQueue.main.async {
                        self.alertMessage = String(localized: "Failed to generate PNG data")
                        self.showAlert = true
                    }
                    return
                }
                
                let pngData = mutableData as Data
                
                PHPhotoLibrary.shared().performChanges({
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .photo, data: pngData, options: nil)
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            self.alertTitle = String(localized: "Success")
                            self.alertMessage = String(localized: "Saved successfully")
                            self.showAlert = true
                            self.showingExtractedImage = false
                        } else {
                            self.alertTitle = String(localized: "Error")
                            self.alertMessage = String(format: String(localized: "failed_to_save"), error?.localizedDescription ?? String(localized: "Unknown error"))
                            self.showAlert = true
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.alertTitle = String(localized: "Error")
                    self.alertMessage = String(localized: "Photo library access permission is required")
                    self.showAlert = true
                }
            }
        }
    }
    
    // MARK: - 点滅アニメーション
    
    private func startPulseAnimation() {
        stopPulseAnimation()
        guard !isProcessing else { return }
        
        // 最初は明るい状態から始め、少し遅延してから点滅を開始
        removeButtonOpacity = 1.0
        removeButtonTextOpacity = 1.0
        
        // 0.5秒後に点滅を開始
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard !self.isProcessing else { return }
            withAnimation(.easeInOut(duration: 1.2)) {
                self.removeButtonOpacity = 0.7
                self.removeButtonTextOpacity = 0.4
            }
            
            self.pulseTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
                guard !self.isProcessing else {
                    self.stopPulseAnimation()
                    return
                }
                withAnimation(.easeInOut(duration: 1.2)) {
                    self.removeButtonOpacity = self.removeButtonOpacity == 0.7 ? 1.0 : 0.7
                    self.removeButtonTextOpacity = self.removeButtonTextOpacity == 0.4 ? 1.0 : 0.4
                }
            }
        }
    }
    
    private func stopPulseAnimation() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        removeButtonOpacity = 1.0
        removeButtonTextOpacity = 1.0
    }
    
    // MARK: - リセット処理
    
    func resetAll() {
        selectedImage = nil
        processedImage = nil
        detectedSubjects = []
        viewModel.interaction.highlightedSubjects = []
        showingExtractedImage = false
        showRemoveBackgroundButton = false
        longPressLocation = nil
        longPressLocationInScrollView = nil
        stopPulseAnimation()
    }
}
