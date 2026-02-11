//
//  MaskEditingView.swift
//  stamp_creator
//
//  PencilKitを使ったマスク編集ビュー
//

import SwiftUI
import PencilKit
import UIKit

struct MaskEditingView: UIViewRepresentable {
    @ObservedObject var viewModel: MaskEditingViewModel
    let onDismiss: () -> Void
    
    @State private var isAddingMode = true // true = 白（追加）、false = 黒（削除）
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        // 元画像ビュー（背景として表示）
        // 編集後の画像があればそれを表示、なければ元画像を表示
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        imageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(imageView)
        
        // PencilKitのキャンバス（マスク編集用）
        let canvasView = PKCanvasView()
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        canvasView.delegate = context.coordinator
        // 初期ツールは白（前景を追加）
        canvasView.tool = PKInkingTool(.pen, color: .white, width: 30)
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(canvasView)
        
        // 制約を設定
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            canvasView.topAnchor.constraint(equalTo: containerView.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        context.coordinator.imageView = imageView
        context.coordinator.canvasView = canvasView
        context.coordinator.viewModel = viewModel
        context.coordinator.onDismiss = onDismiss
        context.coordinator.isAddingMode = viewModel.isAddingMode
        
        // 初期画像を設定（編集後の画像があればそれを表示）
        if let editedImage = viewModel.editedImage {
            imageView.image = editedImage
        } else if let originalImage = viewModel.originalImage {
            imageView.image = originalImage
        }
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let imageView = context.coordinator.imageView,
              let _ = context.coordinator.canvasView else { return }
        
        // 編集後の画像があればそれを表示、なければ元画像を表示
        if let editedImage = viewModel.editedImage {
            imageView.image = editedImage
        } else if let originalImage = viewModel.originalImage {
            imageView.image = originalImage
        }
        
        // 編集モードに応じてツールを更新
        context.coordinator.isAddingMode = viewModel.isAddingMode
        context.coordinator.switchTool(isAdding: viewModel.isAddingMode)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var imageView: UIImageView?
        var canvasView: PKCanvasView?
        var viewModel: MaskEditingViewModel?
        var onDismiss: (() -> Void)?
        var baseMask: UIImage?
        var isAddingMode: Bool = true // true = 白（追加）、false = 黒（削除）
        private var lastUpdateTime: Date = Date()
        private var imageViewFrame: CGRect = .zero // 画像ビューのフレーム（座標変換用）
        
        override init() {
            super.init()
        }
        
        // 画像ビューのフレームを更新（座標変換用）
        func updateImageViewFrame(_ frame: CGRect) {
            imageViewFrame = frame
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // 描画が変更されたらマスクを更新（スロットリング: 0.1秒ごと）
            let now = Date()
            if now.timeIntervalSince(lastUpdateTime) > 0.1 {
                lastUpdateTime = now
                updateMaskFromDrawing()
            } else {
                // 最後の更新から0.1秒経過したら更新
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.updateMaskFromDrawing()
                }
            }
        }
        
        private func updateMaskFromDrawing() {
            guard let canvasView = canvasView,
                  let viewModel = viewModel,
                  let originalImage = viewModel.originalImage,
                  let baseMask = viewModel.maskImage else {
                print("⚠️ [MaskEditing] Missing required data for mask update")
                return
            }
            
            let drawing = canvasView.drawing
            let imageSize = originalImage.size
            let imageRect = CGRect(origin: .zero, size: imageSize)
            
            print("🟢 [MaskEditing] Updating mask from drawing: \(imageRect), isAdding: \(isAddingMode), strokes: \(drawing.strokes.count)")
            
            // 描画が空の場合は何もしない
            guard !drawing.strokes.isEmpty else {
                print("⚠️ [MaskEditing] Drawing is empty")
                return
            }
            
            // 描画のバウンディングボックスを取得
            let drawingBounds = drawing.bounds
            let canvasSize = canvasView.bounds.size
            print("🟢 [MaskEditing] Drawing bounds: \(drawingBounds), canvas size: \(canvasSize)")
            
            guard canvasSize.width > 0 && canvasSize.height > 0 else {
                print("⚠️ [MaskEditing] Canvas size is invalid: \(canvasSize)")
                return
            }
            
            // 描画を画像サイズに変換
            // 重要: drawing.image(from:scale:)に渡す矩形は、キャンバスの座標系である必要がある
            // キャンバスのバウンディングボックスを使用して描画を取得
            let canvasBounds = canvasView.bounds
            let drawingImageFromCanvas = drawing.image(from: canvasBounds, scale: 1.0)
            
            print("🟢 [MaskEditing] Drawing image from canvas size: \(drawingImageFromCanvas.size)")
            
            // 描画を画像サイズにリサイズ
            let rendererForResize = UIGraphicsImageRenderer(size: imageSize)
            let drawingImage = rendererForResize.image { _ in
                drawingImageFromCanvas.draw(in: imageRect)
            }
            
            guard let drawingCG = drawingImage.cgImage else {
                print("❌ [MaskEditing] Failed to create drawing CGImage")
                return
            }
            
            print("🟢 [MaskEditing] Drawing image size after resize: \(drawingImage.size)")
            
            // マスクを更新
            let renderer = UIGraphicsImageRenderer(size: imageSize)
            let updatedMask = renderer.image { context in
                let cgContext = context.cgContext
                
                // 元のマスクを描画（ベースマスク）
                if let baseMaskCG = baseMask.cgImage {
                    cgContext.draw(baseMaskCG, in: imageRect)
                }
                
                // 描画をマスクに適用
                // 描画をグレースケールに変換してマスクとして使用
                let colorSpace = CGColorSpaceCreateDeviceGray()
                guard let grayContext = CGContext(
                    data: nil,
                    width: Int(imageSize.width),
                    height: Int(imageSize.height),
                    bitsPerComponent: 8,
                    bytesPerRow: Int(imageSize.width),
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.none.rawValue
                ) else {
                    print("❌ [MaskEditing] Failed to create gray context for mask")
                    return
                }
                
                // 描画をグレースケールに変換
                grayContext.draw(drawingCG, in: imageRect)
                guard let grayDrawingCG = grayContext.makeImage() else {
                    print("❌ [MaskEditing] Failed to create gray drawing CGImage")
                    return
                }
                
                if isAddingMode {
                    // 白で描画 = 前景を追加（マスクを白に）
                    // 描画された部分を白で上書き
                    // lighten blend modeで、より明るい色（白）を優先
                    cgContext.setBlendMode(.lighten)
                    cgContext.draw(grayDrawingCG, in: imageRect)
                } else {
                    // 黒で描画 = 背景を追加（マスクを黒に）
                    // 描画された部分を黒で上書き
                    // 描画をマスクとして使用して黒で塗りつぶす
                    cgContext.saveGState()
                    cgContext.clip(to: imageRect, mask: grayDrawingCG)
                    cgContext.setFillColor(UIColor.black.cgColor)
                    cgContext.fill(imageRect)
                    cgContext.restoreGState()
                }
            }
            
            print("✅ [MaskEditing] Mask updated, applying to image...")
            
            // マスクを更新（メインスレッドで実行）
            DispatchQueue.main.async {
                viewModel.updateMask(updatedMask)
            }
        }
        
        // ツールを切り替え（追加/削除）
        func switchTool(isAdding: Bool) {
            isAddingMode = isAdding
            guard let canvasView = canvasView else { return }
            
            if isAdding {
                // 白で描画（前景を追加）
                canvasView.tool = PKInkingTool(.pen, color: .white, width: 30)
            } else {
                // 黒で描画（背景を追加 = 前景を削除）
                canvasView.tool = PKInkingTool(.pen, color: .black, width: 30)
            }
        }
    }
}
