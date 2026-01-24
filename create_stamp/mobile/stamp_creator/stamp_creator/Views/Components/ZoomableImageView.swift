//
//  ZoomableImageView.swift
//  stamp_creator
//
//  拡大縮小可能な画像ビュー（ImageAnalysisInteraction対応）
//

import SwiftUI
import VisionKit

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    let onLongPress: (CGPoint) -> Void
    let onTap: (CGPoint) -> Void
    var onLongPressInScrollView: ((CGPoint) -> Void)? = nil // ScrollView内の座標（拡大時用）
    var onZoomChanged: ((CGFloat, CGPoint, CGRect) -> Void)? = nil
    @EnvironmentObject var viewModel: ImageAnalysisViewModel
    
    func makeUIView(context: Context) -> ZoomableScrollView {
        let scrollView = ZoomableScrollView()
        let imageView = CustomizedUIImageView()
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        
        // ImageAnalysisInteractionを追加
        // preferredInteractionTypesを.imageSubjectに設定して被写体の検出・選択機能を有効化
        // カスタムジェスチャーで標準メニュー（copy, add sticker）を抑制
        viewModel.interaction.preferredInteractionTypes = [.imageSubject]
        imageView.addInteraction(viewModel.interaction)
        
        scrollView.addSubview(imageView)
        scrollView.imageView = imageView
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.backgroundColor = .clear
        
        // 画像の枠を表示するビュー
        let borderView = ImageBorderView()
        borderView.isUserInteractionEnabled = false
        scrollView.addSubview(borderView)
        context.coordinator.borderView = borderView
        context.coordinator.scrollView = scrollView
        
        // 初期フレームを設定
        DispatchQueue.main.async {
            let boundsSize = scrollView.bounds.size
            if boundsSize.width > 0 && boundsSize.height > 0 {
                let imageSize = image.size
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
        
        // ジェスチャーを追加（ImageAnalysisInteractionと併用）
        // ScrollViewに追加することで、拡大時でも正しく動作するようにする
        let scrollViewLongPressGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        scrollViewLongPressGesture.minimumPressDuration = 0.3
        scrollViewLongPressGesture.allowableMovement = 10.0  // 少し動いても長押しとして認識
        scrollViewLongPressGesture.cancelsTouchesInView = false  // ScrollViewのジェスチャーと競合しないように
        scrollViewLongPressGesture.delegate = context.coordinator
        // ScrollViewのパンジェスチャーが長押しジェスチャーの失敗を待つようにする
        scrollView.panGestureRecognizer.require(toFail: scrollViewLongPressGesture)
        // ScrollViewに追加（拡大時でも動作するように）
        scrollView.addGestureRecognizer(scrollViewLongPressGesture)
        
        // imageViewにも追加（通常時用）
        let imageViewLongPressGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        imageViewLongPressGesture.minimumPressDuration = 0.3
        imageViewLongPressGesture.allowableMovement = 10.0  // 少し動いても長押しとして認識
        imageViewLongPressGesture.cancelsTouchesInView = true  // 標準のメニューを抑制
        imageViewLongPressGesture.delegate = context.coordinator
        // ScrollViewの長押しジェスチャーが失敗した場合のみ認識（重複を防ぐ）
        imageViewLongPressGesture.require(toFail: scrollViewLongPressGesture)
        imageView.addGestureRecognizer(imageViewLongPressGesture)
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = context.coordinator
        // 長押しジェスチャーが失敗した場合のみタップを認識
        tapGesture.require(toFail: scrollViewLongPressGesture)
        tapGesture.require(toFail: imageViewLongPressGesture)
        imageView.addGestureRecognizer(tapGesture)
        
        context.coordinator.scrollView = scrollView
        context.coordinator.imageView = imageView
        context.coordinator.onLongPress = { location in
            onLongPress(location)
        }
        context.coordinator.onLongPressInScrollView = onLongPressInScrollView
        context.coordinator.onTap = onTap
        context.coordinator.onZoomChanged = onZoomChanged
        
        // 初期状態のズーム情報を通知
        DispatchQueue.main.async {
            context.coordinator.notifyZoomChanged()
        }
        
        return scrollView
    }
    
    func updateUIView(_ uiView: ZoomableScrollView, context: Context) {
        guard let imageView = uiView.imageView else { return }
        
        if imageView.image != image {
            imageView.image = image
            // 画像が変更されたら、フレームを再計算
            DispatchQueue.main.async {
                let boundsSize = uiView.bounds.size
                if boundsSize.width > 0 && boundsSize.height > 0 {
                    let imageSize = image.size
                    let scale = min(boundsSize.width / imageSize.width, boundsSize.height / imageSize.height)
                    let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
                    imageView.frame = CGRect(
                        x: (boundsSize.width - scaledSize.width) / 2,
                        y: (boundsSize.height - scaledSize.height) / 2,
                        width: scaledSize.width,
                        height: scaledSize.height
                    )
                    uiView.contentSize = boundsSize
                    context.coordinator.notifyZoomChanged()
                }
            }
        }
        
        // 枠を更新
        context.coordinator.updateBorder()
        // ズーム情報を通知
        context.coordinator.notifyZoomChanged()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        var scrollView: ZoomableScrollView?
        var imageView: CustomizedUIImageView?
        var borderView: ImageBorderView?
        var onLongPress: ((CGPoint) -> Void)?
        var onLongPressInScrollView: ((CGPoint) -> Void)?
        var onTap: ((CGPoint) -> Void)?
        var onZoomChanged: ((CGFloat, CGPoint, CGRect) -> Void)?
        private var impactFeedback: UIImpactFeedbackGenerator?
        
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
            updateBorder()
            notifyZoomChanged()
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            updateBorder()
            notifyZoomChanged()
        }
        
        func notifyZoomChanged() {
            guard let scrollView = scrollView,
                  let imageView = imageView else { return }
            
            let zoomScale = scrollView.zoomScale
            let scrollOffset = scrollView.contentOffset
            let imageFrame = imageView.frame
            
            onZoomChanged?(zoomScale, scrollOffset, imageFrame)
        }
        
        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            updateBorder()
        }
        
        func updateBorder() {
            guard let scrollView = scrollView,
                  let imageView = imageView,
                  let borderView = borderView,
                  let image = imageView.image else { return }
            
            let boundsSize = scrollView.bounds.size
            guard boundsSize.width > 0 && boundsSize.height > 0 else { return }
            
            let imageSize = image.size
            guard imageSize.width > 0 && imageSize.height > 0 else { return }
            
            // 画像の実際の表示フレームを計算（scaleAspectFit）
            // imageView.frameはズーム後のサイズなので、元のサイズを計算
            let zoomScale = scrollView.zoomScale
            let originalImageFrame = CGRect(
                x: imageView.frame.origin.x / zoomScale,
                y: imageView.frame.origin.y / zoomScale,
                width: imageView.frame.width / zoomScale,
                height: imageView.frame.height / zoomScale
            )
            
            // 画像のアスペクト比から実際の表示サイズを計算
            let imageAspect = imageSize.width / imageSize.height
            let frameAspect = originalImageFrame.width / originalImageFrame.height
            
            let displaySize: CGSize
            let displayOrigin: CGPoint
            
            if imageAspect > frameAspect {
                // 画像の方が横長 → 幅に合わせる
                displaySize = CGSize(width: originalImageFrame.width, height: originalImageFrame.width / imageAspect)
                displayOrigin = CGPoint(
                    x: originalImageFrame.origin.x,
                    y: originalImageFrame.origin.y + (originalImageFrame.height - displaySize.height) / 2
                )
            } else {
                // 画像の方が縦長 → 高さに合わせる
                displaySize = CGSize(width: originalImageFrame.height * imageAspect, height: originalImageFrame.height)
                displayOrigin = CGPoint(
                    x: originalImageFrame.origin.x + (originalImageFrame.width - displaySize.width) / 2,
                    y: originalImageFrame.origin.y
                )
            }
            
            let imageFrame = CGRect(origin: displayOrigin, size: displaySize)
            
            // スクロールビューのオフセットを考慮
            let scrollOffset = scrollView.contentOffset
            
            // 実際の画像フレーム（ズームとスクロールを考慮）
            let actualImageFrame = CGRect(
                x: imageFrame.origin.x * zoomScale + scrollOffset.x,
                y: imageFrame.origin.y * zoomScale + scrollOffset.y,
                width: imageFrame.width * zoomScale,
                height: imageFrame.height * zoomScale
            )
            
            // 枠を画像より一回り大きく表示（パディング: 8px）
            let padding: CGFloat = 8.0
            let borderFrame = CGRect(
                x: actualImageFrame.origin.x - padding,
                y: actualImageFrame.origin.y - padding,
                width: actualImageFrame.width + padding * 2,
                height: actualImageFrame.height + padding * 2
            )
            
            borderView.frame = borderFrame
            borderView.updateBorder(bounds: scrollView.bounds, imageFrame: actualImageFrame)
            borderView.isHidden = false
        }
        
        // UIGestureRecognizerDelegate: ジェスチャーの同時認識を許可
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // 長押しジェスチャーは、ScrollViewのジェスチャーと同時に認識できるようにする
            if gestureRecognizer is UILongPressGestureRecognizer {
                return true
            }
            return true
        }
        
        // 長押しジェスチャーが他のジェスチャーより優先されるようにする
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // 長押しジェスチャーは、ScrollViewのパンジェスチャーより優先されるべき
            if gestureRecognizer is UILongPressGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
                return true
            }
            return false
        }
        
        // ScrollViewのパンジェスチャーが長押しジェスチャーの失敗を待つようにする
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // ScrollViewのパンジェスチャーは、長押しジェスチャーが失敗した場合のみ認識
            if gestureRecognizer is UILongPressGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
                return true
            }
            return false
        }
        
        // 長押しジェスチャーが認識可能になった時点でフィードバックを準備
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            if gestureRecognizer is UILongPressGestureRecognizer {
                // ハプティックフィードバックを事前に準備
                if impactFeedback == nil {
                    impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback?.prepare()
                }
            }
            return true
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard let imageView = imageView,
                  let scrollView = scrollView else { return }
            
            switch gesture.state {
            case .possible:
                // ジェスチャーが認識可能になった時点でフィードバックを準備
                if impactFeedback == nil {
                    impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback?.prepare()
                }
            case .began:
                // ハプティックフィードバックを発火
                impactFeedback?.impactOccurred()
                impactFeedback = nil  // 使用後はクリア
                
                // 長押し位置を画像ビューの座標系に変換
                let location: CGPoint
                let locationInScrollView: CGPoint?
                if gesture.view == scrollView {
                    // ScrollViewから呼ばれた場合（拡大時）
                    let locationInSV = gesture.location(in: scrollView)
                    locationInScrollView = locationInSV
                    let zoomScale = scrollView.zoomScale
                    let scrollOffset = scrollView.contentOffset
                    
                    // 画像ビュー内の実際の位置を計算
                    location = CGPoint(
                        x: (locationInSV.x - scrollOffset.x - imageView.frame.origin.x) / zoomScale,
                        y: (locationInSV.y - scrollOffset.y - imageView.frame.origin.y) / zoomScale
                    )
                } else {
                    // imageViewから呼ばれた場合（通常時）
                    location = gesture.location(in: imageView)
                    locationInScrollView = nil
                }
                
                print("🟢 [Coordinator] 長押し検出: \(location), zoomScale: \(scrollView.zoomScale)")
                onLongPress?(location)
                if let locationInSV = locationInScrollView {
                    onLongPressInScrollView?(locationInSV)
                }
            case .cancelled, .failed, .ended:
                impactFeedback = nil
                break
            default:
                break
            }
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let imageView = imageView else { return }
            let location = gesture.location(in: imageView)
            print("🟢 [Coordinator] タップ検出: \(location)")
            onTap?(location)
        }
    }
}

// MARK: - ZoomableScrollView

class ZoomableScrollView: UIScrollView {
    var imageView: CustomizedUIImageView?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        guard let imageView = imageView,
              let image = imageView.image else { return }
        
        let boundsSize = self.bounds.size
        guard boundsSize.width > 0 && boundsSize.height > 0 else { return }
        
        // 初期フレームが設定されていない場合、設定する
        if imageView.frame.width == 0 || imageView.frame.height == 0 {
            let imageSize = image.size
            let scale = min(boundsSize.width / imageSize.width, boundsSize.height / imageSize.height)
            let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            imageView.frame = CGRect(
                x: (boundsSize.width - scaledSize.width) / 2,
                y: (boundsSize.height - scaledSize.height) / 2,
                width: scaledSize.width,
                height: scaledSize.height
            )
            self.contentSize = boundsSize
        } else {
            // 既にフレームが設定されている場合、中央に配置
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

// MARK: - CustomizedUIImageView

class CustomizedUIImageView: UIImageView {
    override var intrinsicContentSize: CGSize {
        .zero
    }
}

// MARK: - Image Border View

class ImageBorderView: UIView {
    private let borderLayer = CAShapeLayer()
    private let edgeLayers: [CAShapeLayer] = (0..<4).map { _ in CAShapeLayer() }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupBorder()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupBorder()
    }
    
    private func setupBorder() {
        backgroundColor = .clear
        
        // メインの枠線
        borderLayer.strokeColor = UIColor.white.withAlphaComponent(0.6).cgColor
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.lineWidth = 2.0
        borderLayer.lineCap = .round
        borderLayer.lineJoin = .round
        layer.addSublayer(borderLayer)
        
        // 境目の線（見切れそうな時用）
        for edgeLayer in edgeLayers {
            edgeLayer.strokeColor = UIColor.white.withAlphaComponent(0.8).cgColor
            edgeLayer.fillColor = UIColor.clear.cgColor
            edgeLayer.lineWidth = 1.5
            layer.addSublayer(edgeLayer)
        }
    }
    
    func updateBorder(bounds: CGRect, imageFrame: CGRect) {
        // borderViewのframeは既にimageFrameより一回り大きく設定されている
        // そのため、borderView内での座標は、paddingを考慮する必要がある
        let padding: CGFloat = 8.0
        let borderRect = CGRect(
            x: padding,
            y: padding,
            width: max(0, imageFrame.width),
            height: max(0, imageFrame.height)
        )
        
        guard borderRect.width > 0 && borderRect.height > 0 else {
            borderLayer.path = nil
            for edgeLayer in edgeLayers {
                edgeLayer.isHidden = true
            }
            return
        }
        
        // メインの枠線（角丸）
        let borderPath = UIBezierPath(roundedRect: borderRect, cornerRadius: 8.0)
        borderLayer.path = borderPath.cgPath
        
        // 境目の線を描画（見切れそうな時）
        // 注意: imageFrameとboundsは同じ座標系（スクロールビュー座標系）である必要がある
        let edgePadding: CGFloat = 10.0 // より厳密な条件にする
        let edgeLength: CGFloat = 20.0
        let cornerRadius: CGFloat = 8.0
        
        // すべての境目の線を一旦非表示にする
        for edgeLayer in edgeLayers {
            edgeLayer.isHidden = true
        }
        
        // 上端が見切れているかチェック（左上角を避ける）
        if imageFrame.minY < bounds.minY + edgePadding && imageFrame.minY < bounds.minY {
            let topPath = UIBezierPath()
            let startX = borderRect.minX + cornerRadius + 5.0
            topPath.move(to: CGPoint(x: startX, y: padding))
            topPath.addLine(to: CGPoint(x: startX + edgeLength, y: padding))
            edgeLayers[0].path = topPath.cgPath
            edgeLayers[0].isHidden = false
        }
        
        // 右端が見切れているかチェック（右上角を避ける）
        if imageFrame.maxX > bounds.maxX - edgePadding && imageFrame.maxX > bounds.maxX {
            let rightPath = UIBezierPath()
            let startY = borderRect.minY + cornerRadius + 5.0
            rightPath.move(to: CGPoint(x: borderRect.maxX, y: startY))
            rightPath.addLine(to: CGPoint(x: borderRect.maxX, y: startY + edgeLength))
            edgeLayers[1].path = rightPath.cgPath
            edgeLayers[1].isHidden = false
        }
        
        // 下端が見切れているかチェック（右下角を避ける）
        if imageFrame.maxY > bounds.maxY - edgePadding && imageFrame.maxY > bounds.maxY {
            let bottomPath = UIBezierPath()
            let startX = borderRect.maxX - cornerRadius - 5.0 - edgeLength
            bottomPath.move(to: CGPoint(x: startX, y: borderRect.maxY))
            bottomPath.addLine(to: CGPoint(x: startX + edgeLength, y: borderRect.maxY))
            edgeLayers[2].path = bottomPath.cgPath
            edgeLayers[2].isHidden = false
        }
        
        // 左端が見切れているかチェック（左下角を避ける）
        if imageFrame.minX < bounds.minX + edgePadding && imageFrame.minX < bounds.minX {
            let leftPath = UIBezierPath()
            let startY = borderRect.maxY - cornerRadius - 5.0 - edgeLength
            leftPath.move(to: CGPoint(x: borderRect.minX, y: startY))
            leftPath.addLine(to: CGPoint(x: borderRect.minX, y: startY + edgeLength))
            edgeLayers[3].path = leftPath.cgPath
            edgeLayers[3].isHidden = false
        }
    }
}
