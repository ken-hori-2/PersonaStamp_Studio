//
//  ContentView.swift
//  stamp_creator
//
//  Created by 堀内健司 on 2025/11/15.
//

import SwiftUI
import Vision
import PhotosUI
import Photos
import ImageIO

// 検出された人物の情報
struct DetectedPerson: Identifiable {
    let id = UUID()
    var maskBuffer: CVPixelBuffer  // varに変更（手動調整可能にするため）
    let boundingBox: CGRect  // 画像内での位置
    var isSelected: Bool = false
    var facePosition: CGPoint?  // 顔の位置（正規化座標、0.0〜1.0）
    var bodyPosePoints: [VNHumanBodyPoseObservation.JointName: CGPoint]?  // 体の姿勢の関節位置
}

struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var processedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var isProcessing = false
    @State private var showShareSheet = false
    @State private var showAlert = false
    @State private var alertTitle = "通知"
    @State private var alertMessage = ""
    
    // 複数人物検出用
    @State private var detectedPersons: [DetectedPerson] = []
    @State private var showingPersonSelection = false
    @State private var imageSize: CGSize = .zero
    @State private var detectedFaces: [CGPoint] = []  // 検出された顔の位置（正規化座標）
    
    // 手動調整用
    @State private var isEditingMask = false
    @State private var editingPersonId: UUID?
    @State private var maskEditMode: MaskEditMode = .none
    @State private var brushSize: CGFloat = 10.0  // デフォルト値を1~20の中央値に
    @State private var maskEditCounter: Int = 0  // マスク編集のカウンター（View更新用）
    @State private var lastEditLocation: CGPoint?  // 前回の編集位置（滑らかな編集用）
    @State private var editWorkItem: DispatchWorkItem?  // 編集処理の間引き用
    
    enum MaskEditMode {
        case none
        case add      // マスクを追加
        case remove   // マスクを削除
    }
    
    var body: some View {
        ZStack {
            // モダンなグラデーション背景
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.18),
                    Color(red: 0.15, green: 0.12, blue: 0.28),
                    Color(red: 0.12, green: 0.1, blue: 0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // 装飾的なグラデーションオーバーレイ
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.1),
                    Color.blue.opacity(0.05),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Title (Modern Design)
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.purple, Color.pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("Stamp Creator")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.white, Color.white.opacity(0.9)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                        
                        Text("Remove background automatically")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.top, 4)
                        
                        // Info message (modern design)
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Photo with people required")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.blue.opacity(0.25),
                                            Color.purple.opacity(0.2)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .padding(.top, 8)
                    }
                    .padding(.top, 20)
                    
                    // 画像表示エリア（モダンなデザイン）
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(.ultraThinMaterial)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 25, x: 0, y: 12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.3),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                        
                        if let image = processedImage ?? selectedImage {
                            ZStack {
                                // 透過画像の場合はチェッカーパターンの背景を表示
                                if processedImage != nil {
                                    // チェッカーパターンで透過を視覚化
                                    CheckerboardPattern()
                                        .clipShape(RoundedRectangle(cornerRadius: 24))
                                }
                                
                                GeometryReader { geometry in
                                    let actualImageSize = calculateActualImageSize(
                                        imageSize: imageSize,
                                        viewSize: geometry.size
                                    )
                                    
                                    // 画像を中央に配置するためのオフセット
                                    let imageOffsetX = (geometry.size.width - actualImageSize.width) / 2
                                    let imageOffsetY = (geometry.size.height - actualImageSize.height) / 2
                                    
                                    ZStack {
                                        // 元画像を中央に配置（角丸を統一）
                                        // 全ての画像フォーマットで角丸を確実に適用
                                        // 画像を直接角丸に加工してから表示（元画像のサイズに基づいて角丸を計算）
                                        // actualImageSizeは表示サイズ、image.sizeは元画像サイズ
                                        // 角丸24ptを元画像サイズにスケール
                                        let scale = min(image.size.width / actualImageSize.width, image.size.height / actualImageSize.height)
                                        let cornerRadiusInImage = max(24 * scale, 1.0)  // 最小1px
                                        let roundedImage = image.rounded(cornerRadius: cornerRadiusInImage) ?? image
                                        Image(uiImage: roundedImage)
                                            .resizable()
                                            .interpolation(.high)
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: actualImageSize.width, height: actualImageSize.height)
                                            .clipShape(RoundedRectangle(cornerRadius: 24))
                                            .offset(x: imageOffsetX, y: imageOffsetY)
                                        
                                        // 人物選択モード: 検出された人物の領域をセグメンテーションマスクで塗りつぶし
                                        if showingPersonSelection && !detectedPersons.isEmpty {
                                            ForEach(detectedPersons) { person in
                                                MaskOverlayView(
                                                    person: person,
                                                    imageSize: imageSize,
                                                    actualImageSize: actualImageSize,
                                                    viewSize: geometry.size,
                                                    imageOffset: CGPoint(x: imageOffsetX, y: imageOffsetY),
                                                    isSelected: person.isSelected,
                                                    isEditingMode: isEditingMask,  // 編集モードを渡す
                                                    editCounter: maskEditCounter,  // 編集カウンターを渡す
                                                    onTap: {
                                                        selectPerson(person.id)
                                                    }
                                                )
                                            }
                                        }
                                    }
                                    .gesture(
                                        // 編集モードまたはタップ位置を正確に検出
                                        DragGesture(minimumDistance: isEditingMask ? 1 : 0)
                                            .onChanged { value in
                                                if isEditingMask && maskEditMode != .none {
                                                    // 編集モード: ドラッグでマスクを編集
                                                    let editLocation = value.location
                                                    
                                                    // 前回の位置を取得（この時点でのlastEditLocation）
                                                    // nilの場合は、現在位置を始点として使用（最初の編集時）
                                                    let previousLocation: CGPoint?
                                                    if let lastLoc = self.lastEditLocation {
                                                        previousLocation = lastLoc
                                                    } else {
                                                        // 最初の編集時は、現在位置を始点として使用
                                                        previousLocation = editLocation
                                                        // lastEditLocationを初期化
                                                        self.lastEditLocation = editLocation
                                                    }
                                                    
                                                    // リアルタイム編集：スワイプ中も定期的に適用
                                                    editWorkItem?.cancel()
                                                    
                                                    // 現在の位置を保存（次のonChangedのための前回位置として）
                                                    let currentLocationForNext = editLocation
                                                    
                                                    // 即座に編集処理を実行（待機時間なし）
                                                    // 前回の位置と現在の位置を渡す
                                                    self.editMask(
                                                        at: editLocation,
                                                        previousLocation: previousLocation,
                                                        in: geometry.size,
                                                        actualImageSize: actualImageSize,
                                                        imageOffset: CGPoint(x: imageOffsetX, y: imageOffsetY)
                                                    )
                                                    
                                                    // 次の編集のための始点として現在位置を保存
                                                    self.lastEditLocation = currentLocationForNext
                                                    
                                                    // 追加の間引き処理（重い処理を防ぐため）
                                                    // ただし、即座に実行した後、16ms後に再度実行して確実に反映
                                                    let workItem = DispatchWorkItem {
                                                        // 再度編集処理を実行（確実に反映させるため）
                                                        self.editMask(
                                                            at: editLocation,
                                                            previousLocation: previousLocation,
                                                            in: geometry.size,
                                                            actualImageSize: actualImageSize,
                                                            imageOffset: CGPoint(x: imageOffsetX, y: imageOffsetY)
                                                        )
                                                    }
                                                    editWorkItem = workItem
                                                    // 16ms間隔で追加実行（約60fps、滑らかに）
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.016, execute: workItem)
                                                }
                                            }
                                            .onEnded { value in
                                                if showingPersonSelection && !detectedPersons.isEmpty {
                                                    if isEditingMask && maskEditMode != .none {
                                                        // 編集モード: 最後の編集を実行して終了
                                                        editWorkItem?.cancel()
                                                        let editLocation = value.location
                                                        let previousLocation = self.lastEditLocation
                                                        editMask(at: editLocation, previousLocation: previousLocation, in: geometry.size, actualImageSize: actualImageSize, imageOffset: CGPoint(x: imageOffsetX, y: imageOffsetY))
                                                        lastEditLocation = nil  // リセット
                                                    } else {
                                                        // 通常モード: タップ位置から人物を判定
                                                        let tapLocation = value.location
                                                        handleTap(at: tapLocation, in: geometry.size, actualImageSize: actualImageSize, imageOffset: CGPoint(x: imageOffsetX, y: imageOffsetY))
                                                    }
                                                }
                                            }
                                    )
                                }
                            }
                            .padding(16)
                            .onAppear {
                                if let image = selectedImage {
                                    imageSize = image.size
                                }
                            }
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Text("Select an image")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 300)
                        }
                    }
                    .frame(height: 400)
                    .padding(.horizontal, 20)
                    
                    // ボタンエリア
                    VStack(spacing: 16) {
                        // 画像選択ボタン
                        HStack(spacing: 16) {
                            Button(action: {
                                imagePickerSourceType = .photoLibrary
                                showingImagePicker = true
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text("Select Photo")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [Color.blue, Color.purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(18)
                                .shadow(color: .blue.opacity(0.4), radius: 12, x: 0, y: 6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                            }
                            
                            Button(action: {
                                imagePickerSourceType = .camera
                                showingImagePicker = true
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text("Camera")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [Color.purple, Color.pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(18)
                                .shadow(color: .purple.opacity(0.4), radius: 12, x: 0, y: 6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // 背景除去ボタン
                        if selectedImage != nil {
                            VStack(spacing: 12) {
                                // 人物選択モードの場合、選択ボタンと編集ボタンを表示
                                if showingPersonSelection {
                                    VStack(spacing: 12) {
                                        Text("Tap to select people")
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.8))
                                        
                                        // 編集モード切り替えボタン（モダンなデザイン）
                                        VStack(spacing: 12) {
                                            Button(action: {
                                                isEditingMask.toggle()
                                                if !isEditingMask {
                                                    maskEditMode = .none
                                                    editingPersonId = nil
                                                    lastEditLocation = nil  // リセット
                                                }
                                            }) {
                                                HStack(spacing: 8) {
                                                    Image(systemName: isEditingMask ? "pencil.circle.fill" : "pencil.circle")
                                                        .font(.system(size: 16, weight: .semibold))
                                                    Text(isEditingMask ? "Done" : "Edit Mask")
                                                        .font(.system(size: 15, weight: .semibold))
                                                }
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 10)
                                                .background(
                                                    isEditingMask ?
                                                    LinearGradient(
                                                        colors: [Color.orange, Color.orange.opacity(0.8)],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    ) :
                                                    LinearGradient(
                                                        colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .cornerRadius(14)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 14)
                                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                                )
                                            }
                                            
                                            if isEditingMask {
                                                // 編集モード選択（モダンなデザイン）
                                                HStack(spacing: 16) {
                                                    Button(action: {
                                                        maskEditMode = maskEditMode == .add ? .none : .add
                                                        if maskEditMode != .add {
                                                            maskEditMode = .remove
                                                        }
                                                    }) {
                                                        Image(systemName: maskEditMode == .add ? "plus.circle.fill" : "plus.circle")
                                                            .font(.system(size: 28, weight: .medium))
                                                            .foregroundColor(maskEditMode == .add ? .green : .white.opacity(0.7))
                                                            .frame(width: 44, height: 44)
                                                            .background(
                                                                Circle()
                                                                    .fill(maskEditMode == .add ? Color.green.opacity(0.2) : Color.clear)
                                                            )
                                                    }
                                                    
                                                    Button(action: {
                                                        maskEditMode = maskEditMode == .remove ? .none : .remove
                                                        if maskEditMode != .remove {
                                                            maskEditMode = .add
                                                        }
                                                    }) {
                                                        Image(systemName: maskEditMode == .remove ? "minus.circle.fill" : "minus.circle")
                                                            .font(.system(size: 28, weight: .medium))
                                                            .foregroundColor(maskEditMode == .remove ? .red : .white.opacity(0.7))
                                                            .frame(width: 44, height: 44)
                                                            .background(
                                                                Circle()
                                                                    .fill(maskEditMode == .remove ? Color.red.opacity(0.2) : Color.clear)
                                                            )
                                                    }
                                                    
                                                    // Brush size adjustment (modern design)
                                                    VStack(spacing: 6) {
                                                        Text("Brush Size")
                                                            .font(.system(size: 12, weight: .medium))
                                                            .foregroundColor(.white.opacity(0.8))
                                                        HStack(spacing: 8) {
                                                            Image(systemName: "circle.fill")
                                                                .font(.system(size: 8))
                                                                .foregroundColor(.white.opacity(0.6))
                                                            Slider(value: $brushSize, in: 1...20, step: 1)
                                                                .tint(.white.opacity(0.8))
                                                            Image(systemName: "circle.fill")
                                                                .font(.system(size: 16))
                                                                .foregroundColor(.white.opacity(0.6))
                                                        }
                                                        Text("\(Int(brushSize))px")
                                                            .font(.system(size: 11, weight: .medium))
                                                            .foregroundColor(.white.opacity(0.7))
                                                    }
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .fill(Color.white.opacity(0.1))
                                                    )
                                                }
                                            }
                                        }
                                    }
                                    
                                    Button(action: {
                                        processSelectedPerson()
                                    }) {
                                        HStack(spacing: 10) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 18, weight: .semibold))
                                            Text("Remove Background")
                                                .font(.system(size: 17, weight: .semibold))
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(
                                            LinearGradient(
                                                colors: [Color.green, Color.mint],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(18)
                                        .shadow(color: .green.opacity(0.4), radius: 12, x: 0, y: 6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                    }
                                    .disabled(detectedPersons.allSatisfy { !$0.isSelected })
                                    .opacity(detectedPersons.allSatisfy { !$0.isSelected } ? 0.5 : 1.0)
                                    
                                    Button(action: {
                                        showingPersonSelection = false
                                        detectedPersons = []
                                    }) {
                                        Text("Cancel")
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                } else {
                                    Button(action: {
                                        removeBackground()
                                    }) {
                                        HStack(spacing: 10) {
                                            if isProcessing {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    .scaleEffect(0.9)
                                                Text("Processing...")
                                                    .font(.system(size: 17, weight: .semibold))
                                            } else {
                                                Image(systemName: "wand.and.stars")
                                                    .font(.system(size: 18, weight: .semibold))
                                                Text("Remove Background")
                                                    .font(.system(size: 17, weight: .semibold))
                                            }
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(
                                            LinearGradient(
                                                colors: [Color.green, Color.mint],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(18)
                                        .shadow(color: .green.opacity(0.4), radius: 12, x: 0, y: 6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                    }
                                    .disabled(isProcessing)
                                    .opacity(isProcessing ? 0.7 : 1.0)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // 保存・共有ボタン（モダンなデザイン）
                        if processedImage != nil {
                            HStack(spacing: 16) {
                                Button(action: {
                                    saveToPhotoLibrary()
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "square.and.arrow.down")
                                            .font(.system(size: 18, weight: .semibold))
                                        Text("Save")
                                            .font(.system(size: 17, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.orange, Color.red],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(18)
                                    .shadow(color: .orange.opacity(0.4), radius: 12, x: 0, y: 6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                
                                Button(action: {
                                    showShareSheet = true
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 18, weight: .semibold))
                                        Text("Share")
                                            .font(.system(size: 17, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.cyan, Color.blue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(18)
                                    .shadow(color: .cyan.opacity(0.4), radius: 12, x: 0, y: 6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(
                sourceType: imagePickerSourceType,
                selectedImage: $selectedImage
            )
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = processedImage {
                ShareSheet(activityItems: [image])
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: selectedImage) { _ in
            processedImage = nil
            detectedPersons = []
            showingPersonSelection = false
        }
        .onAppear {
            // アプリ起動時にサンプル画像をフォトライブラリに追加
            addSampleImageToPhotoLibrary()
        }
    }
    
    // サンプル画像をフォトライブラリに追加
    func addSampleImageToPhotoLibrary() {
        // 既に追加済みかチェック（UserDefaultsで管理）
        let key = "sample_image_added"
        if UserDefaults.standard.bool(forKey: key) {
            return // 既に追加済み
        }
        
        // アセットから画像を読み込む
        guard let image = UIImage(named: "IMG_sample") else {
            return
        }
        
        // フォトライブラリへのアクセス許可を確認
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized || status == .limited {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }) { success, error in
                    if success {
                        // 追加成功を記録
                        UserDefaults.standard.set(true, forKey: key)
                        print("✅ サンプル画像をフォトライブラリに追加しました")
                    } else {
                        print("❌ サンプル画像の追加に失敗: \(error?.localizedDescription ?? "不明なエラー")")
                    }
                }
            }
        }
    }
    
    // 実際の画像表示サイズを計算（aspectRatio(.fit)と同じロジック）
    func calculateActualImageSize(imageSize: CGSize, viewSize: CGSize) -> CGSize {
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height
        
        if imageAspect > viewAspect {
            // 画像の方が横長：幅に合わせる
            let scale = viewSize.width / imageSize.width
            return CGSize(
                width: viewSize.width,
                height: imageSize.height * scale
            )
        } else {
            // 画像の方が縦長：高さに合わせる
            let scale = viewSize.height / imageSize.height
            return CGSize(
                width: imageSize.width * scale,
                height: viewSize.height
            )
        }
    }
    
    // 画像を適切な向きとサイズに調整（向きを正しく修正）
    func prepareImage(_ image: UIImage) -> UIImage? {
        // 画像の向きを正しく修正（より確実な方法）
        let orientedImage = image.fixedOrientation()
        
        guard let orientedImage = orientedImage else {
            print("❌ [DEBUG] 画像の向き修正に失敗")
            return nil
        }
        
        print("✅ [DEBUG] 向き修正完了: \(orientedImage.size), 向き: \(orientedImage.imageOrientation.rawValue)")
        
        // 実機ではより大きなサイズで処理可能（精度向上のため）
        #if targetEnvironment(simulator)
        let maxDimension: CGFloat = 1024  // シミュレータ用
        #else
        let maxDimension: CGFloat = 2048  // 実機用（より高精度）
        #endif
        
        let size = orientedImage.size
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        
        var processedImage = orientedImage
        
        if scale < 1.0 {
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            orientedImage.draw(in: CGRect(origin: .zero, size: newSize))
            if let resizedImage = UIGraphicsGetImageFromCurrentImageContext() {
                processedImage = resizedImage
            }
            UIGraphicsEndImageContext()
            print("✅ [DEBUG] リサイズ完了: \(newSize)")
        }
        
        return processedImage
    }
    
    // 背景除去処理
    func removeBackground() {
        guard let image = selectedImage else { return }
        
        // 背景除去をリセット：処理済み画像をクリアして、元画像から一から実行
        processedImage = nil
        detectedPersons = []
        showingPersonSelection = false
        isEditingMask = false
        maskEditMode = .none
        
        #if targetEnvironment(simulator)
        // シミュレータ用: Vision Frameworkが動作しないため、適切なメッセージを表示
        removeBackgroundSimulator(image: image)
        #else
        // 実機用: Vision Frameworkを使用
        removeBackgroundDevice(image: image)
        #endif
    }
    
    // シミュレータ用の背景除去処理（モック実装）
    func removeBackgroundSimulator(image: UIImage) {
        isProcessing = true
        print("🔵 [DEBUG] シミュレータ環境: 背景除去処理を開始（モック）")
        
        DispatchQueue.global(qos: .userInitiated).async {
            // シミュレータではVision Frameworkが動作しないため、適切なメッセージを表示
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isProcessing = false
                self.alertTitle = "シミュレータでは動作しません"
                self.alertMessage = "Vision Frameworkの人物セグメンテーションは、Neural Engineが必要なため、シミュレータでは動作しません。\n\n実機（iPhone/iPad）でテストしてください。\n\n実機では正常に動作します。"
                self.showAlert = true
            }
        }
    }
    
    // 実機用の背景除去処理
    func removeBackgroundDevice(image: UIImage) {
        isProcessing = true
        print("🔵 [DEBUG] 実機環境: 背景除去処理を開始")
        print("🔵 [DEBUG] 元画像サイズ: \(image.size)")
        print("🔵 [DEBUG] 元画像の向き: \(image.imageOrientation.rawValue)")
        
        // バックグラウンドスレッドで処理
        DispatchQueue.global(qos: .userInitiated).async {
            // 画像を前処理（向き修正、リサイズ）
            guard let preparedImage = self.prepareImage(image) else {
                print("❌ [DEBUG] 画像の前処理に失敗")
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.alertTitle = "エラー"
                    self.alertMessage = "画像の準備に失敗しました。別の画像を試してください。"
                    self.showAlert = true
                }
                return
            }
            
            print("✅ [DEBUG] 画像の前処理完了: \(preparedImage.size)")
            
            // CIImageに変換
            guard let ciImage = CIImage(image: preparedImage) else {
                print("❌ [DEBUG] CIImageへの変換に失敗")
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.alertTitle = "エラー"
                    self.alertMessage = "画像の読み込みに失敗しました。別の画像を試してください。"
                    self.showAlert = true
                }
                return
            }
            
            print("✅ [DEBUG] CIImage作成完了: \(ciImage.extent)")
            
            // 顔検出リクエストを作成（人物セグメンテーションと同時に実行）
            var detectedFacePositions: [CGPoint] = []
            let faceRequest = VNDetectFaceRectanglesRequest { request, error in
                if let error = error {
                    print("⚠️ [DEBUG] 顔検出エラー: \(error.localizedDescription)")
                    return
                }
                
                guard let observations = request.results as? [VNFaceObservation] else {
                    print("🔵 [DEBUG] 顔が検出されませんでした")
                    return
                }
                
                print("✅ [DEBUG] 顔検出成功: \(observations.count)個の顔を検出")
                
                // 検出された顔の位置を正規化座標で保存
                detectedFacePositions = observations.map { observation in
                    // VNFaceObservationのboundingBoxは正規化座標（0.0〜1.0）で返される
                    // ただし、Y座標は下から上なので、上から下に変換
                    let faceCenter = CGPoint(
                        x: observation.boundingBox.midX,
                        y: 1.0 - observation.boundingBox.midY  // Y座標を反転
                    )
                    print("🔵 [DEBUG] 顔の位置: (\(faceCenter.x), \(faceCenter.y))")
                    return faceCenter
                }
            }
            
            // 人体矩形検出リクエスト（一旦コメントアウト：マスクが伸びる原因の可能性）
            // マスクの範囲を超えたバウンディングボックスが設定されるため、一旦無効化
            /*
            var detectedHumanRectangles: [CGRect] = []
            let humanRectanglesRequest = VNDetectHumanRectanglesRequest { request, error in
                if let error = error {
                    print("⚠️ [DEBUG] 人体矩形検出エラー: \(error.localizedDescription)")
                    return
                }
                
                guard let observations = request.results as? [VNDetectedObjectObservation] else {
                    print("🔵 [DEBUG] 人体矩形が検出されませんでした")
                    return
                }
                
                print("✅ [DEBUG] 人体矩形検出成功: \(observations.count)個の人体矩形を検出")
                
                // 検出された人体矩形の位置を保存（正規化座標）
                detectedHumanRectangles = observations.map { observation in
                    // VNDetectedObjectObservationのboundingBoxは正規化座標（0.0〜1.0）で返される
                    // Y座標は下から上なので、上から下に変換
                    let rect = observation.boundingBox
                    let normalizedRect = CGRect(
                        x: rect.origin.x,
                        y: 1.0 - rect.origin.y - rect.height,  // Y座標を反転
                        width: rect.width,
                        height: rect.height
                    )
                    print("🔵 [DEBUG] 人体矩形: (\(normalizedRect.origin.x), \(normalizedRect.origin.y)), サイズ: (\(normalizedRect.width), \(normalizedRect.height))")
                    return normalizedRect
                }
            }
            */
            var detectedHumanRectangles: [CGRect] = []  // 空配列として定義
            
            // 体の姿勢検出リクエストを作成（解決策2）
            var detectedBodyPoses: [[VNHumanBodyPoseObservation.JointName: CGPoint]] = []
            let bodyPoseRequest = VNDetectHumanBodyPoseRequest { request, error in
                if let error = error {
                    print("⚠️ [DEBUG] 体の姿勢検出エラー: \(error.localizedDescription)")
                    return
                }
                
                guard let observations = request.results as? [VNHumanBodyPoseObservation] else {
                    print("🔵 [DEBUG] 体の姿勢が検出されませんでした")
                    return
                }
                
                print("✅ [DEBUG] 体の姿勢検出成功: \(observations.count)個の人物を検出")
                
                // 各人物の関節位置を保存
                detectedBodyPoses = observations.map { observation in
                    var posePoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
                    
                    // 主要な関節を取得
                    let jointNames: [VNHumanBodyPoseObservation.JointName] = [
                        .nose, .neck, .root, .leftShoulder, .rightShoulder,
                        .leftElbow, .rightElbow, .leftWrist, .rightWrist,
                        .leftHip, .rightHip, .leftKnee, .rightKnee,
                        .leftAnkle, .rightAnkle
                    ]
                    
                    for jointName in jointNames {
                        do {
                            let point = try observation.recognizedPoint(jointName)
                            if point.confidence > 0.3 {  // 信頼度が高い場合のみ
                                // 正規化座標を画像座標系に変換（Y座標を反転）
                                posePoints[jointName] = CGPoint(
                                    x: point.location.x,
                                    y: 1.0 - point.location.y
                                )
                            }
        } catch {
                            // 関節が検出されなかった場合はスキップ
                        }
                    }
                    
                    return posePoints
                }
            }
            
            // Vision リクエストを作成
            let request = VNGeneratePersonSegmentationRequest { request, error in
                print("🔵 [DEBUG] Vision リクエストのコールバックが呼ばれました")
                
                // エラーが発生した場合の処理
                if let error = error {
                    print("⚠️ [DEBUG] Vision エラー発生: \(error.localizedDescription)")
                    print("⚠️ [DEBUG] エラードメイン: \((error as NSError).domain)")
                    print("⚠️ [DEBUG] エラーコード: \((error as NSError).code)")
                    
                    // エラーが発生しても、結果がある場合は処理を続行
                    if let results = request.results, !results.isEmpty {
                        print("✅ [DEBUG] エラーがあるが結果も存在: \(results.count)件")
                        // 結果があるので処理を続行
                    } else {
                        print("❌ [DEBUG] エラーがあり、結果もなし")
                        // エラーで結果もない場合は、人物が検出されなかったと判断
                        DispatchQueue.main.async {
                            self.isProcessing = false
                            self.alertTitle = "人物が検出されませんでした"
                            self.alertMessage = "Vision Frameworkで人物を検出できませんでした。\n\nデバッグ情報:\nエラー: \(error.localizedDescription)\n\n以下の点を確認してください：\n• 人物がはっきり写っている写真\n• 人物が画面の中央付近に写っている\n• 背景と人物のコントラストがはっきりしている"
                            self.showAlert = true
                        }
            return
                    }
                } else {
                    print("✅ [DEBUG] エラーなし")
                }
                
                // 結果の確認
                if let results = request.results {
                    print("🔵 [DEBUG] 検出結果数: \(results.count)")
                    for (index, observation) in results.enumerated() {
                        print("🔵 [DEBUG] 結果[\(index)]: \(type(of: observation))")
                        if let pixelBufferObs = observation as? VNPixelBufferObservation {
                            let maskSize = CVPixelBufferGetWidth(pixelBufferObs.pixelBuffer)
                            let maskHeight = CVPixelBufferGetHeight(pixelBufferObs.pixelBuffer)
                            print("🔵 [DEBUG] マスクサイズ: \(maskSize)x\(maskHeight)")
                        }
                    }
                } else {
                    print("❌ [DEBUG] 検出結果がnil")
                }
                
                // 人物が検出されなかった場合をチェック
                guard let results = request.results, !results.isEmpty,
                      let result = results.first as? VNPixelBufferObservation else {
                    print("❌ [DEBUG] 人物が検出されませんでした（結果なしまたは空）")
                    DispatchQueue.main.async {
                        self.isProcessing = false
                        self.alertTitle = "人物が検出されませんでした"
                        self.alertMessage = "Vision Frameworkで人物を検出できませんでした。\n\n以下の点を確認してください：\n• 人物がはっきり写っている写真\n• 人物が画面の中央付近に写っている\n• 背景と人物のコントラストがはっきりしている\n\nXcodeのコンソールにデバッグ情報が表示されています。"
                        self.showAlert = true
                    }
                    return
                }
                
                print("✅ [DEBUG] 人物検出成功！マスクを取得")
                
                // マスクの後処理（ノイズ除去、エッジの平滑化）で精度を向上
                let processedMask = self.postProcessMask(result.pixelBuffer)
                
                // 複数人物を検出して、各人物の領域を計算（顔の位置情報、人体矩形、体の姿勢も含める）
                let persons = self.detectMultiplePersons(
                    from: processedMask,
                    imageSize: preparedImage.size,
                    facePositions: detectedFacePositions,
                    humanRectangles: detectedHumanRectangles,
                    bodyPoses: detectedBodyPoses
                )
                print("🔵 [DEBUG] 検出された人物数: \(persons.count)")
                
                // 顔の位置情報をメインスレッドに保存
                DispatchQueue.main.async {
                    self.detectedFaces = detectedFacePositions
                }
                
                // 1人以上検出された場合、選択モードを表示（編集可能にするため）
                if persons.count >= 1 {
                    // 1人の場合は自動選択
                    if persons.count == 1 {
                        var updatedPersons = persons
                        updatedPersons[0].isSelected = true
                        DispatchQueue.main.async {
                            self.detectedPersons = updatedPersons
                            self.showingPersonSelection = true
                            self.isProcessing = false
                            print("✅ [DEBUG] 1人物を検出。選択モードを表示（編集可能）")
                        }
                    } else {
                        // 複数人物が検出された場合、近いグループごとに分離して選択モードを表示
                        let groupedPersons = self.groupPersonsByProximity(persons)
                        DispatchQueue.main.async {
                            // グループごとに分離された人物を表示
                            self.detectedPersons = persons
                            self.showingPersonSelection = true
                            self.isProcessing = false
                            print("✅ [DEBUG] 複数人物を検出（\(groupedPersons.count)グループ）。選択モードを表示")
                        }
                    }
                    return
                }
                
                // 選択済みの人物がいる場合、複数選択に対応してマスクを統合
                let maskToUse: CVPixelBuffer
                let selectedPersons = persons.filter { $0.isSelected }
                if !selectedPersons.isEmpty {
                    // 複数選択されている場合、マスクを統合
                    maskToUse = self.combineMasks(selectedPersons.map { $0.maskBuffer }) ?? processedMask
                } else {
                    maskToUse = processedMask
                }
                
                // マスクを使って透過画像を生成（向きが修正された画像を使用）
                // preparedImageを使用することで、向きが正しく処理された画像で透過画像を生成
                let processed = self.createTransparentImage(from: preparedImage, maskBuffer: maskToUse)
                
                guard let processed = processed else {
                    print("❌ [DEBUG] 透過画像の生成に失敗")
                    DispatchQueue.main.async {
                        self.isProcessing = false
                        self.alertTitle = "エラー"
                        self.alertMessage = "画像の処理に失敗しました。別の画像を試してください。"
                        self.showAlert = true
                    }
                    return
                }
                
                print("✅ [DEBUG] 透過画像生成成功！")
                
                DispatchQueue.main.async {
                    self.processedImage = processed
                    self.isProcessing = false
                    print("✅ [DEBUG] 処理完了！")
                }
            }
            
            // リクエストの設定を最適化（実機用）
            // 実機ではNeural Engineが利用可能なため、高精度モードを使用可能
            request.qualityLevel = .accurate  // 実機では高精度モードを使用
            request.outputPixelFormat = kCVPixelFormatType_OneComponent8
            
            print("🔵 [DEBUG] Vision リクエスト設定完了")
            print("🔵 [DEBUG] Quality Level: \(request.qualityLevel.rawValue)")
            print("🔵 [DEBUG] リクエストを実行します...")
            
            // CIImageから直接ハンドラーを作成（向き情報を含める）
            let handler = VNImageRequestHandler(ciImage: ciImage, orientation: .up, options: [:])
            
            do {
                let startTime = Date()
                // 人物セグメンテーション、顔検出、体の姿勢検出を同時に実行
                // 人体矩形検出は一旦コメントアウト（マスクが伸びる原因の可能性）
                try handler.perform([request, faceRequest, bodyPoseRequest])
                // try handler.perform([request, faceRequest, humanRectanglesRequest, bodyPoseRequest])
                let elapsedTime = Date().timeIntervalSince(startTime)
                print("✅ [DEBUG] リクエスト実行完了（所要時間: \(String(format: "%.2f", elapsedTime))秒）")
        } catch {
                print("❌ [DEBUG] リクエスト実行エラー: \(error.localizedDescription)")
                print("❌ [DEBUG] エラーの詳細: \(error)")
                // エラーが発生した場合でも、人物が検出されなかった可能性が高い
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.alertTitle = "人物が検出されませんでした"
                    self.alertMessage = "Vision Frameworkの実行中にエラーが発生しました。\n\nエラー: \(error.localizedDescription)\n\nXcodeのコンソールに詳細なデバッグ情報が表示されています。"
                    self.showAlert = true
                }
            }
        }
    }
    
    // マスクを使って透過画像を生成
    func createTransparentImage(from image: UIImage, maskBuffer: CVPixelBuffer) -> UIImage? {
        // より確実な方法: 手動でアルファチャンネルを設定
        return createTransparentImageManual(from: image, maskBuffer: maskBuffer)
    }
    
    // 手動で透過画像を生成
    func createTransparentImageManual(from image: UIImage, maskBuffer: CVPixelBuffer) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // マスクデータを取得
        CVPixelBufferLockBaseAddress(maskBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(maskBuffer, []) }
        
        guard let maskBaseAddress = CVPixelBufferGetBaseAddress(maskBuffer) else { return nil }
        let maskBytesPerRow = CVPixelBufferGetBytesPerRow(maskBuffer)
        let maskWidth = CVPixelBufferGetWidth(maskBuffer)
        let maskHeight = CVPixelBufferGetHeight(maskBuffer)
        
        // 新しい画像データを作成（RGBAお
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        // 透過画像用のコンテキストを作成（premultiplied alpha）
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        // 元画像を描画（一時的に）
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else { return nil }
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        
        // マスクを適用してアルファチャンネルを設定
        // 背景部分は完全に透明（RGBも0）にする
        for y in 0..<height {
            let maskY = Int(Float(y) / Float(height) * Float(maskHeight))
            guard maskY < maskHeight else { continue }
            
            for x in 0..<width {
                let maskX = Int(Float(x) / Float(width) * Float(maskWidth))
                guard maskX < maskWidth else { continue }
                
                let pixelIndex = (y * width + x) * bytesPerPixel
                let maskIndex = maskY * maskBytesPerRow + maskX
                
                let maskValue = maskBaseAddress.assumingMemoryBound(to: UInt8.self)[maskIndex]
                let alpha = Float(maskValue) / 255.0
                
                // 背景部分（マスク値が低い）は完全に透明にする
                if maskValue < 128 {
                    // 背景部分は完全に透明（RGBも0）
                    pixels[pixelIndex + 0] = 0  // R
                    pixels[pixelIndex + 1] = 0  // G
                    pixels[pixelIndex + 2] = 0  // B
                    pixels[pixelIndex + 3] = 0  // A (完全に透明)
                } else {
                    // 人物部分はアルファ値を適用（premultiplied alpha）
                    // 現在のRGB値を取得して、アルファ値で乗算
                    let currentR = Float(pixels[pixelIndex + 0])
                    let currentG = Float(pixels[pixelIndex + 1])
                    let currentB = Float(pixels[pixelIndex + 2])
                    
                    // premultiplied alpha: RGB = RGB * alpha
                    pixels[pixelIndex + 0] = UInt8(currentR * alpha)  // R (premultiplied)
                    pixels[pixelIndex + 1] = UInt8(currentG * alpha)  // G (premultiplied)
                    pixels[pixelIndex + 2] = UInt8(currentB * alpha)  // B (premultiplied)
                    pixels[pixelIndex + 3] = maskValue  // A
                }
            }
        }
        
        guard let finalCGImage = context.makeImage() else { return nil }
        
        // 透過情報を保持したUIImageを作成
        // CGImageAlphaInfoを確認して、透過情報が保持されていることを確認
        let image = UIImage(cgImage: finalCGImage, scale: 1.0, orientation: .up)
        
        // デバッグ: アルファチャンネルの有無を確認
        if let cgImage = image.cgImage {
            let alphaInfo = cgImage.alphaInfo
            print("🔵 [DEBUG] 透過画像のアルファ情報: \(alphaInfo.rawValue)")
            print("🔵 [DEBUG] アルファチャンネルあり: \(alphaInfo != .none && alphaInfo != .noneSkipFirst && alphaInfo != .noneSkipLast)")
        }
        
        return image
    }
    
    // 写真ライブラリに保存（透過PNGとして保存）
    func saveToPhotoLibrary() {
        guard let image = processedImage else { return }
        
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized || status == .limited {
                // CGImageから直接透過PNGデータを生成（より確実な方法）
                guard let cgImage = image.cgImage else {
                    DispatchQueue.main.async {
                        self.alertMessage = "画像の取得に失敗しました"
                        self.showAlert = true
                    }
                    return
                }
                
                // CGImageから透過PNGデータを生成
                let mutableData = NSMutableData()
                guard let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil) else {
                    DispatchQueue.main.async {
                        self.alertMessage = "PNGデータの生成に失敗しました"
                        self.showAlert = true
                    }
                    return
                }
                
                // 透過情報を保持したままPNGデータを生成
                CGImageDestinationAddImage(destination, cgImage, nil)
                guard CGImageDestinationFinalize(destination) else {
                    DispatchQueue.main.async {
                        self.alertMessage = "PNGデータの生成に失敗しました"
                        self.showAlert = true
                    }
                    return
                }
                
                let pngData = mutableData as Data
                print("🔵 [DEBUG] PNGデータサイズ: \(pngData.count) bytes")
                
                // 透過PNGとして保存（PHAssetCreationRequestを使用）
                PHPhotoLibrary.shared().performChanges({
                    // PHAssetCreationRequestを使用してPNGデータを直接保存
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .photo, data: pngData, options: nil)
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            self.alertMessage = "透過PNGとして写真ライブラリに保存しました"
                            print("✅ [DEBUG] 透過PNGの保存に成功")
                        } else {
                            self.alertMessage = "保存に失敗しました: \(error?.localizedDescription ?? "不明なエラー")"
                            print("❌ [DEBUG] 透過PNGの保存に失敗: \(error?.localizedDescription ?? "不明なエラー")")
                        }
                        self.showAlert = true
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.alertMessage = "写真ライブラリへのアクセス許可が必要です"
                    self.showAlert = true
                }
            }
        }
    }
    
    // マスクを後処理（ノイズ除去、エッジの平滑化）
    func postProcessMask(_ maskBuffer: CVPixelBuffer) -> CVPixelBuffer {
        // マスクデータを取得
        CVPixelBufferLockBaseAddress(maskBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(maskBuffer, []) }
        
        guard let maskBaseAddress = CVPixelBufferGetBaseAddress(maskBuffer) else {
            return maskBuffer
        }
        
        let maskBytesPerRow = CVPixelBufferGetBytesPerRow(maskBuffer)
        let maskWidth = CVPixelBufferGetWidth(maskBuffer)
        let maskHeight = CVPixelBufferGetHeight(maskBuffer)
        
        // マスクのピクセルデータを読み取り
        let maskPointer = maskBaseAddress.assumingMemoryBound(to: UInt8.self)
        
        // マスクのコピーを作成（元のマスクを変更しないため）
        var maskPixels = [UInt8](repeating: 0, count: maskHeight * maskWidth)
        for y in 0..<maskHeight {
            for x in 0..<maskWidth {
                let idx = y * maskBytesPerRow + x
                maskPixels[y * maskWidth + x] = maskPointer[idx]
            }
        }
        
        // モルフォロジー演算：小さなノイズを除去
        // 拡張（dilation）と収縮（erosion）を適用
        let processedPixels = applyMorphology(to: maskPixels, width: maskWidth, height: maskHeight)
        
        // 新しいマスクバッファを作成（元のマスクを変更しないため）
        var outputBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            maskWidth,
            maskHeight,
            kCVPixelFormatType_OneComponent8,
            nil,
            &outputBuffer
        )
        
        guard status == kCVReturnSuccess, let output = outputBuffer else {
            print("⚠️ [DEBUG] マスクバッファの作成に失敗。元のマスクを返します")
            return maskBuffer
        }
        
        CVPixelBufferLockBaseAddress(output, [])
        defer { CVPixelBufferUnlockBaseAddress(output, []) }
        
        guard let outputBaseAddress = CVPixelBufferGetBaseAddress(output) else {
            return maskBuffer
        }
        
        let outputPointer = outputBaseAddress.assumingMemoryBound(to: UInt8.self)
        let outputBytesPerRow = CVPixelBufferGetBytesPerRow(output)
        
        // 処理済みマスクを新しいバッファに書き込む
        for y in 0..<maskHeight {
            for x in 0..<maskWidth {
                let outputIdx = y * outputBytesPerRow + x
                outputPointer[outputIdx] = processedPixels[y * maskWidth + x]
            }
        }
        
        print("✅ [DEBUG] マスクの後処理完了（ノイズ除去）")
        return output
    }
    
    // モルフォロジー演算を適用（ノイズ除去）
    func applyMorphology(to pixels: [UInt8], width: Int, height: Int) -> [UInt8] {
        var result = pixels
        
        // 収縮（erosion）：小さなノイズを除去
        var eroded = [UInt8](repeating: 0, count: width * height)
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var minValue: UInt8 = 255
                for ky in -1...1 {
                    for kx in -1...1 {
                        let idx = (y + ky) * width + (x + kx)
                        minValue = min(minValue, pixels[idx])
                    }
                }
                eroded[y * width + x] = minValue
            }
        }
        
        // 拡張（dilation）：人物の領域を拡大
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var maxValue: UInt8 = 0
                for ky in -1...1 {
                    for kx in -1...1 {
                        let idx = (y + ky) * width + (x + kx)
                        maxValue = max(maxValue, eroded[idx])
                    }
                }
                result[y * width + x] = maxValue
            }
        }
        
        return result
    }
    
    // 複数人物を検出（マスクから連結成分を検出、顔の位置情報、人体矩形、体の姿勢も考慮）
    func detectMultiplePersons(from maskBuffer: CVPixelBuffer, imageSize: CGSize, facePositions: [CGPoint] = [], humanRectangles: [CGRect] = [], bodyPoses: [[VNHumanBodyPoseObservation.JointName: CGPoint]] = []) -> [DetectedPerson] {
        CVPixelBufferLockBaseAddress(maskBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(maskBuffer, []) }
        
        guard let maskBaseAddress = CVPixelBufferGetBaseAddress(maskBuffer) else {
            return []
        }
        
        let maskBytesPerRow = CVPixelBufferGetBytesPerRow(maskBuffer)
        let maskWidth = CVPixelBufferGetWidth(maskBuffer)
        let maskHeight = CVPixelBufferGetHeight(maskBuffer)
        let maskPointer = maskBaseAddress.assumingMemoryBound(to: UInt8.self)
        
        // 連結成分解析（Connected Component Analysis）で各人物の領域を検出
        var visited = Array(repeating: Array(repeating: false, count: maskWidth), count: maskHeight)
        var persons: [DetectedPerson] = []
        // しきい値を下げることで、より多くの人物を検出（複数人対応）
        let threshold: UInt8 = 100  // 128から100に下げて、より多くの人物を検出
        
        // 各ピクセルをチェックして、未訪問の人物ピクセルから連結成分を検出
        for y in 0..<maskHeight {
            for x in 0..<maskWidth {
                let maskIndex = y * maskBytesPerRow + x
                let maskValue = maskPointer[maskIndex]
                
                // 人物ピクセルで、まだ訪問していない場合
                if maskValue >= threshold && !visited[y][x] {
                    // 連結成分を検出（フラッドフィル）
                    var component: [(Int, Int)] = []
                    var queue: [(Int, Int)] = [(x, y)]
                    visited[y][x] = true
                    
                    // バウンディングボックスの初期値
                    var minX = x, maxX = x
                    var minY = y, maxY = y
                    
                    // フラッドフィルで連結成分を収集
                    while !queue.isEmpty {
                        let (cx, cy) = queue.removeFirst()
                        component.append((cx, cy))
                        
                        // 8方向の隣接ピクセルをチェック
                        for dy in -1...1 {
                            for dx in -1...1 {
                                if dx == 0 && dy == 0 { continue }
                                
                                let nx = cx + dx
                                let ny = cy + dy
                                
                                if nx >= 0 && nx < maskWidth && ny >= 0 && ny < maskHeight && !visited[ny][nx] {
                                    let neighborIndex = ny * maskBytesPerRow + nx
                                    let neighborValue = maskPointer[neighborIndex]
                                    
                                    if neighborValue >= threshold {
                                        visited[ny][nx] = true
                                        queue.append((nx, ny))
                                        
                                        // バウンディングボックスを更新
                                        minX = min(minX, nx)
                                        maxX = max(maxX, nx)
                                        minY = min(minY, ny)
                                        maxY = max(maxY, ny)
                                    }
                                }
                            }
                        }
                    }
                    
                    // 十分な大きさの連結成分のみを人物として扱う（ノイズ除去）
                    let componentSize = component.count
                    let minComponentSize = (maskWidth * maskHeight) / 1000  // 画像の0.1%以上
                    
                    if componentSize >= minComponentSize {
                        // この人物のマスクを作成（選択された人物のみを残す）
                        let personMask = createPersonMask(from: maskBuffer, component: component, maskWidth: maskWidth, maskHeight: maskHeight, maskBytesPerRow: maskBytesPerRow)
                        
                        if let personMask = personMask {
                            // マスクの実際の範囲を正確に計算（ピクセル単位）
                            // 注意: maxX, maxYは包含的（inclusive）なので、幅と高さは maxX - minX + 1, maxY - minY + 1
                            // ただし、正規化座標では +1 は不要（既にピクセル単位で計算済み）
                            
                            // 人物の中心座標を計算（正規化座標）
                            let personCenter = CGPoint(
                                x: (CGFloat(minX) + CGFloat(maxX)) / 2.0 / CGFloat(maskWidth),
                                y: (CGFloat(minY) + CGFloat(maxY)) / 2.0 / CGFloat(maskHeight)
                            )
                            
                            // 人物のバウンディングボックス（正規化座標、マスクの実際の範囲）
                            // マスクの範囲を正確に反映（+1はピクセル単位の計算に含まれるが、正規化座標では不要）
                            let personBoundingBox = CGRect(
                                x: CGFloat(minX) / CGFloat(maskWidth),
                                y: CGFloat(minY) / CGFloat(maskHeight),
                                width: CGFloat(maxX - minX + 1) / CGFloat(maskWidth),  // ピクセル単位で+1が必要
                                height: CGFloat(maxY - minY + 1) / CGFloat(maskHeight)  // ピクセル単位で+1が必要
                            )
                            
                            // バウンディングボックスを決定
                            // マスクの実際の範囲を使用（マスクが伸びる問題を防ぐ）
                            // マスクの範囲を超えないように、0.0〜1.0の範囲に厳密に制限
                            let clampedX = max(0.0, min(1.0, personBoundingBox.origin.x))
                            let clampedY = max(0.0, min(1.0, personBoundingBox.origin.y))
                            let maxWidth = 1.0 - clampedX
                            let maxHeight = 1.0 - clampedY
                            let clampedWidth = max(0.0, min(maxWidth, personBoundingBox.width))
                            let clampedHeight = max(0.0, min(maxHeight, personBoundingBox.height))
                            
                            let finalBoundingBox = CGRect(
                                x: clampedX,
                                y: clampedY,
                                width: clampedWidth,
                                height: clampedHeight
                            )
                            
                            // デバッグ: バウンディングボックスが範囲内か確認
                            if finalBoundingBox.maxX > 1.0 || finalBoundingBox.maxY > 1.0 || finalBoundingBox.minX < 0.0 || finalBoundingBox.minY < 0.0 {
                                print("⚠️ [DEBUG] バウンディングボックスが範囲外: \(finalBoundingBox)")
                            }
                            
                            // 人体矩形検出結果との関連付け（一旦コメントアウト）
                            /*
                            // 注意: 人体矩形検出結果はマスクの範囲を超える可能性があるため、
                            // マスクの実際の範囲（personBoundingBox）を優先し、人体矩形は参考程度に使用
                            var bestHumanRectangle: CGRect?
                            var minRectangleOverlap: CGFloat = 0.0
                            
                            for humanRect in humanRectangles {
                                // 矩形の重なり（IoU: Intersection over Union）を計算
                                let intersection = personBoundingBox.intersection(humanRect)
                                let union = personBoundingBox.union(humanRect)
                                let overlap = intersection.area / union.area
                                
                                if overlap > minRectangleOverlap && overlap > 0.3 {  // 30%以上の重なりが必要
                                    minRectangleOverlap = overlap
                                    bestHumanRectangle = humanRect
                                }
                            }
                            
                            // バウンディングボックスを決定
                            // 人体矩形が見つかった場合でも、マスクの範囲内に制限する
                            let finalBoundingBox: CGRect
                            if let humanRect = bestHumanRectangle {
                                // 人体矩形とマスクのバウンディングボックスの交差を取る
                                // これにより、マスクの範囲を超えないようにする
                                let intersection = personBoundingBox.intersection(humanRect)
                                if intersection.width > 0 && intersection.height > 0 {
                                    // 交差が有効な場合、マスクの範囲内に制限したバウンディングボックスを使用
                                    finalBoundingBox = personBoundingBox  // マスクの範囲を優先
                                    print("🔵 [DEBUG] 人体矩形を参考に使用（マスク範囲内に制限）: 重なり=\(minRectangleOverlap)")
                                } else {
                                    // 交差がない場合は、マスクのバウンディングボックスを使用
                                    finalBoundingBox = personBoundingBox
                                }
                            } else {
                                // 人体矩形が見つからない場合は、マスクのバウンディングボックスを使用
                                finalBoundingBox = personBoundingBox
                            }
                            */
                            
                            // 顔の位置情報と人物領域を関連付け
                            var associatedFace: CGPoint?
                            var minFaceDistance = CGFloat.greatestFiniteMagnitude
                            
                            for facePosition in facePositions {
                                // 顔の位置が人物のバウンディングボックス内にあるかチェック
                                if finalBoundingBox.contains(facePosition) {
                                    let faceDistance = sqrt(
                                        pow(personCenter.x - facePosition.x, 2) +
                                        pow(personCenter.y - facePosition.y, 2)
                                    )
                                    
                                    if faceDistance < minFaceDistance {
                                        minFaceDistance = faceDistance
                                        associatedFace = facePosition
                                    }
                                }
                            }
                            
                            // 顔との距離が近い場合（例: 0.15以内）のみ顔の位置を保存
                            let faceThreshold: CGFloat = 0.15
                            let finalAssociatedFace = minFaceDistance < faceThreshold ? associatedFace : nil
                            
                            if let face = finalAssociatedFace {
                                print("🔵 [DEBUG] 人物と顔を関連付け: 距離=\(minFaceDistance)")
                            }
                            
                            // 体の姿勢と人物領域を関連付け
                            var associatedBodyPose: [VNHumanBodyPoseObservation.JointName: CGPoint]?
                            var minPoseDistance = CGFloat.greatestFiniteMagnitude
                            
                            for bodyPose in bodyPoses {
                                // 首の位置を基準に関連付け
                                if let neckPosition = bodyPose[.neck] {
                                    // 首の位置が人物のバウンディングボックス内にあるかチェック
                                    if finalBoundingBox.contains(neckPosition) {
                                        let poseDistance = sqrt(
                                            pow(personCenter.x - neckPosition.x, 2) +
                                            pow(personCenter.y - neckPosition.y, 2)
                                        )
                                        
                                        if poseDistance < minPoseDistance {
                                            minPoseDistance = poseDistance
                                            associatedBodyPose = bodyPose
                                        }
                                    }
                                }
                            }
                            
                            // 体の姿勢との距離が近い場合（例: 0.2以内）のみ関連付け
                            let poseThreshold: CGFloat = 0.2
                            let finalBodyPose = minPoseDistance < poseThreshold ? associatedBodyPose : nil
                            
                            if finalBodyPose != nil {
                                print("🔵 [DEBUG] 人物と体の姿勢を関連付け: 距離=\(minPoseDistance)")
                            }
                            
                            persons.append(DetectedPerson(
                                maskBuffer: personMask,
                                boundingBox: finalBoundingBox,  // 人体矩形検出結果を使用
                                isSelected: false,
                                facePosition: finalAssociatedFace,
                                bodyPosePoints: finalBodyPose
                            ))
                        }
                    }
                }
            }
        }
        
        print("🔵 [DEBUG] 検出された人物数: \(persons.count)")
        return persons
    }
    
    // 特定の人物のマスクを作成（選択された人物のみを残す）
    func createPersonMask(from originalMask: CVPixelBuffer, component: [(Int, Int)], maskWidth: Int, maskHeight: Int, maskBytesPerRow: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            maskWidth,
            maskHeight,
            kCVPixelFormatType_OneComponent8,
            nil,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let outputBuffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(outputBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(outputBuffer, []) }
        
        guard let outputBaseAddress = CVPixelBufferGetBaseAddress(outputBuffer) else {
            return nil
        }
        
        let outputPointer = outputBaseAddress.assumingMemoryBound(to: UInt8.self)
        let outputBytesPerRow = CVPixelBufferGetBytesPerRow(outputBuffer)
        
        // 初期化（すべて背景）
        for y in 0..<maskHeight {
            for x in 0..<maskWidth {
                let index = y * outputBytesPerRow + x
                outputPointer[index] = 0
            }
        }
        
        // 選択された人物のピクセルのみを残す
        CVPixelBufferLockBaseAddress(originalMask, [])
        defer { CVPixelBufferUnlockBaseAddress(originalMask, []) }
        
        guard let originalBaseAddress = CVPixelBufferGetBaseAddress(originalMask) else {
            return nil
        }
        
        let originalPointer = originalBaseAddress.assumingMemoryBound(to: UInt8.self)
        
        for (x, y) in component {
            let originalIndex = y * maskBytesPerRow + x
            let outputIndex = y * outputBytesPerRow + x
            outputPointer[outputIndex] = originalPointer[originalIndex]
        }
        
        return outputBuffer
    }
    
    // タップ位置から人物を判定して選択（顔検出を優先）
    func handleTap(at location: CGPoint, in viewSize: CGSize, actualImageSize: CGSize, imageOffset: CGPoint) {
        // タップ位置を画像座標系に変換
        let imageX = location.x - imageOffset.x
        let imageY = location.y - imageOffset.y
        
        // 画像座標系を正規化（0.0〜1.0）
        let normalizedX = imageX / actualImageSize.width
        let normalizedY = imageY / actualImageSize.height
        
        let tapPoint = CGPoint(x: normalizedX, y: normalizedY)
        
        print("🔵 [DEBUG] タップ位置: \(location), 画像座標: (\(imageX), \(imageY)), 正規化: (\(normalizedX), \(normalizedY))")
        
        // まず、顔の位置に基づいて選択を試みる（より正確）
        if !detectedFaces.isEmpty {
            // タップ位置に最も近い顔を探す
            var minFaceDistance = CGFloat.greatestFiniteMagnitude
            var closestFaceIndex: Int?
            
            for (index, facePosition) in detectedFaces.enumerated() {
                let distance = sqrt(
                    pow(tapPoint.x - facePosition.x, 2) +
                    pow(tapPoint.y - facePosition.y, 2)
                )
                
                if distance < minFaceDistance {
                    minFaceDistance = distance
                    closestFaceIndex = index
                }
            }
            
            // 顔に近い場合（例: 0.1以内）、その顔に関連付けられた人物を選択
            let faceThreshold: CGFloat = 0.1
            if let faceIndex = closestFaceIndex, minFaceDistance < faceThreshold {
                let selectedFace = detectedFaces[faceIndex]
                
                // この顔に関連付けられた人物を探す
                for person in detectedPersons {
                    if let personFace = person.facePosition {
                        let faceDistance = sqrt(
                            pow(selectedFace.x - personFace.x, 2) +
                            pow(selectedFace.y - personFace.y, 2)
                        )
                        
                        // 顔の位置が一致する場合（例: 0.05以内）
                        if faceDistance < 0.05 {
                            print("🔵 [DEBUG] 顔に基づいて人物を選択: 顔距離=\(faceDistance)")
                            selectPerson(person.id)
                            return
                        }
                    }
                }
            }
        }
        
        // 顔検出が失敗した場合、従来の方法で人物を選択
        for person in detectedPersons {
            // バウンディングボックス内かチェック
            if person.boundingBox.contains(tapPoint) {
                // マスクをチェックして、実際に人物領域内か確認
                if isPointInPersonMask(normalizedX: normalizedX, normalizedY: normalizedY, person: person) {
                    print("🔵 [DEBUG] マスクに基づいて人物を選択")
                    selectPerson(person.id)
                    return
                }
            }
        }
    }
    
    // 正規化座標が人物のマスク内かチェック
    func isPointInPersonMask(normalizedX: CGFloat, normalizedY: CGFloat, person: DetectedPerson) -> Bool {
        CVPixelBufferLockBaseAddress(person.maskBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(person.maskBuffer, []) }
        
        guard let maskBaseAddress = CVPixelBufferGetBaseAddress(person.maskBuffer) else {
            return false
        }
        
        let maskBytesPerRow = CVPixelBufferGetBytesPerRow(person.maskBuffer)
        let maskWidth = CVPixelBufferGetWidth(person.maskBuffer)
        let maskHeight = CVPixelBufferGetHeight(person.maskBuffer)
        let maskPointer = maskBaseAddress.assumingMemoryBound(to: UInt8.self)
        let threshold: UInt8 = 128
        
        // 正規化座標をマスク座標に変換
        let maskX = Int(normalizedX * CGFloat(maskWidth))
        let maskY = Int(normalizedY * CGFloat(maskHeight))
        
        guard maskX >= 0 && maskX < maskWidth && maskY >= 0 && maskY < maskHeight else {
            return false
        }
        
        let maskIndex = maskY * maskBytesPerRow + maskX
        let maskValue = maskPointer[maskIndex]
        
        return maskValue >= threshold
    }
    
    // 人物を選択（複数選択対応）
    func selectPerson(_ personId: UUID) {
        // 状態を確実に更新するため、新しい配列を作成
        var updatedPersons = detectedPersons
        if let index = updatedPersons.firstIndex(where: { $0.id == personId }) {
            // トグル選択（複数選択可能）
            updatedPersons[index].isSelected.toggle()
        }
        detectedPersons = updatedPersons
        print("🔵 [DEBUG] 人物を選択: \(personId), 選択状態: \(updatedPersons.first(where: { $0.id == personId })?.isSelected ?? false)")
    }
    
    // 近いグループごとに人物を分離（クラスタリング）
    func groupPersonsByProximity(_ persons: [DetectedPerson], threshold: CGFloat = 0.3) -> [[DetectedPerson]] {
        var groups: [[DetectedPerson]] = []
        var assigned = Set<UUID>()
        
        for person in persons {
            if assigned.contains(person.id) {
                continue
            }
            
            // 新しいグループを開始
            var group: [DetectedPerson] = [person]
            assigned.insert(person.id)
            
            // この人物に近い人物を探す
            let personCenter = CGPoint(
                x: person.boundingBox.midX,
                y: person.boundingBox.midY
            )
            
            var foundNew = true
            while foundNew {
                foundNew = false
                for otherPerson in persons {
                    if assigned.contains(otherPerson.id) {
                        continue
                    }
                    
                    let otherCenter = CGPoint(
                        x: otherPerson.boundingBox.midX,
                        y: otherPerson.boundingBox.midY
                    )
                    
                    let distance = sqrt(
                        pow(personCenter.x - otherCenter.x, 2) +
                        pow(personCenter.y - otherCenter.y, 2)
                    )
                    
                    // 閾値以内の距離にある人物を同じグループに追加
                    if distance < threshold {
                        group.append(otherPerson)
                        assigned.insert(otherPerson.id)
                        foundNew = true
                    }
                }
            }
            
            groups.append(group)
        }
        
        return groups
    }
    
    // 複数のマスクを統合（複数選択対応）
    func combineMasks(_ masks: [CVPixelBuffer]) -> CVPixelBuffer? {
        guard !masks.isEmpty else { return nil }
        
        // 最初のマスクのサイズを基準にする
        let firstMask = masks[0]
        let maskWidth = CVPixelBufferGetWidth(firstMask)
        let maskHeight = CVPixelBufferGetHeight(firstMask)
        
        // 統合されたマスクを作成
        var combinedBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            maskWidth,
            maskHeight,
            kCVPixelFormatType_OneComponent8,
            nil,
            &combinedBuffer
        )
        
        guard status == kCVReturnSuccess, let combined = combinedBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(combined, [])
        defer { CVPixelBufferUnlockBaseAddress(combined, []) }
        
        guard let combinedBaseAddress = CVPixelBufferGetBaseAddress(combined) else {
            return nil
        }
        
        let combinedBytesPerRow = CVPixelBufferGetBytesPerRow(combined)
        let combinedPointer = combinedBaseAddress.assumingMemoryBound(to: UInt8.self)
        
        // 初期化（すべて背景）
        for y in 0..<maskHeight {
            for x in 0..<maskWidth {
                let index = y * combinedBytesPerRow + x
                combinedPointer[index] = 0
            }
        }
        
        // 全てのマスクを統合（OR演算）
        for mask in masks {
            CVPixelBufferLockBaseAddress(mask, [])
            defer { CVPixelBufferUnlockBaseAddress(mask, []) }
            
            guard let maskBaseAddress = CVPixelBufferGetBaseAddress(mask) else {
                continue
            }
            
            let maskBytesPerRow = CVPixelBufferGetBytesPerRow(mask)
            let maskPointer = maskBaseAddress.assumingMemoryBound(to: UInt8.self)
            let threshold: UInt8 = 128
            
            for y in 0..<maskHeight {
                for x in 0..<maskWidth {
                    let maskIndex = y * maskBytesPerRow + x
                    let maskValue = maskPointer[maskIndex]
                    
                    if maskValue >= threshold {
                        let combinedIndex = y * combinedBytesPerRow + x
                        combinedPointer[combinedIndex] = 255
                    }
                }
            }
        }
        
        return combined
    }
    
    // マスクを手動で編集（解決策3、最適化版）
    func editMask(at location: CGPoint, previousLocation: CGPoint?, in viewSize: CGSize, actualImageSize: CGSize, imageOffset: CGPoint) {
        guard maskEditMode != .none else { return }
        
        // タップ位置を画像座標系に変換
        let imageX = location.x - imageOffset.x
        let imageY = location.y - imageOffset.y
        
        // 画像座標系を正規化（0.0〜1.0）
        let normalizedX = imageX / actualImageSize.width
        let normalizedY = imageY / actualImageSize.height
        
        guard normalizedX >= 0 && normalizedX <= 1.0 && normalizedY >= 0 && normalizedY <= 1.0 else {
            return
        }
        
        let currentPoint = CGPoint(x: normalizedX, y: normalizedY)
        
        // 選択されている人物を編集（複数選択時は最初の選択された人物を編集）
        guard let selectedPersonIndex = detectedPersons.firstIndex(where: { $0.isSelected }) else {
            return
        }
        
        var person = detectedPersons[selectedPersonIndex]
        
        // 前回の位置（previousLocation）と現在の位置の間を補間して滑らかに編集
        // previousLocationはonChangedで渡された前回の位置（tの始点）
        // currentPointは現在の位置（tの終点）
        // 重要: previousLocationはnilにならない（onChangedで初期化されている）
        guard let lastPoint = previousLocation else {
            // 念のため、previousLocationがnilの場合は現在位置のみ
            print("⚠️ [DEBUG] previousLocationがnilです。現在位置のみを適用します。")
            let pointsToEdit = [currentPoint]
            // 編集処理を実行
            DispatchQueue.global(qos: .userInteractive).async {
                let editedMask = self.editMaskBufferOptimized(
                    maskBuffer: person.maskBuffer,
                    at: pointsToEdit,
                    mode: self.maskEditMode,
                    brushSize: self.brushSize,
                    imageSize: self.imageSize,
                    actualImageSize: actualImageSize
                )
                
                if let editedMask = editedMask {
                    DispatchQueue.main.async {
                        person.maskBuffer = editedMask
                        var updatedPersons = self.detectedPersons
                        updatedPersons[selectedPersonIndex] = person
                        self.detectedPersons = updatedPersons
                        self.maskEditCounter += 1
                    }
                }
            }
            return
        }
        
        // 前回の位置を画像座標系に変換
        let prevImageX = lastPoint.x - imageOffset.x
        let prevImageY = lastPoint.y - imageOffset.y
        let prevNormalizedX = prevImageX / actualImageSize.width
        let prevNormalizedY = prevImageY / actualImageSize.height
        
        let lastPointNormalized = CGPoint(x: prevNormalizedX, y: prevNormalizedY)
        
        // 前回の位置（tの始点）と現在の位置（tの終点）の間を補間
        // 始点と終点が同じ場合は補間不要
        let distance = sqrt(pow(currentPoint.x - lastPointNormalized.x, 2) + pow(currentPoint.y - lastPointNormalized.y, 2))
        
        let pointsToEdit: [CGPoint]
        if distance < 0.001 {
            // 始点と終点がほぼ同じ場合は、現在位置のみ
            pointsToEdit = [currentPoint]
            print("🔵 [DEBUG] 始点と終点が同じ: ポイント(\(currentPoint.x), \(currentPoint.y))")
        } else {
            // 距離に応じてステップ数を計算（リアルタイム編集のため、ステップ数を減らす）
            // 間引き間隔が短いため、補間ステップ数も少なくしてパフォーマンスを維持
            let steps = max(1, min(Int(distance * 50), 5))  // 最大5ステップに制限
            pointsToEdit = interpolatePoints(from: lastPointNormalized, to: currentPoint, steps: steps)
            print("🔵 [DEBUG] 補間: 始点(\(lastPointNormalized.x), \(lastPointNormalized.y)) -> 終点(\(currentPoint.x), \(currentPoint.y)), 距離: \(distance), ステップ数: \(steps), ポイント数: \(pointsToEdit.count)")
        }
        
        // リアルタイム編集のため、バックグラウンドスレッドで編集処理を実行
        // ただし、UIの応答性を保つため、優先度を高く設定
        DispatchQueue.global(qos: .userInteractive).async {
            // マスクを直接編集（コピーしない、より高速）
            let editedMask = self.editMaskBufferOptimized(
                maskBuffer: person.maskBuffer,
                at: pointsToEdit,
                mode: self.maskEditMode,
                brushSize: self.brushSize,
                imageSize: self.imageSize,
                actualImageSize: actualImageSize
            )
            
            if let editedMask = editedMask {
                // メインスレッドで即座に更新（リアルタイム反映）
                DispatchQueue.main.async {
                    person.maskBuffer = editedMask
                    // 新しい配列を作成して更新（SwiftUIの状態更新を確実に）
                    var updatedPersons = self.detectedPersons
                    updatedPersons[selectedPersonIndex] = person
                    self.detectedPersons = updatedPersons
                    
                    // 編集カウンターをインクリメントしてViewを強制的に更新
                    self.maskEditCounter += 1
                }
            }
        }
    }
    
    // 2点間を補間（始点から終点まで全てのポイントを生成）
    func interpolatePoints(from start: CGPoint, to end: CGPoint, steps: Int) -> [CGPoint] {
        guard steps > 0 else {
            return [start, end]  // ステップが0の場合は始点と終点のみ
        }
        
        var points: [CGPoint] = []
        // 始点から終点まで全ての補間点を生成
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = start.x + (end.x - start.x) * t
            let y = start.y + (end.y - start.y) * t
            points.append(CGPoint(x: x, y: y))
        }
        return points
    }
    
    // マスクバッファを編集（最適化版：複数ポイント、直接編集）
    func editMaskBufferOptimized(maskBuffer: CVPixelBuffer, at points: [CGPoint], mode: MaskEditMode, brushSize: CGFloat, imageSize: CGSize, actualImageSize: CGSize) -> CVPixelBuffer? {
        CVPixelBufferLockBaseAddress(maskBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(maskBuffer, []) }
        
        guard let maskBaseAddress = CVPixelBufferGetBaseAddress(maskBuffer) else {
            return nil
        }
        
        let maskBytesPerRow = CVPixelBufferGetBytesPerRow(maskBuffer)
        let maskWidth = CVPixelBufferGetWidth(maskBuffer)
        let maskHeight = CVPixelBufferGetHeight(maskBuffer)
        let maskPointer = maskBaseAddress.assumingMemoryBound(to: UInt8.self)
        
        // 新しいマスクバッファを作成（コピー）
        var newPixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            maskWidth,
            maskHeight,
            kCVPixelFormatType_OneComponent8,
            nil,
            &newPixelBuffer
        )
        
        guard status == kCVReturnSuccess, let newBuffer = newPixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(newBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(newBuffer, []) }
        
        guard let newBaseAddress = CVPixelBufferGetBaseAddress(newBuffer) else {
            return nil
        }
        
        let newBytesPerRow = CVPixelBufferGetBytesPerRow(newBuffer)
        let newPointer = newBaseAddress.assumingMemoryBound(to: UInt8.self)
        
        // 元のマスクをコピー（memcpyを使用して高速化）
        memcpy(newBaseAddress, maskBaseAddress, maskHeight * maskBytesPerRow)
        
        // ブラシサイズを実際の表示サイズに基づいて計算
        // actualImageSizeとimageSizeの比率を考慮
        let scaleX = actualImageSize.width / imageSize.width
        let scaleY = actualImageSize.height / imageSize.height
        let scale = min(scaleX, scaleY)  // アスペクト比を維持
        
        // マスク座標系でのブラシサイズを計算
        // brushSizeは表示サイズ（actualImageSize）でのピクセル数
        // 最小値1pxを保証
        let brushRadiusInMask = max(1, Int(brushSize * CGFloat(maskWidth) / actualImageSize.width))
        
        // 編集値
        let value: UInt8 = mode == .add ? 255 : 0
        
        // 複数のポイントを編集（最適化：距離の2乗で比較してsqrtを回避）
        let brushRadiusSquared = brushRadiusInMask * brushRadiusInMask
        var editedPointCount = 0
        var skippedPointCount = 0
        
        // 全てのポイントを確実に処理
        for (index, point) in points.enumerated() {
            // 編集位置をマスク座標に変換
            let maskX = Int(point.x * CGFloat(maskWidth))
            let maskY = Int(point.y * CGFloat(maskHeight))
            
            // 境界チェック
            guard maskX >= 0 && maskX < maskWidth && maskY >= 0 && maskY < maskHeight else {
                skippedPointCount += 1
                continue
            }
            
            // ブラシでマスクを編集（円形ブラシ、最適化版）
            // 境界チェックを先に行って、不要な計算を回避
            let minX = max(0, maskX - brushRadiusInMask)
            let maxX = min(maskWidth - 1, maskX + brushRadiusInMask)
            let minY = max(0, maskY - brushRadiusInMask)
            let maxY = min(maskHeight - 1, maskY + brushRadiusInMask)
            
            var pixelsEditedForThisPoint = 0
            for y in minY...maxY {
                let dy = y - maskY
                let dySquared = dy * dy
                for x in minX...maxX {
                    let dx = x - maskX
                    let distanceSquared = dx * dx + dySquared
                    if distanceSquared <= brushRadiusSquared {
                        let pixelIndex = y * newBytesPerRow + x
                        newPointer[pixelIndex] = value
                        pixelsEditedForThisPoint += 1
                    }
                }
            }
            
            if pixelsEditedForThisPoint > 0 {
                editedPointCount += 1
            } else {
                skippedPointCount += 1
            }
        }
        
        print("🔵 [DEBUG] マスク編集完了: 総ポイント数=\(points.count), 編集成功=\(editedPointCount), スキップ=\(skippedPointCount)")
        
        return newBuffer
    }
    
    // 選択した人物の背景除去を実行（複数選択対応）
    func processSelectedPerson() {
        let selectedPersons = detectedPersons.filter { $0.isSelected }
        guard !selectedPersons.isEmpty,
              let image = selectedImage else {
            return
        }
        
        isProcessing = true
        
        // 画像の前処理
        guard let preparedImage = prepareImage(image) else {
            isProcessing = false
            alertTitle = "Error"
            alertMessage = "Failed to preprocess image"
            showAlert = true
            return
        }
        
        // 選択した人物のマスクを統合（複数選択対応）
        guard let combinedMask = combineMasks(selectedPersons.map { $0.maskBuffer }) else {
            isProcessing = false
            alertTitle = "Error"
            alertMessage = "Failed to combine masks"
            showAlert = true
            return
        }
        
        // 統合したマスクを使って透過画像を生成
        let processed = createTransparentImage(from: preparedImage, maskBuffer: combinedMask)
        
        guard let processed = processed else {
            isProcessing = false
            alertTitle = "Error"
            alertMessage = "Failed to process image"
            showAlert = true
            return
        }
        
        processedImage = processed
        showingPersonSelection = false
        detectedPersons = []
        isProcessing = false
        
        print("✅ [DEBUG] 選択した人物の背景除去完了")
    }
    
    // マスクからPathを作成（セグメンテーション領域を塗りつぶすため）
    func createPathFromMask(_ maskBuffer: CVPixelBuffer, maskWidth: Int, maskHeight: Int, imageSize: CGSize) -> Path? {
        CVPixelBufferLockBaseAddress(maskBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(maskBuffer, []) }
        
        guard let maskBaseAddress = CVPixelBufferGetBaseAddress(maskBuffer) else {
            return nil
        }
        
        let maskBytesPerRow = CVPixelBufferGetBytesPerRow(maskBuffer)
        let maskPointer = maskBaseAddress.assumingMemoryBound(to: UInt8.self)
        let threshold: UInt8 = 128
        
        // マスクから輪郭点を抽出（4方向チェック）
        var contourPoints: [(Int, Int)] = []
        
        for y in 0..<maskHeight {
            for x in 0..<maskWidth {
                let maskIndex = y * maskBytesPerRow + x
                let maskValue = maskPointer[maskIndex]
                
                if maskValue >= threshold {
                    // 4方向をチェックして、背景がある場合は輪郭点
                    var isContour = false
                    
                    // 上
                    if y == 0 || (y > 0 && maskPointer[(y - 1) * maskBytesPerRow + x] < threshold) {
                        isContour = true
                    }
                    // 下
                    else if y == maskHeight - 1 || (y < maskHeight - 1 && maskPointer[(y + 1) * maskBytesPerRow + x] < threshold) {
                        isContour = true
                    }
                    // 左
                    else if x == 0 || (x > 0 && maskPointer[y * maskBytesPerRow + (x - 1)] < threshold) {
                        isContour = true
                    }
                    // 右
                    else if x == maskWidth - 1 || (x < maskWidth - 1 && maskPointer[y * maskBytesPerRow + (x + 1)] < threshold) {
                        isContour = true
                    }
                    
                    if isContour {
                        contourPoints.append((x, y))
                    }
                }
            }
        }
        
        guard contourPoints.count >= 3 else { return nil }
        
        // 輪郭点を時計回りにソート（最も上の点から開始）
        guard let startPoint = contourPoints.min(by: {
            if $0.1 != $1.1 { return $0.1 < $1.1 }
            return $0.0 < $1.0
        }) else {
            return nil
        }
        
        // 角度でソート
        let sortedPoints = contourPoints.sorted { p1, p2 in
            let dx1 = Double(p1.0 - startPoint.0)
            let dy1 = Double(p1.1 - startPoint.1)
            let dx2 = Double(p2.0 - startPoint.0)
            let dy2 = Double(p2.1 - startPoint.1)
            
            let angle1 = atan2(dy1, dx1)
            let angle2 = atan2(dy2, dx2)
            
            return angle1 < angle2
        }
        
        // Pathを作成
        let scaleX = imageSize.width / CGFloat(maskWidth)
        let scaleY = imageSize.height / CGFloat(maskHeight)
        
        var path = Path()
        
        guard let firstPoint = sortedPoints.first else { return nil }
        let startX = CGFloat(firstPoint.0) * scaleX
        let startY = CGFloat(firstPoint.1) * scaleY
        path.move(to: CGPoint(x: startX, y: startY))
        
        // 輪郭点を間引いて滑らかに
        var lastAddedPoint = firstPoint
        let minDistance: CGFloat = 5.0
        
        for point in sortedPoints.dropFirst() {
            let dx = CGFloat(point.0 - lastAddedPoint.0) * scaleX
            let dy = CGFloat(point.1 - lastAddedPoint.1) * scaleY
            let distance = sqrt(dx * dx + dy * dy)
            
            if distance >= minDistance {
                let x = CGFloat(point.0) * scaleX
                let y = CGFloat(point.1) * scaleY
                path.addLine(to: CGPoint(x: x, y: y))
                lastAddedPoint = point
            }
        }
        
        path.closeSubpath()
        
        return path
    }
}

// マスクオーバーレイView（セグメンテーション領域を塗りつぶし）
struct MaskOverlayView: View {
    let person: DetectedPerson
    let imageSize: CGSize  // 元画像のサイズ
    let actualImageSize: CGSize  // 実際に表示されている画像のサイズ
    let viewSize: CGSize
    let imageOffset: CGPoint  // 画像のオフセット（中央配置用）
    let isSelected: Bool
    let isEditingMode: Bool  // 編集モードかどうか
    let editCounter: Int  // 編集カウンター（View更新用）
    let onTap: () -> Void
    
    // マスク画像をキャッシュ（処理の重さを軽減）
    // 編集モード中はキャッシュを無効化して常に最新のマスクを表示
    @State private var cachedMaskImage: UIImage?
    
    var body: some View {
        // 編集モード中は常に最新のマスクを生成（キャッシュを使わない）
        let maskImage: UIImage?
        if isEditingMode {
            // 編集モード中はキャッシュを使わず、常に最新のマスクを生成
            maskImage = createMaskImageLightweight()
        } else {
            // 通常モードではキャッシュを使用
            maskImage = cachedMaskImage ?? createMaskImageLightweight()
            if cachedMaskImage == nil, let img = maskImage {
                DispatchQueue.main.async {
                    self.cachedMaskImage = img
                }
            }
        }
        
        if let maskImage = maskImage {
            return AnyView(
                Image(uiImage: maskImage)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: actualImageSize.width, height: actualImageSize.height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .offset(x: imageOffset.x, y: imageOffset.y)
                    .colorMultiply(isSelected ? Color.green : Color.blue)
                    .opacity(isSelected ? 0.4 : 0.3)
                    .allowsHitTesting(false)  // タップは親Viewで処理
                    .id("\(person.id)-\(editCounter)")  // 編集カウンターでViewを更新
            )
        } else {
            // フォールバック：四角形で表示
            let scaledBoundingBox = CGRect(
                x: person.boundingBox.origin.x * actualImageSize.width,
                y: person.boundingBox.origin.y * actualImageSize.height,
                width: person.boundingBox.width * actualImageSize.width,
                height: person.boundingBox.height * actualImageSize.height
            )
            
            return AnyView(
                Rectangle()
                    .fill(isSelected ? Color.green.opacity(0.3) : Color.blue.opacity(0.2))
                    .frame(width: scaledBoundingBox.width, height: scaledBoundingBox.height)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .offset(
                        x: imageOffset.x + scaledBoundingBox.midX - actualImageSize.width / 2,
                        y: imageOffset.y + scaledBoundingBox.midY - actualImageSize.height / 2
                    )
                    .allowsHitTesting(false)  // タップは親Viewで処理
            )
        }
    }
    
    // マスクからUIImageを作成（軽量化版：間引き処理）
    func createMaskImageLightweight() -> UIImage? {
        CVPixelBufferLockBaseAddress(person.maskBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(person.maskBuffer, []) }
        
        guard let maskBaseAddress = CVPixelBufferGetBaseAddress(person.maskBuffer) else {
            return nil
        }
        
        let maskBytesPerRow = CVPixelBufferGetBytesPerRow(person.maskBuffer)
        let maskWidth = CVPixelBufferGetWidth(person.maskBuffer)
        let maskHeight = CVPixelBufferGetHeight(person.maskBuffer)
        let maskPointer = maskBaseAddress.assumingMemoryBound(to: UInt8.self)
        let threshold: UInt8 = 128
        
        // マスクは元画像と同じサイズで生成されているはず
        // 元画像のサイズ（imageSize）とマスクのサイズ（maskWidth, maskHeight）の比率を計算
        let maskToImageScaleX = imageSize.width / CGFloat(maskWidth)
        let maskToImageScaleY = imageSize.height / CGFloat(maskHeight)
        
        // actualImageSizeに合わせて出力サイズを計算（軽量化のため最大512pxに制限）
        let maxDimension: CGFloat = 512
        let scale = min(maxDimension / actualImageSize.width, maxDimension / actualImageSize.height, 1.0)
        let finalOutputWidth = Int(actualImageSize.width * scale)
        let finalOutputHeight = Int(actualImageSize.height * scale)
        
        // RGBA画像を作成
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bitsPerComponent = 8
        
        guard let context = CGContext(
            data: nil,
            width: finalOutputWidth,
            height: finalOutputHeight,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerPixel * finalOutputWidth,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        guard let data = context.data else {
            return nil
        }
        
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        
        // マスクの値をRGBAに変換（actualImageSizeに合わせてスケール）
        for y in 0..<finalOutputHeight {
            for x in 0..<finalOutputWidth {
                // 出力座標（ダウンスケール後）をactualImageSize座標系に変換
                let actualX = CGFloat(x) / scale
                let actualY = CGFloat(y) / scale
                
                // actualImageSize座標系を元画像座標系に変換
                // actualImageSizeはimageSizeをaspectRatio(.fit)でスケールしたもの
                // aspectRatio(.fit)の場合、XとYのスケールは同じ（小さい方に合わせる）
                let imageScale = min(actualImageSize.width / imageSize.width, actualImageSize.height / imageSize.height)
                let imageX = actualX / imageScale
                let imageY = actualY / imageScale
                
                // 元画像座標系をマスク座標系に変換
                let maskX = Int(imageX / maskToImageScaleX)
                let maskY = Int(imageY / maskToImageScaleY)
                
                guard maskX >= 0 && maskX < maskWidth && maskY >= 0 && maskY < maskHeight else {
                    let pixelIndex = (y * finalOutputWidth + x) * bytesPerPixel
                    pixels[pixelIndex + 0] = 0
                    pixels[pixelIndex + 1] = 0
                    pixels[pixelIndex + 2] = 0
                    pixels[pixelIndex + 3] = 0
                    continue
                }
                
                let maskIndex = maskY * maskBytesPerRow + maskX
                let maskValue = maskPointer[maskIndex]
                
                let pixelIndex = (y * finalOutputWidth + x) * bytesPerPixel
                
                if maskValue >= threshold {
                    // 人物領域：白（後で色を乗算）
                    pixels[pixelIndex + 0] = 255  // R
                    pixels[pixelIndex + 1] = 255  // G
                    pixels[pixelIndex + 2] = 255  // B
                    pixels[pixelIndex + 3] = 255  // A（不透明）
                } else {
                    // 背景領域：透明
                    pixels[pixelIndex + 0] = 0  // R
                    pixels[pixelIndex + 1] = 0  // G
                    pixels[pixelIndex + 2] = 0  // B
                    pixels[pixelIndex + 3] = 0  // A（透明）
                }
            }
        }
        
        guard let cgImage = context.makeImage() else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
}

// UIImageの向きを修正する拡張
extension UIImage {
    // 画像に角丸を適用する
    func rounded(cornerRadius: CGFloat) -> UIImage? {
        let size = self.size
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            path.addClip()
            self.draw(in: rect)
        }
    }
    
    // 画像の向きを正しく修正する（EXIF情報を考慮）
    // より確実な方法: UIImageのdraw(in:)メソッドを使用
    func fixedOrientation() -> UIImage? {
        // 向きが既に正しい場合はそのまま返す
        if imageOrientation == .up {
            return self
        }
        
        // CGImageを取得
        guard let cgImage = self.cgImage else {
            return nil
        }
        
        // 向きに応じたサイズを計算
        // image.sizeは向き情報を考慮したサイズを返すが、CGImageのサイズも確認
        let width: CGFloat
        let height: CGFloat
        
        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            // 90度回転している場合、幅と高さを入れ替え
            width = CGFloat(cgImage.height)
            height = CGFloat(cgImage.width)
        default:
            width = CGFloat(cgImage.width)
            height = CGFloat(cgImage.height)
        }
        
        // 向きを修正した画像を作成
        // UIGraphicsImageRendererを使用（より確実で高品質）
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: UIGraphicsImageRendererFormat.default())
        let correctedImage = renderer.image { context in
            // UIImageのdraw(in:)メソッドを使用すると、自動的に向きが正しく処理される
            // 向き情報（imageOrientation）が自動的に適用される
            self.draw(in: CGRect(origin: .zero, size: CGSize(width: width, height: height)))
        }
        
        // 修正後の画像の向きを確認（デバッグ用）
        print("🔵 [DEBUG] 向き修正: \(imageOrientation.rawValue) -> \(correctedImage.imageOrientation.rawValue)")
        
        return correctedImage
    }
}

// UIImageをCVPixelBufferに変換する拡張
extension UIImage {
    func toCVPixelBuffer() -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )
        
        guard let cgContext = context else {
            return nil
        }
        
        cgContext.translateBy(x: 0, y: size.height)
        cgContext.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(cgContext)
        draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        UIGraphicsPopContext()
        
        return buffer
    }
}

// 画像ピッカー
struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// CGRectの拡張：面積とユニオンを計算
extension CGRect {
    var area: CGFloat {
        return width * height
    }
    
    func union(_ other: CGRect) -> CGRect {
        let minX = min(self.minX, other.minX)
        let minY = min(self.minY, other.minY)
        let maxX = max(self.maxX, other.maxX)
        let maxY = max(self.maxY, other.maxY)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

// チェッカーパターン（透過を視覚化するための背景）
struct CheckerboardPattern: View {
    var squareSize: CGFloat = 20
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let cols = Int(width / squareSize) + 1
            let rows = Int(height / squareSize) + 1
            
            ZStack {
                ForEach(0..<rows, id: \.self) { row in
                    ForEach(0..<cols, id: \.self) { col in
                        Rectangle()
                            .fill((row + col) % 2 == 0 ? Color.white.opacity(0.1) : Color.gray.opacity(0.2))
                            .frame(width: squareSize, height: squareSize)
                            .offset(x: CGFloat(col) * squareSize, y: CGFloat(row) * squareSize)
                    }
                }
            }
        }
    }
}

// 共有シート
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ContentView()
}
