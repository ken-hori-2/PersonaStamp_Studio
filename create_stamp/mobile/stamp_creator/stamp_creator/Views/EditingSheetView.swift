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
    @State private var canvasView: PKCanvasView?
    @State private var toolPicker: PKToolPicker?
    @State private var isToolPickerVisible = false
    @State private var canUndo = false
    @State private var canRedo = false
    @State private var imageViewFrame: CGRect = .zero
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.08, blue: 0.18),
                        Color(red: 0.15, green: 0.12, blue: 0.28)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
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
                        onImageViewFrameChanged: { frame in
                            imageViewFrame = frame
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // 編集コントロール（画面上部）
                if isToolPickerVisible {
                    editingControlsOverlay
                }
            }
            .navigationTitle("Edit Image")
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
                        .foregroundColor(canUndo ? .white : .white.opacity(0.5))
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
                        .foregroundColor(canRedo ? .white : .white.opacity(0.5))
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
                    var canvasSize: CGSize = .zero
                    var drawing: PKDrawing = PKDrawing()
                    var imageFrame: CGRect = .zero
                    var zoomScale: CGFloat = 1.0
                    
                    DispatchQueue.main.sync {
                        var parentView: UIView? = canvasView.superview
                        while parentView != nil {
                            if let scrollView = parentView as? UIScrollView {
                                canvasSize = scrollView.bounds.size
                                zoomScale = scrollView.zoomScale
                                break
                            }
                            parentView = parentView?.superview
                        }
                        
                        if parentView == nil {
                            canvasSize = canvasView.bounds.size
                        }
                        
                        drawing = canvasView.drawing
                        imageFrame = self.imageViewFrame
                    }
                    
                    guard canvasSize.width > 0 && canvasSize.height > 0 else {
                        continuation.resume(throwing: NSError(domain: "ImageEditor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Canvas size is invalid"]))
                        return
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
                    
                    let displaySize: CGSize
                    let displayFrame: CGRect
                    
                    if imageFrame.width > 0 && imageFrame.height > 0 {
                        displaySize = CGSize(
                            width: imageFrame.width / zoomScale,
                            height: imageFrame.height / zoomScale
                        )
                        displayFrame = CGRect(
                            x: 0,
                            y: 0,
                            width: displaySize.width,
                            height: displaySize.height
                        )
                    } else {
                        let canvasAspect = canvasSize.width / canvasSize.height
                        let imageAspect = imageSize.width / imageSize.height
                        
                        if imageAspect > canvasAspect {
                            let width = canvasSize.width
                            let height = canvasSize.width / imageAspect
                            displaySize = CGSize(width: width, height: height)
                            displayFrame = CGRect(
                                x: 0,
                                y: (canvasSize.height - height) / 2,
                                width: width,
                                height: height
                            )
                        } else {
                            let width = canvasSize.height * imageAspect
                            let height = canvasSize.height
                            displaySize = CGSize(width: width, height: height)
                            displayFrame = CGRect(
                                x: (canvasSize.width - width) / 2,
                                y: 0,
                                width: width,
                                height: height
                            )
                        }
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
}
