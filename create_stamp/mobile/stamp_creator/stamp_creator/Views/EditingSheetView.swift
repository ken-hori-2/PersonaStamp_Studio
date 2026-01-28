//
//  EditingSheetView.swift
//  stamp_creator
//
//  編集画面をsheetで表示するビュー
//

import SwiftUI
import PencilKit

struct EditingSheetView: View {
    let image: UIImage
    let onDismiss: () -> Void
    let onSave: (UIImage) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var canvasView: PKCanvasView?
    @State private var toolPicker: PKToolPicker?
    @State private var isToolPickerVisible = false
    @State private var canUndo = false
    @State private var canRedo = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
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
                
                // 透明画像の場合はチェッカーパターンを背景に表示
                if imageHasTransparency(image) {
                    CheckerboardPattern()
                        .ignoresSafeArea()
                }
                
                VStack(spacing: 0) {
                    // 編集エリア
                    ZoomablePencilKitImageView(
                        image: image,
                        canvasView: $canvasView,
                        toolPicker: $toolPicker,
                        isToolPickerVisible: $isToolPickerVisible,
                        onUndoRedoStateChanged: {
                            updateUndoRedoState()
                        },
                        onImageViewFrameChanged: { _ in }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // 編集コントロール（画面上部）
                if isToolPickerVisible {
                    editingControlsOverlay
                }
            }
            .navigationTitle("Edit Sticker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveAndDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                // 画像をタップして編集モードに入る
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    toggleToolPicker()
                }
            }
        }
    }
    
    // 編集コントロールオーバーレイ
    private var editingControlsOverlay: some View {
        VStack {
            HStack(spacing: 12) {
                // アンドゥボタン
                Button(action: {
                    performUndo()
                }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.title3)
                        .foregroundColor(canUndo 
                            ? (colorScheme == .dark ? .white : .primary)
                            : (colorScheme == .dark ? .white.opacity(0.5) : .primary.opacity(0.5)))
                        .frame(width: 50, height: 50)
                        .background(.ultraThinMaterial)
                        .cornerRadius(25)
                        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                }
                .disabled(!canUndo)
                
                // リドゥボタン
                Button(action: {
                    performRedo()
                }) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.title3)
                        .foregroundColor(canRedo 
                            ? (colorScheme == .dark ? .white : .primary)
                            : (colorScheme == .dark ? .white.opacity(0.5) : .primary.opacity(0.5)))
                        .frame(width: 50, height: 50)
                        .background(.ultraThinMaterial)
                        .cornerRadius(25)
                        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                }
                .disabled(!canRedo)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            
            Spacer()
        }
    }
    
    private func toggleToolPicker() {
        guard let toolPicker = toolPicker,
              let canvasView = canvasView else { return }
        
        isToolPickerVisible.toggle()
        toolPicker.setVisible(isToolPickerVisible, forFirstResponder: canvasView)
        if isToolPickerVisible {
            canvasView.becomeFirstResponder()
        }
    }
    
    @MainActor
    private func endEditing() {
        isToolPickerVisible = false
        
        guard let toolPicker = toolPicker,
              let canvasView = canvasView else { return }
        
        toolPicker.setVisible(false, forFirstResponder: canvasView)
        canvasView.resignFirstResponder()
    }
    
    private func updateUndoRedoState() {
        DispatchQueue.main.async {
            if let canvasView = self.canvasView {
                if let undoManager = canvasView.undoManager {
                    self.canUndo = undoManager.canUndo
                    self.canRedo = undoManager.canRedo
                } else {
                    self.canUndo = !canvasView.drawing.strokes.isEmpty
                    self.canRedo = false
                }
            } else {
                self.canUndo = false
                self.canRedo = false
            }
        }
    }
    
    private func performUndo() {
        guard let canvasView = canvasView else { return }
        
        if let undoManager = canvasView.undoManager, undoManager.canUndo {
            undoManager.undo()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updateUndoRedoState()
            }
        }
    }
    
    private func performRedo() {
        guard let canvasView = canvasView else { return }
        
        if let undoManager = canvasView.undoManager, undoManager.canRedo {
            undoManager.redo()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updateUndoRedoState()
            }
        }
    }
    
    private func saveAndDismiss() {
        guard let canvasView = canvasView else {
            onDismiss()
            return
        }
        
        Task { @MainActor in
            do {
                let editedImage = try await compositeImage(image: image, canvasView: canvasView)
                onSave(editedImage)
            } catch {
                onDismiss()
            }
        }
    }
    
    private func compositeImage(image: UIImage, canvasView: PKCanvasView) async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    var canvasBounds: CGRect = .zero
                    var drawing: PKDrawing = PKDrawing()
                    var scrollViewBounds: CGSize = .zero
                    
                    DispatchQueue.main.sync {
                        drawing = canvasView.drawing
                        canvasBounds = canvasView.bounds
                        var parentView: UIView? = canvasView.superview
                        while parentView != nil {
                            if let sv = parentView as? UIScrollView {
                                scrollViewBounds = sv.bounds.size
                                break
                            }
                            parentView = parentView?.superview
                        }
                    }
                    
                    var imageSize = image.size
                    guard imageSize.width > 0 && imageSize.height > 0 else {
                        continuation.resume(throwing: NSError(domain: "ImageEditor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Image size is invalid"]))
                        return
                    }
                    
                    guard !drawing.strokes.isEmpty else {
                        continuation.resume(returning: image)
                        return
                    }
                    
                    let maxDimension: CGFloat = 4096
                    let resizeScale: CGFloat
                    if imageSize.width > maxDimension || imageSize.height > maxDimension {
                        resizeScale = min(maxDimension / imageSize.width, maxDimension / imageSize.height)
                        imageSize = CGSize(width: imageSize.width * resizeScale, height: imageSize.height * resizeScale)
                    } else {
                        resizeScale = 1.0
                    }
                    
                    let resizedImage: UIImage
                    if resizeScale < 1.0 {
                        let renderer = UIGraphicsImageRenderer(size: imageSize)
                        resizedImage = renderer.image { _ in
                            image.draw(in: CGRect(origin: .zero, size: imageSize))
                        }
                    } else {
                        resizedImage = image
                    }
                    
                    // 描画座標系は canvasView.bounds（ズームに依存しない）で決まる。
                    // imageViewFrame/zoomScale を使うと、拡大したまま Done したときに縮尺がずれて編集がずれる。
                    let displaySize: CGSize
                    let displayFrame: CGRect
                    
                    if canvasBounds.width > 0 && canvasBounds.height > 0 {
                        displaySize = canvasBounds.size
                        displayFrame = CGRect(origin: .zero, size: canvasBounds.size)
                    } else if scrollViewBounds.width > 0 && scrollViewBounds.height > 0 {
                        let canvasAspect = scrollViewBounds.width / scrollViewBounds.height
                        let imageAspect = imageSize.width / imageSize.height
                        if imageAspect > canvasAspect {
                            displaySize = CGSize(width: scrollViewBounds.width, height: scrollViewBounds.width / imageAspect)
                        } else {
                            displaySize = CGSize(width: scrollViewBounds.height * imageAspect, height: scrollViewBounds.height)
                        }
                        displayFrame = CGRect(origin: .zero, size: displaySize)
                    } else {
                        continuation.resume(throwing: NSError(domain: "ImageEditor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Canvas size is invalid"]))
                        return
                    }
                    
                    guard displaySize.width > 0 && displaySize.height > 0 else {
                        continuation.resume(throwing: NSError(domain: "ImageEditor", code: 3, userInfo: [NSLocalizedDescriptionKey: "Display size is invalid"]))
                        return
                    }
                    
                    let imageScale = image.scale
                    let drawingScale = min(imageScale * 2.0, 4.0)
                    let drawingImageFromCanvas = drawing.image(from: displayFrame, scale: drawingScale)
                    
                    guard drawingImageFromCanvas.size.width > 0 && drawingImageFromCanvas.size.height > 0 else {
                        continuation.resume(throwing: NSError(domain: "ImageEditor", code: 4, userInfo: [NSLocalizedDescriptionKey: "Drawing image size is invalid"]))
                        return
                    }
                    
                    let scaleX = imageSize.width / displaySize.width
                    let scaleY = imageSize.height / displaySize.height
                    
                    var format = UIGraphicsImageRendererFormat.default()
                    format.scale = imageScale
                    let renderer = UIGraphicsImageRenderer(size: imageSize, format: format)
                    let editedImage = renderer.image { context in
                        resizedImage.draw(in: CGRect(origin: .zero, size: imageSize))
                        
                        let scaledDrawingRect = CGRect(
                            x: 0,
                            y: 0,
                            width: drawingImageFromCanvas.size.width * scaleX,
                            height: drawingImageFromCanvas.size.height * scaleY
                        )
                        drawingImageFromCanvas.draw(in: scaledDrawingRect)
                    }
                    
                    continuation.resume(returning: editedImage)
                }
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
