//
//  MaskEditingViewModel.swift
//  stamp_creator
//
//  マスク編集のロジックを管理するViewModel
//

import SwiftUI
import CoreImage
import Combine

class MaskEditingViewModel: ObservableObject {
    @Published var originalImage: UIImage?
    @Published var maskImage: UIImage?
    @Published var editedImage: UIImage?
    @Published var isEditing = false
    @Published var isAddingMode = true // true = 白（追加）、false = 黒（削除）
    
    // 編集モードを設定
    func setEditingMode(isAdding: Bool) {
        isAddingMode = isAdding
    }
    
    // マスクを初期化（透過PNG画像からアルファチャンネルを抽出）
    func initializeMask(from extractedImage: UIImage, originalImage: UIImage) {
        self.originalImage = originalImage
        
        // 透過PNG画像からアルファチャンネルをマスクとして抽出
        // より簡単な方法: 透過PNG画像を白黒に変換してマスクとして使用
        let size = extractedImage.size
        
        // 透過PNG画像を描画して、アルファチャンネルを白黒マスクに変換
        let renderer = UIGraphicsImageRenderer(size: size)
        let mask = renderer.image { context in
            // 黒で塗りつぶし（背景 = 透明部分）
            context.cgContext.setFillColor(UIColor.black.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: size))
            
            // 透過PNG画像を描画（アルファチャンネルが白になる部分）
            extractedImage.draw(in: CGRect(origin: .zero, size: size), blendMode: .normal, alpha: 1.0)
        }
        
        // グレースケールに変換
        guard let cgImage = mask.cgImage else {
            print("❌ [MaskEditing] Failed to get CGImage from mask")
            return
        }
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            print("❌ [MaskEditing] Failed to create mask context")
            return
        }
        
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        
        guard let maskCGImage = context.makeImage() else {
            print("❌ [MaskEditing] Failed to create mask CGImage")
            return
        }
        
        maskImage = UIImage(cgImage: maskCGImage)
        print("✅ [MaskEditing] Mask initialized: \(size.width)x\(size.height)")
        
        // 初期マスクを適用
        applyMaskToImage()
    }
    
    // PencilKitで編集されたマスクを更新
    func updateMask(_ newMask: UIImage) {
        print("🟢 [MaskEditing] Updating mask: \(newMask.size)")
        maskImage = newMask
        applyMaskToImage()
    }
    
    // CIBlendWithMaskフィルタでマスクを画像に適用
    func applyMaskToImage() {
        guard let originalImage = originalImage,
              let maskImage = maskImage,
              let _ = originalImage.cgImage,
              let _ = maskImage.cgImage else {
            print("⚠️ [MaskEditing] Missing images for mask application")
            return
        }
        
        // マスクを元画像と同じサイズにリサイズ
        let originalSize = originalImage.size
        let maskSize = maskImage.size
        
        let resizedMask: UIImage
        if maskSize != originalSize {
            // マスクをリサイズ
            let renderer = UIGraphicsImageRenderer(size: originalSize)
            resizedMask = renderer.image { _ in
                maskImage.draw(in: CGRect(origin: .zero, size: originalSize))
            }
        } else {
            resizedMask = maskImage
        }
        
        guard let resizedMaskCGImage = resizedMask.cgImage else {
            print("❌ [MaskEditing] Failed to create resized mask CGImage")
            return
        }
        
        // マスクを使って透過PNG画像を作成
        // UIGraphicsImageRendererを使用してRGBA形式で描画
        let renderer = UIGraphicsImageRenderer(size: originalSize, format: UIGraphicsImageRendererFormat.default())
        let maskedImage = renderer.image { context in
            let cgContext = context.cgContext
            
            // マスクをクリッピングマスクとして設定
            cgContext.clip(to: CGRect(origin: .zero, size: originalSize), mask: resizedMaskCGImage)
            
            // 元画像を描画（マスクされた部分のみ表示される）
            originalImage.draw(in: CGRect(origin: .zero, size: originalSize))
        }
        
        editedImage = maskedImage
        print("✅ [MaskEditing] Mask applied successfully: \(originalSize.width)x\(originalSize.height)")
    }
    
    // 編集をリセット
    func reset() {
        maskImage = nil
        editedImage = nil
        isEditing = false
    }
}
