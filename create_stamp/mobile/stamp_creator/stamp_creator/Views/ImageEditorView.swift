//
//  ImageEditorView.swift
//  stamp_creator
//
//  PencilKitを使った画像編集ビュー
//

import SwiftUI
import PencilKit
import Photos

struct ImageEditorView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingEditingSheet = false
    @State private var showingSaveAlert = false
    @State private var isSaving = false
    @State private var alertTitle = String(localized: "Info")
    @State private var alertMessage = ""
    // MARK: - テキスト入力機能（コメントアウト）
    // @State private var textLayers: [TextLayer] = [] // テキストレイヤー
    // @State private var showingTextEditor = false // テキストエディタの表示状態
    // @State private var editingTextLayer: TextLayer? // 編集中のテキストレイヤー
    // @State private var showingAddMenu = false // 追加メニューの表示状態
    // @State private var addMenuPosition: CGPoint = .zero // メニューの表示位置
    
    var body: some View {
        ZStack {
            backgroundView
            mainContentView
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showingEditingSheet) {
            if let image = selectedImage {
                EditingSheetView(
                    image: image,
                    onDismiss: {
                        showingEditingSheet = false
                    },
                    onSave: { editedImage in
                        selectedImage = editedImage
                        showingEditingSheet = false
                    }
                )
            }
        }
        // MARK: - テキストエディタシート（コメントアウト）
        // .sheet(isPresented: $showingTextEditor) {
        //     if let textLayer = editingTextLayer {
        //         TextEditorView(
        //             textLayer: Binding(
        //                 get: { textLayer },
        //                 set: { newValue in
        //                     if let index = textLayers.firstIndex(where: { $0.id == newValue.id }) {
        //                         textLayers[index] = newValue
        //                     }
        //                 }
        //             ),
        //             imageFrame: imageViewFrame
        //         )
        //     }
        // }
        .alert(alertTitle, isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
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
                VStack(spacing: 20) {
                    imagePreviewArea
                }
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Edit Sticker")
        .navigationBarTitleDisplayMode(.large)
    }
    
    @ViewBuilder
    private var imagePreviewArea: some View {
        if let image = selectedImage {
            VStack(spacing: 16) {
            // 画像プレビュー（タップで編集画面を開く）
                VStack(spacing: 12) {
                    ZStack {
                        // 背景を明示的に設定（ライトモードでの白い四角の重複を防ぐ）
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.clear)
                        
                        // 透明画像の場合はチェッカーパターンを表示
                        if imageHasTransparency(image) {
                            CheckerboardPattern()
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                        
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 400)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .compositingGroup()
                    .drawingGroup()
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
                .contentShape(Rectangle())
                .onTapGesture {
                    showingEditingSheet = true
                }
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
                
                // EditボタンとSaveボタン
                HStack(spacing: 14) {
                    // 編集ボタン（Save と同じアイコン枠でサイズを揃える）
                    Button(action: {
                        showingEditingSheet = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "pencil.tip")
                                .font(.title2)
                                .frame(width: 26, height: 26)
                            Text("Edit")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white) // ボタン背景が青・シアンのグラデーションのため
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                LinearGradient(
                                    colors: [
                                        Color.cyan.opacity(0.85),
                                        Color.blue.opacity(0.85)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                                .shadow(color: .cyan.opacity(0.4), radius: 12, x: 0, y: 6)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    // Saveボタン（アイコン/ProgressView を固定枠で入れ替え、レイアウトのずれを防ぐ）
                    Button(action: {
                        saveCurrentImage()
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
                        .foregroundColor(.white) // ボタン背景が青・紫のグラデーションのため
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
                }
                .padding(.horizontal)
            }
        } else {
            placeholderView
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
                
                Text("Select Image")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                
                Text("Tap to choose an image and start editing")
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
    
    private func saveCurrentImage() {
        // 現在の画像をそのまま保存（編集画面で編集した場合は既に更新されている）
        guard let image = selectedImage else {
            alertTitle = String(localized: "Error")
            alertMessage = String(localized: "No image selected")
            showingSaveAlert = true
            return
        }
        
        saveImageToPhotoLibrary(image)
    }
    
    private func resetAll() {
        // 画像をクリア
        selectedImage = nil
    }
    
    private func saveImageToPhotoLibrary(_ image: UIImage) {
        isSaving = true
        
        // メインスレッドで実行
        Task { @MainActor in
            do {
                // バックグラウンドスレッドでPNGデータに変換（メモリ効率化）
                let pngData = await Task.detached(priority: .userInitiated) {
                    autoreleasepool {
                        return image.pngData()
                    }
                }.value
                
                guard let pngData = pngData else {
                    alertTitle = String(localized: "Error")
                    alertMessage = String(localized: "Failed to convert image to PNG")
                    showingSaveAlert = true
                    return
                }
                
                // フォトライブラリへのアクセス許可を確認
                let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                
                guard status == .authorized || status == .limited else {
                    alertTitle = String(localized: "Error")
                    alertMessage = String(localized: "Photo library access permission is required")
                    showingSaveAlert = true
                    return
                }
                
                // フォトライブラリに保存
                try await PHPhotoLibrary.shared().performChanges {
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .photo, data: pngData, options: nil)
                }
                
                // 成功
                isSaving = false
                alertTitle = String(localized: "Success")
                alertMessage = String(localized: "Saved successfully")
                showingSaveAlert = true
                
            } catch {
                isSaving = false
                alertTitle = String(localized: "Error")
                alertMessage = String(format: String(localized: "failed_to_save"), error.localizedDescription)
                showingSaveAlert = true
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func imageHasTransparency(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        let alphaInfo = cgImage.alphaInfo
        return alphaInfo == .first || alphaInfo == .last || alphaInfo == .premultipliedFirst || alphaInfo == .premultipliedLast || alphaInfo == .alphaOnly
    }
}

// MARK: - PencilKit Image View

struct PencilKitImageView: UIViewRepresentable {
    let image: UIImage
    @Binding var canvasView: PKCanvasView?
    @Binding var toolPicker: PKToolPicker?
    @Binding var isToolPickerVisible: Bool
    var onUndoRedoStateChanged: (() -> Void)?
    var onImageViewFrameChanged: ((CGRect) -> Void)?
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        // 画像ビュー（カスタムクラスでフレーム変更を監視）
        let imageView = FrameTrackingImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // coordinatorを変数に代入してからクロージャで使用
        let coordinator = context.coordinator
        imageView.onFrameChanged = { [weak coordinator, weak imageView] frame in
            coordinator?.onImageViewFrameChanged?(frame)
            // フレームが変更されたら枠を更新
            if let imageView = imageView {
                coordinator?.updateImageBorder(for: imageView, in: containerView)
            }
        }
        containerView.addSubview(imageView)
        
        // 画像の枠を表示するビュー
        let borderView = UIView()
        borderView.backgroundColor = .clear
        borderView.layer.borderWidth = 2.0
        borderView.layer.borderColor = UIColor.white.withAlphaComponent(0.6).cgColor
        borderView.layer.cornerRadius = 8.0
        borderView.isUserInteractionEnabled = false
        borderView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(borderView)
        context.coordinator.borderView = borderView
        
        // PencilKitキャンバス
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.delegate = context.coordinator
        canvas.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(canvas)
        
        // 制約を設定
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            canvas.topAnchor.constraint(equalTo: containerView.topAnchor),
            canvas.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            canvas.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // PKToolPickerを設定
        // iOS 14以降では、個別のインスタンスを作成
        var picker: PKToolPicker?
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           windowScene.windows.first != nil {
            picker = PKToolPicker()
            if let picker = picker {
                picker.addObserver(canvas)
                // 初期状態では非表示（isToolPickerVisibleがfalseの場合）
                picker.setVisible(isToolPickerVisible, forFirstResponder: canvas)
                if isToolPickerVisible {
                    canvas.becomeFirstResponder()
                }
            }
        }
        
        context.coordinator.canvasView = canvas
        context.coordinator.imageView = imageView
        context.coordinator.toolPicker = picker
        context.coordinator.onUndoRedoStateChanged = onUndoRedoStateChanged
        context.coordinator.onImageViewFrameChanged = onImageViewFrameChanged
        
        // Bindingに設定
        DispatchQueue.main.async {
            self.canvasView = canvas
            self.toolPicker = picker
        }
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let imageView = context.coordinator.imageView,
              let canvasView = context.coordinator.canvasView,
              let toolPicker = context.coordinator.toolPicker else { return }
        
        // 画像が変更された場合
        if imageView.image != image {
            imageView.image = image
            // FrameTrackingImageViewが自動的にフレームを通知する
        }
        
        // 枠を更新
        if context.coordinator.borderView != nil {
            context.coordinator.updateImageBorder(for: imageView, in: uiView)
        }
        
        // ツールピッカーの表示状態に応じて描画ポリシーと表示状態を変更
        toolPicker.setVisible(isToolPickerVisible, forFirstResponder: canvasView)
        if isToolPickerVisible {
            // ツールピッカーが表示されている時は、描画を有効化
            canvasView.drawingPolicy = .anyInput
            canvasView.becomeFirstResponder()
        } else {
            // ツールピッカーが非表示の時は、描画を無効化（Apple Pencilのみ、または無効）
            canvasView.drawingPolicy = .pencilOnly
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var canvasView: PKCanvasView?
        var imageView: UIImageView?
        var toolPicker: PKToolPicker?
        var borderView: UIView?
        var onUndoRedoStateChanged: (() -> Void)?
        var onImageViewFrameChanged: ((CGRect) -> Void)?
        private var lastImageFrame: CGRect = .zero
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // 描画が変更されたら、アンドゥ/リドゥの状態を更新
            DispatchQueue.main.async { [weak self] in
                self?.onUndoRedoStateChanged?()
            }
        }
        
        func updateImageBorder(for imageView: UIImageView, in containerView: UIView) {
            guard let borderView = borderView else { return }
            
            // 画像ビューの実際の表示フレームを計算
            let imageFrame: CGRect
            if let frameTrackingView = imageView as? FrameTrackingImageView {
                imageFrame = frameTrackingView.calculateImageFrame()
            } else {
                // フォールバック: 画像ビューのフレームを使用
                imageFrame = imageView.frame
            }
            
            // フレームが変更されていない場合はスキップ
            if imageFrame == lastImageFrame && imageFrame.width > 0 && imageFrame.height > 0 {
                return
            }
            lastImageFrame = imageFrame
            
            guard imageFrame.width > 0 && imageFrame.height > 0 else {
                borderView.isHidden = true
                return
            }
            
            // 枠を画像より一回り大きく表示（パディング: 8px）
            let padding: CGFloat = 8.0
            borderView.frame = CGRect(
                x: imageFrame.origin.x - padding,
                y: imageFrame.origin.y - padding,
                width: imageFrame.width + padding * 2,
                height: imageFrame.height + padding * 2
            )
            borderView.isHidden = false
        }
    }
}

// MARK: - Frame Tracking Image View

class FrameTrackingImageView: UIImageView {
    var onFrameChanged: ((CGRect) -> Void)?
    private var lastFrame: CGRect = .zero
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // フレームが変更された場合のみ通知
        if frame != lastFrame && frame.width > 0 && frame.height > 0 {
            lastFrame = frame
            // contentMode = .scaleAspectFitの場合の実際の画像表示領域を計算
            let actualImageFrame = calculateImageFrame()
            onFrameChanged?(actualImageFrame)
        }
    }
    
    func calculateImageFrame() -> CGRect {
        guard let image = image else { return frame }
        
        let imageSize = image.size
        guard imageSize.width > 0 && imageSize.height > 0 else { return frame }
        
        let viewSize = bounds.size
        guard viewSize.width > 0 && viewSize.height > 0 else { return frame }
        
        // scaleAspectFitの場合の実際の画像表示サイズを計算
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height
        
        let displaySize: CGSize
        if imageAspect > viewAspect {
            // 画像の方が横長 → 幅に合わせる
            displaySize = CGSize(width: viewSize.width, height: viewSize.width / imageAspect)
        } else {
            // 画像の方が縦長 → 高さに合わせる
            displaySize = CGSize(width: viewSize.height * imageAspect, height: viewSize.height)
        }
        
        // 中央に配置されたフレームを返す
        return CGRect(
            x: (viewSize.width - displaySize.width) / 2,
            y: (viewSize.height - displaySize.height) / 2,
            width: displaySize.width,
            height: displaySize.height
        )
    }
}
