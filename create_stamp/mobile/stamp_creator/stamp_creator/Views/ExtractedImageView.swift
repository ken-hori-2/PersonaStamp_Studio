//
//  ExtractedImageView.swift
//  stamp_creator
//
//  抽出画像を表示するビュー
//

import SwiftUI

struct ExtractedImageView: View {
    let image: UIImage
    let onSave: () -> Void
    let onDismiss: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // チェッカーパターンの背景
                    CheckerboardPattern()
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // 拡大縮小可能な画像（画面全体を使用）
                        ZoomableExtractedImageView(image: image, scale: $scale, offset: $offset)
                            .frame(
                                width: geometry.size.width,
                                height: geometry.size.height - 100 // ボタンエリアの高さを確保
                            )
                        
                        // ボタン群
                        HStack(spacing: 16) {
                            Button(action: onDismiss) {
                                HStack(spacing: 12) {
                                    Image(systemName: "xmark")
                                        .font(.title2)
                                        .frame(width: 26, height: 26)
                                    Text("Close")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.5))
                                .cornerRadius(12)
                            }
                            
                            Button(action: onSave) {
                                HStack(spacing: 12) {
                                    Image(systemName: "square.and.arrow.down.fill")
                                        .font(.title2)
                                        .frame(width: 26, height: 26)
                                    Text("Save")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Color.indigo.opacity(0.9), Color.purple.opacity(0.9)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                                .shadow(color: .indigo.opacity(0.4), radius: 8, x: 0, y: 4)
                            }
                        }
                        .padding()
                        .frame(height: 100)
                    }
                }
            }
            .navigationTitle("Extracted Image")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - 拡大縮小可能な抽出画像ビュー

struct ZoomableExtractedImageView: UIViewRepresentable {
    let image: UIImage
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        
        scrollView.addSubview(imageView)
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.backgroundColor = .clear
        
        context.coordinator.scrollView = scrollView
        context.coordinator.imageView = imageView
        
        // 初期レイアウトを設定
        DispatchQueue.main.async {
            let boundsSize = scrollView.bounds.size
            if boundsSize.width > 0 && boundsSize.height > 0 {
                let imageSize = image.size
                guard imageSize.width > 0 && imageSize.height > 0 else { return }
                
                let scale = min(boundsSize.width / imageSize.width, boundsSize.height / imageSize.height)
                let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
                
                imageView.frame = CGRect(
                    x: (boundsSize.width - scaledSize.width) / 2,
                    y: (boundsSize.height - scaledSize.height) / 2,
                    width: scaledSize.width,
                    height: scaledSize.height
                )
                
                scrollView.contentSize = boundsSize
            }
        }
        
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        guard let imageView = context.coordinator.imageView else { return }
        
        if imageView.image != image {
            imageView.image = image
        }
        
        // レイアウトを更新（画面全体に表示されるように）
        DispatchQueue.main.async {
            let boundsSize = uiView.bounds.size
            guard boundsSize.width > 0 && boundsSize.height > 0 else { return }
            
            let imageSize = image.size
            guard imageSize.width > 0 && imageSize.height > 0 else { return }
            
            // アスペクト比を保持しながら画面全体に収まるようにスケール
            let scale = min(boundsSize.width / imageSize.width, boundsSize.height / imageSize.height)
            let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            
            imageView.frame = CGRect(
                x: (boundsSize.width - scaledSize.width) / 2,
                y: (boundsSize.height - scaledSize.height) / 2,
                width: scaledSize.width,
                height: scaledSize.height
            )
            
            uiView.contentSize = boundsSize
            uiView.zoomScale = 1.0
        }
    }
    
    func makeCoordinator() -> ExtractedImageCoordinator {
        ExtractedImageCoordinator()
    }
    
    class ExtractedImageCoordinator: NSObject, UIScrollViewDelegate {
        var scrollView: UIScrollView?
        var imageView: UIImageView?
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return imageView
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let imageView = imageView else { return }
            
            let boundsSize = scrollView.bounds.size
            var frameToCenter = imageView.frame
            
            if frameToCenter.size.width < boundsSize.width {
                frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
            } else {
                frameToCenter.origin.x = 0
            }
            
            if frameToCenter.size.height < boundsSize.height {
                frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
            } else {
                frameToCenter.origin.y = 0
            }
            
            imageView.frame = frameToCenter
        }
    }
}
