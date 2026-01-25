//
//  BackgroundCompositionView.swift
//  stamp_creator
//
//  背景除去した画像を任意の背景の上に配置するビュー
//

import SwiftUI
import Photos

struct BackgroundCompositionView: View {
    // 画像関連
    @State private var foregroundImage: UIImage? // 背景除去した画像（透明PNG）
    @State private var composedImage: UIImage? // 合成された画像
    
    // UI状態
    @State private var showingForegroundPicker = false
    @State private var isComposing = false
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertTitle = String(localized: "Info")
    @State private var alertMessage = ""
    @State private var composeButtonOpacity: Double = 1.0
    @State private var composeButtonTextOpacity: Double = 1.0
    @State private var pulseTimer: Timer?
    
    // 背景設定
    @State private var backgroundColor: BackgroundColor = .white
    @State private var squareSize: SquareSize = .size512
    
    // 合成オプション
    @State private var foregroundScale: CGFloat = 1.0
    @State private var initialScale: CGFloat = 1.0 // 初期スケール（100%で画像全体が表示される）
    @State private var previewImage: UIImage? // プレビュー用の画像（実際の合成はしない）
    
    enum BackgroundColor: String, CaseIterable {
        case white = "White"
        case transparent = "Transparent"
    }
    
    enum SquareSize: Int, CaseIterable {
        case size512 = 512
        case size1024 = 1024
        case size2048 = 2048
        
        var displayName: String {
            return "\(rawValue)×\(rawValue)"
        }
    }
    
    var body: some View {
        ZStack {
            backgroundView
            mainContentView
        }
        .sheet(isPresented: $showingForegroundPicker) {
            ImagePicker(selectedImage: $foregroundImage)
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: foregroundImage) { oldValue, newValue in
            if let image = newValue {
                composedImage = nil
                // 100%で画像全体が表示されるように初期スケールを計算
                let currentSquareSize = CGFloat(self.squareSize.rawValue)
                let imageAspect = image.size.width / image.size.height
                let squareAspect: CGFloat = 1.0
                
                // 画像が正方形に収まるようにスケールを計算
                if imageAspect > squareAspect {
                    // 画像が横長の場合、幅に合わせる
                    initialScale = currentSquareSize / image.size.width
                } else {
                    // 画像が縦長の場合、高さに合わせる
                    initialScale = currentSquareSize / image.size.height
                }
                // スライダーの100%が画像全体が収まる値になるように、スライダーの値を1.0に設定
                foregroundScale = 1.0
                previewImage = nil
            }
        }
        .onChange(of: squareSize) { oldValue, newValue in
            if let image = foregroundImage {
                // サイズ変更時も100%で画像全体が表示されるように再計算
                let newSquareSize = CGFloat(newValue.rawValue)
                let imageAspect = image.size.width / image.size.height
                let squareAspect: CGFloat = 1.0
                
                if imageAspect > squareAspect {
                    initialScale = newSquareSize / image.size.width
                } else {
                    initialScale = newSquareSize / image.size.height
                }
                // スライダーの100%が画像全体が収まる値になるように、スライダーの値を1.0に設定
                foregroundScale = 1.0
                composedImage = nil
                previewImage = nil
            }
        }
        .onChange(of: backgroundColor) { oldValue, newValue in
            if foregroundImage != nil {
                composedImage = nil
                previewImage = nil
            }
        }
        .navigationTitle("Compose Background")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - View Components
    
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
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    // 画像が選択されていない場合はプレースホルダー
                    if foregroundImage == nil {
                        placeholderView
                    } else {
                    // 背景設定エリア
                    backgroundSettingsArea
                    
                        // 合成オプション（スライダーの下にプレビューを配置）
                        compositionOptionsArea
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Background Settings Area
    
    private var backgroundSettingsArea: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "paintpalette")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
            Text("Background Settings")
                .font(.headline)
                    .fontWeight(.semibold)
                .foregroundColor(.white)
            }
                .padding(.horizontal)
            
            // 背景色選択
            VStack(alignment: .leading, spacing: 12) {
                Text("Background Color")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal)
                
                Picker("Background Color", selection: $backgroundColor) {
                    ForEach(BackgroundColor.allCases, id: \.self) { color in
                        Text(String(localized: String.LocalizationValue(color.rawValue))).tag(color)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }
            
            // 正方形サイズ選択
            VStack(alignment: .leading, spacing: 12) {
                Text("Square Size")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal)
                
                Picker("サイズ", selection: $squareSize) {
                    ForEach(SquareSize.allCases, id: \.self) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Composition Options Area
    
    private var compositionOptionsArea: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
            Text("Composition Options")
                .font(.headline)
                    .fontWeight(.semibold)
                .foregroundColor(.white)
            }
                .padding(.horizontal)
            
            // スケール調整
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Image Size")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    Text("\(Int(foregroundScale * 100))%")
                    .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
                    .padding(.horizontal)
                
                Slider(value: $foregroundScale, in: 0.1...2.0, step: 0.1)
                    .tint(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.horizontal)
                    .onChange(of: foregroundScale) { oldValue, newValue in
                        // バー変更 = 設定が変わったので Compose 結果を無効化。Save は Compose 後にだけ表示。
                        composedImage = nil
                        updatePreview()
                    }
                
                // スライダーの下にプレビュー画像を配置（固定サイズで揺れを防ぐ）
                if let foreground = foregroundImage {
            VStack(alignment: .leading, spacing: 8) {
                        Text((composedImage != nil || previewImage != nil) ? "Preview" : "Selected Image")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal)
                
                        // 固定フレームで揺れを防ぐ（正方形の背景サイズで、Compose/プレビューと同じ見せ方。中央揃えで左寄せを防ぐ）
                        Group {
                            if let preview = previewImage {
                                Image(uiImage: preview)
                                    .resizable()
                                    .scaledToFit()
                            } else if let composed = composedImage {
                                Image(uiImage: composed)
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                Image(uiImage: foreground)
                                    .resizable()
                                    .scaledToFit()
                            }
                        }
                        .frame(width: 300, height: 300) // 正方形で、Compose後の表示と揃える
                        .frame(maxWidth: .infinity, alignment: .center) // 中央揃え（Selected Image の左寄せを防ぐ）
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal)
    }
                    .padding(.top, 8)
                    .id(composedImage != nil ? "composed" : previewImage != nil ? "preview" : "selected") // IDを設定してアニメーションを制御
                    
                    Text("Adjust with the slider to preview. Press Compose to create the final image, then Save.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 4)
                    
                    // Change Imageボタン
                Button(action: {
                        showingForegroundPicker = true
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
                    .padding(.top, 8)
                
                    // Composeボタン
                    Button(action: {
                        composeImages()
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Image(systemName: "square.stack.3d.up")
                                    .font(.title2)
                                    .opacity(isComposing ? 0 : 1)
                                if isComposing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.9)
                                }
                            }
                            .frame(width: 26, height: 26)
                            Text(isComposing ? "Composing..." : "Compose Image")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .opacity(isComposing ? 1.0 : composeButtonTextOpacity)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: isComposing
                                            ? [Color.gray.opacity(0.5), Color.gray.opacity(0.5)]
                                            : [Color.blue.opacity(0.9), Color.purple.opacity(0.9)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(
                                            isComposing
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
                                    color: isComposing
                                        ? Color.clear
                                        : Color.blue.opacity(0.3),
                                    radius: 12,
                                    x: 0,
                                    y: 4
                                )
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isComposing)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .opacity(isComposing ? 1.0 : composeButtonOpacity)
                    .onAppear {
                        startPulseAnimation()
                    }
                    .onChange(of: isComposing) { oldValue, newValue in
                        if newValue {
                            stopPulseAnimation()
                        } else {
                            startPulseAnimation()
                        }
                    }
                    .onDisappear {
                        stopPulseAnimation()
                    }
            
                    // Saveボタン（合成済みの場合）
                    if composedImage != nil {
                Button(action: {
                            saveComposedImage()
                }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Image(systemName: "square.and.arrow.down.fill")
                                        .font(.title2)
                                        .opacity(isSaving ? 0 : 1)
                                    if isSaving {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.9)
                                    }
                                }
                                .frame(width: 26, height: 26)
                                Text(isSaving ? "Saving..." : "Save")
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
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Preview Area
    
    
    private var placeholderView: some View {
        Button(action: {
            showingForegroundPicker = true
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
                
                Text("Select an extracted image to place on a square background")
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
    
    // MARK: - Composition Logic
    
    private func updateComposition() {
        // この関数は使用しない（スライダー変更時は再合成しない）
    }
    
    private func composeImages() {
        guard let foreground = foregroundImage else {
            alertTitle = String(localized: "Error")
            alertMessage = String(localized: "Please select an extracted image")
            showAlert = true
            return
        }
        
        isComposing = true
        
        Task {
            do {
                // 実際のスケールを計算（スライダーの値 × 初期スケール）
                let actualScale = foregroundScale * initialScale
                let composed = try await performComposition(
                    foreground: foreground,
                    backgroundColor: backgroundColor,
                    squareSize: CGFloat(squareSize.rawValue),
                    scale: actualScale
                )
                
                await MainActor.run {
                    composedImage = composed
                    previewImage = nil // 実際の合成が完了したらプレビューをクリア
                    isComposing = false
                }
            } catch {
                await MainActor.run {
                    isComposing = false
                    alertTitle = String(localized: "Error")
                    alertMessage = String(format: String(localized: "failed_to_compose"), error.localizedDescription)
                    showAlert = true
                }
            }
        }
    }
    
    private func updatePreview() {
        // スライダー変更時にプレビューを更新（実際の合成はしない）
        guard let foreground = foregroundImage else { return }
        
        Task {
            do {
                // 実際のスケールを計算（スライダーの値 × 初期スケール）
                let actualScale = foregroundScale * initialScale
                let preview = try await performComposition(
                    foreground: foreground,
                    backgroundColor: backgroundColor,
                    squareSize: CGFloat(squareSize.rawValue),
                    scale: actualScale
                )
                
                await MainActor.run {
                    previewImage = preview
                }
            } catch {
                // エラー時は何もしない
            }
        }
    }
    
    private func performComposition(
        foreground: UIImage,
        backgroundColor: BackgroundColor,
        squareSize: CGFloat,
        scale: CGFloat
    ) async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    // 正方形の背景サイズ
                    let backgroundSize = CGSize(width: squareSize, height: squareSize)
                    
                    // 前景画像をスケール
                    let scaledForegroundSize = CGSize(
                        width: foreground.size.width * scale,
                        height: foreground.size.height * scale
                    )
                    
                    // 中央配置の位置を計算
                    let foregroundPosition = CGPoint(
                        x: (backgroundSize.width - scaledForegroundSize.width) / 2,
                        y: (backgroundSize.height - scaledForegroundSize.height) / 2
                    )
                    
                    // 合成画像を作成
                    let format = UIGraphicsImageRendererFormat.default()
                    format.opaque = (backgroundColor == .white) // 白の場合は不透明、透明の場合は透明
                    
                    let renderer = UIGraphicsImageRenderer(size: backgroundSize, format: format)
                    let composed = renderer.image { context in
                        let cgContext = context.cgContext
                        
                        // 背景を描画
                        if backgroundColor == .white {
                            // 白で塗りつぶし
                            cgContext.setFillColor(UIColor.white.cgColor)
                            cgContext.fill(CGRect(origin: .zero, size: backgroundSize))
                        }
                        // 透明の場合は何も描画しない（透明のまま）
                        
                        // 前景画像を描画（透明部分は保持される）
                        foreground.draw(
                            in: CGRect(
                                origin: foregroundPosition,
                                size: scaledForegroundSize
                            ),
                            blendMode: .normal,
                            alpha: 1.0
                        )
                    }
                    
                    continuation.resume(returning: composed)
                }
            }
        }
    }
    
    // MARK: - Save Logic
    
    private func saveComposedImage() {
        // 保存できるのは Compose で確定した画像のみ。プレビューはスライダー操作の確認用。
        guard let image = composedImage else {
            alertTitle = String(localized: "Error")
            alertMessage = String(localized: "No composed image available")
            showAlert = true
            return
        }
        
        isSaving = true
        
        Task { @MainActor in
            do {
                let pngData = await Task.detached(priority: .userInitiated) {
                    autoreleasepool {
                        return image.pngData()
                    }
                }.value
                
                guard let pngData = pngData else {
                    isSaving = false
                    alertTitle = String(localized: "Error")
                    alertMessage = String(localized: "failed_to_convert_image")
                    showAlert = true
                    return
                }
                
                let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                
                guard status == .authorized || status == .limited else {
                    isSaving = false
                    alertTitle = String(localized: "Error")
                    alertMessage = String(localized: "Photo library access permission is required")
                    showAlert = true
                    return
                }
                
                try await PHPhotoLibrary.shared().performChanges {
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .photo, data: pngData, options: nil)
                }
                
                isSaving = false
                alertTitle = String(localized: "Success")
                alertMessage = String(localized: "Saved successfully")
                showAlert = true
                
            } catch {
                isSaving = false
alertTitle = String(localized: "Error")
                    alertMessage = String(format: String(localized: "failed_to_save"), error.localizedDescription)
                    showAlert = true
            }
        }
    }
    
    // MARK: - 点滅アニメーション
    
    private func startPulseAnimation() {
        stopPulseAnimation()
        guard !isComposing else { return }
        
        // 最初は明るい状態から始め、少し遅延してから点滅を開始
        composeButtonOpacity = 1.0
        composeButtonTextOpacity = 1.0
        
        // 0.5秒後に点滅を開始
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard !self.isComposing else { return }
            withAnimation(.easeInOut(duration: 1.2)) {
                self.composeButtonOpacity = 0.7
                self.composeButtonTextOpacity = 0.4
            }
            
            self.pulseTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
                guard !self.isComposing else {
                    self.stopPulseAnimation()
                    return
                }
                withAnimation(.easeInOut(duration: 1.2)) {
                    self.composeButtonOpacity = self.composeButtonOpacity == 0.7 ? 1.0 : 0.7
                    self.composeButtonTextOpacity = self.composeButtonTextOpacity == 0.4 ? 1.0 : 0.4
                }
            }
        }
    }
    
    private func stopPulseAnimation() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        composeButtonOpacity = 1.0
        composeButtonTextOpacity = 1.0
    }
    
    // MARK: - Reset Logic
    
    private func resetAll() {
        foregroundImage = nil
        composedImage = nil
        foregroundScale = 1.0
        backgroundColor = .white
        squareSize = .size512
        stopPulseAnimation()
    }
}
