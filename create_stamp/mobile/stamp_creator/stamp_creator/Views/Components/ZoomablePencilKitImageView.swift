//
//  ZoomablePencilKitImageView.swift
//  stamp_creator
//
//  PencilKitとZoomableScrollViewを組み合わせた画像編集ビュー
//

import SwiftUI
import PencilKit

struct ZoomablePencilKitImageView: UIViewRepresentable {
    let image: UIImage
    @Binding var canvasView: PKCanvasView?
    @Binding var toolPicker: PKToolPicker?
    @Binding var isToolPickerVisible: Bool
    // MARK: - テキスト入力関連のバインディング（コメントアウト）
    // @Binding var textLayers: [TextLayer]
    // @Binding var editingTextLayer: TextLayer?
    // @Binding var showingTextEditor: Bool
    // var onAddText: (() -> Void)?
    // var onAddTextAtPosition: ((CGPoint) -> Void)?
    // var onShowAddMenu: ((CGPoint) -> Void)?
    var onUndoRedoStateChanged: (() -> Void)?
    var onImageViewFrameChanged: ((CGRect) -> Void)?
    @Environment(\.colorScheme) var colorScheme
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        // ZoomableScrollViewを作成
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.backgroundColor = .clear
        scrollView.delegate = context.coordinator
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(scrollView)
        
        // 画像とキャンバスを同じコンテナビューに配置
        // このコンテナビューをズーム対象にする
        let contentContainer = UIView()
        contentContainer.backgroundColor = .clear
        contentContainer.translatesAutoresizingMaskIntoConstraints = true
        scrollView.addSubview(contentContainer)
        
        // 画像ビュー（カスタムクラスでフレーム変更を監視）
        let imageView = FrameTrackingImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        imageView.translatesAutoresizingMaskIntoConstraints = true
        contentContainer.addSubview(imageView)
        
        // coordinatorを変数に代入してからクロージャで使用
        let coordinator = context.coordinator
        imageView.onFrameChanged = { [weak coordinator, weak imageView] frame in
            coordinator?.onImageViewFrameChanged?(frame)
            // フレームが変更されたら枠を更新
            if let imageView = imageView, let containerView = coordinator?.containerView, let scrollView = coordinator?.scrollView {
                coordinator?.updateImageBorder(for: imageView, in: containerView, scrollView: scrollView)
            }
        }
        
        // 画像の枠を表示するビュー
        let borderView = ImageBorderView()
        borderView.isUserInteractionEnabled = false
        borderView.translatesAutoresizingMaskIntoConstraints = true
        borderView.updateBorderColor(isDarkMode: colorScheme == .dark)
        scrollView.addSubview(borderView)
        context.coordinator.borderView = borderView
        
        // PencilKitキャンバス
        // キャンバスを画像と同じ位置・サイズに配置
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.delegate = context.coordinator
        canvas.translatesAutoresizingMaskIntoConstraints = true
        // キャンバスを画像の上に配置（同じ位置・サイズ）
        contentContainer.addSubview(canvas)
        
        // MARK: - タップジェスチャー（テキスト追加用、コメントアウト）
        // // タップジェスチャーを追加（テキスト追加用）
        // let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleImageTap(_:)))
        // tapGesture.numberOfTapsRequired = 1
        // tapGesture.numberOfTouchesRequired = 1
        // // ペンが表示されている時は描画を優先
        // tapGesture.requiresExclusiveTouchType = false
        // canvas.addGestureRecognizer(tapGesture)
        
        context.coordinator.contentContainer = contentContainer
        // MARK: - テキストレイヤー関連（コメントアウト）
        // context.coordinator.textLayers = textLayers
        // context.coordinator.editingTextLayer = editingTextLayer
        // context.coordinator.showingTextEditor = showingTextEditor
        
        // 制約を設定（scrollViewのみ）
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // PKToolPickerを設定（iOS 18以降でカスタムツールを追加）
        var picker: PKToolPicker?
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           windowScene.windows.first != nil {
            // PKToolPickerを作成
            picker = PKToolPicker()
            
            // MARK: - +ボタン（テキスト追加用、コメントアウト）
            // // iOS 18以降で+ボタンをアクセサリアイテムとして追加（色選択の外側に表示）
            // if #available(iOS 18.0, *) {
            //     if let picker = picker {
            //         // +ボタンをアクセサリアイテムとして追加
            //         let addButton = UIBarButtonItem(
            //             image: UIImage(systemName: "plus.circle.fill"),
            //             style: .plain,
            //             target: context.coordinator,
            //             action: #selector(Coordinator.handleAddButtonTap)
            //         )
            //         picker.accessoryItem = addButton
            //         picker.delegate = context.coordinator
            //     }
            // }
            
            if let picker = picker {
                picker.addObserver(canvas)
                picker.setVisible(isToolPickerVisible, forFirstResponder: canvas)
                
                // MARK: - +ボタン（テキスト追加用、コメントアウト）
                // iOS 18以降で+ボタンをアクセサリアイテムとして追加（色選択の外側に表示）
                // if #available(iOS 18.0, *) {
                //     // +ボタンをアクセサリアイテムとして追加
                //     let coordinator = context.coordinator
                //     let addButton = UIBarButtonItem(
                //         image: UIImage(systemName: "plus.circle.fill"),
                //         style: .plain,
                //         target: coordinator,
                //         action: #selector(Coordinator.handleAddButtonTap)
                //     )
                //     picker.accessoryItem = addButton
                //     picker.delegate = coordinator
                // }
                
                if isToolPickerVisible {
                    canvas.becomeFirstResponder()
                }
            }
        }
        
        context.coordinator.scrollView = scrollView
        context.coordinator.canvasView = canvas
        context.coordinator.imageView = imageView
        context.coordinator.toolPicker = picker
        context.coordinator.containerView = containerView
        // MARK: - テキストレイヤー関連の更新（コメントアウト）
        // context.coordinator.textLayers = textLayers
        // context.coordinator.editingTextLayer = editingTextLayer
        // context.coordinator.showingTextEditor = showingTextEditor
        // context.coordinator.onAddText = onAddText
        // context.coordinator.onAddTextAtPosition = onAddTextAtPosition
        // context.coordinator.onShowAddMenu = onShowAddMenu
        context.coordinator.onUndoRedoStateChanged = onUndoRedoStateChanged
        context.coordinator.onImageViewFrameChanged = onImageViewFrameChanged
        
        // MARK: - テキストレイヤー関連のクロージャ設定（コメントアウト）
        // // SwiftUIのBindingを更新するためのクロージャを設定（初回のみ）
        // if context.coordinator.onTextLayersUpdate == nil {
        //     context.coordinator.onTextLayersUpdate = { [self] (newLayers: [TextLayer]) in
        //         self.textLayers = newLayers
        //     }
        //     context.coordinator.onEditingTextLayerUpdate = { [self] (newLayer: TextLayer?) in
        //         self.editingTextLayer = newLayer
        //     }
        //     context.coordinator.onShowingTextEditorUpdate = { [self] (newValue: Bool) in
        //         self.showingTextEditor = newValue
        //     }
        // }
        
        // 初期レイアウトを設定
        DispatchQueue.main.async {
            let boundsSize = scrollView.bounds.size
            if boundsSize.width > 0 && boundsSize.height > 0 {
                let imageSize = image.size
                let scale = min(boundsSize.width / imageSize.width, boundsSize.height / imageSize.height)
                let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
                let contentFrame = CGRect(
                    x: (boundsSize.width - scaledSize.width) / 2,
                    y: (boundsSize.height - scaledSize.height) / 2,
                    width: scaledSize.width,
                    height: scaledSize.height
                )
                
                // コンテナビューのフレームを設定
                contentContainer.frame = contentFrame
                
                // 画像とキャンバスをコンテナビューの全体に配置
                imageView.frame = CGRect(origin: .zero, size: contentFrame.size)
                canvas.frame = CGRect(origin: .zero, size: contentFrame.size)
                
                scrollView.contentSize = boundsSize
                coordinator.updateImageBorder(for: imageView, in: containerView, scrollView: scrollView)
            }
        }
        
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
              let toolPicker = context.coordinator.toolPicker,
              let scrollView = context.coordinator.scrollView,
              let containerView = context.coordinator.containerView else { return }
              // let contentContainer = context.coordinator.contentContainer else { return } // コメントアウト（未使用）
        
        // カラースキームが変更されたら枠の色を更新
        if let borderView = context.coordinator.borderView {
            borderView.updateBorderColor(isDarkMode: colorScheme == .dark)
        }
        
        // 画像が変更された場合
        if imageView.image != image {
            imageView.image = image
            // FrameTrackingImageViewが自動的にフレームを通知する
        }
        
        // MARK: - テキストレイヤー更新処理（コメントアウト）
        // // テキストレイヤーを更新
        // let textLayersChanged = context.coordinator.textLayers.count != textLayers.count || 
        //                         context.coordinator.textLayers.map { $0.id } != textLayers.map { $0.id }
        // 
        // if textLayersChanged {
        //     context.coordinator.textLayers = textLayers
        //     context.coordinator.updateTextViews(in: scrollView, contentContainer: contentContainer)
        // } else {
        //     // 既存のテキストレイヤーの内容を更新
        //     for textLayer in textLayers {
        //         if let textView = context.coordinator.textViews[textLayer.id] {
        //             textView.textLayer = textLayer
        //             if let textView = textView.textView {
        //                 textView.text = textLayer.text
        //                 textView.font = UIFont(name: textLayer.fontName, size: textLayer.fontSize) ?? UIFont.systemFont(ofSize: textLayer.fontSize)
        //                 textView.textColor = textLayer.textColor
        //                 textView.backgroundColor = textLayer.backgroundColor ?? .clear
        //                 textView.textAlignment = textLayer.alignment
        //             }
        //             if let contentContainer = context.coordinator.contentContainer {
        //                 context.coordinator.updateTextViewFrame(textView, textLayer: textLayer, in: scrollView, contentContainer: contentContainer)
        //             }
        //         }
        //     }
        // }
        // 
        // if context.coordinator.editingTextLayer?.id != editingTextLayer?.id {
        //     context.coordinator.editingTextLayer = editingTextLayer
        // }
        // 
        // if context.coordinator.showingTextEditor != showingTextEditor {
        //     context.coordinator.showingTextEditor = showingTextEditor
        // }
        
        // 枠を更新
        context.coordinator.updateImageBorder(for: imageView, in: containerView, scrollView: scrollView)
        
        // ツールピッカーの表示状態に応じて描画ポリシーと表示状態を変更
        toolPicker.setVisible(isToolPickerVisible, forFirstResponder: canvasView)
        if isToolPickerVisible {
            canvasView.drawingPolicy = .anyInput
            canvasView.becomeFirstResponder()
        } else {
            canvasView.drawingPolicy = .pencilOnly
        }
    }
    
    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator()
        // MARK: - テキストレイヤー関連のクロージャ設定（コメントアウト）
        // Bindingを更新するためのクロージャを設定
        // coordinator.onTextLayersUpdate = { [self] (newLayers: [TextLayer]) in
        //     self.textLayers = newLayers
        // }
        // coordinator.onEditingTextLayerUpdate = { [self] (newLayer: TextLayer?) in
        //     self.editingTextLayer = newLayer
        // }
        // coordinator.onShowingTextEditorUpdate = { [self] (newValue: Bool) in
        //     self.showingTextEditor = newValue
        // }
        return coordinator
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate, UIScrollViewDelegate, PKToolPicker.Delegate {
        var scrollView: UIScrollView?
        var canvasView: PKCanvasView?
        var imageView: UIImageView?
        var toolPicker: PKToolPicker?
        var borderView: ImageBorderView?
        var containerView: UIView?
        var contentContainer: UIView?
        // MARK: - テキストレイヤー関連（コメントアウト）
        // var textLayers: [TextLayer] = []
        // var editingTextLayer: TextLayer?
        // var showingTextEditor: Bool = false
        // var textViews: [UUID: EditableTextContainerView] = [:]
        var onUndoRedoStateChanged: (() -> Void)?
        var onImageViewFrameChanged: ((CGRect) -> Void)?
        private var lastImageFrame: CGRect = .zero
        
        // MARK: - テキストレイヤー関連のコールバック（コメントアウト）
        // var onTextLayersUpdate: (([TextLayer]) -> Void)?
        // var onEditingTextLayerUpdate: ((TextLayer?) -> Void)?
        // var onShowingTextEditorUpdate: ((Bool) -> Void)?
        // var onAddText: (() -> Void)?
        // var onAddTextAtPosition: ((CGPoint) -> Void)?
        // var onShowAddMenu: ((CGPoint) -> Void)?
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            // コンテナビューをズーム対象にする
            // これにより、画像とキャンバスが一緒にズームされる
            return contentContainer
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let contentContainer = contentContainer,
                  let imageView = imageView else { return }
            
            let boundsSize = scrollView.bounds.size
            var frameToCenter = contentContainer.frame
            
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
            
            contentContainer.frame = frameToCenter
            
            scrollView.contentSize = CGSize(
                width: max(boundsSize.width, frameToCenter.width),
                height: max(boundsSize.height, frameToCenter.height)
            )
            
            // 枠を更新
            if let containerView = containerView {
                updateImageBorder(for: imageView, in: containerView, scrollView: scrollView)
            }
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let imageView = imageView,
                  let containerView = containerView else { return }
            
            updateImageBorder(for: imageView, in: containerView, scrollView: scrollView)
        }
        
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            DispatchQueue.main.async { [weak self] in
                self?.onUndoRedoStateChanged?()
            }
        }
        
        func updateImageBorder(for imageView: UIImageView, in containerView: UIView, scrollView: UIScrollView) {
            guard let borderView = borderView,
                  let image = imageView.image,
                  let contentContainer = contentContainer else { return }
            
            let boundsSize = scrollView.bounds.size
            guard boundsSize.width > 0 && boundsSize.height > 0 else { return }
            
            let imageSize = image.size
            guard imageSize.width > 0 && imageSize.height > 0 else { return }
            
            // コンテナビューがズームされているので、そのフレームを取得
            let containerFrame = contentContainer.frame
            
            // 画像のアスペクト比から実際の表示サイズを計算
            let imageAspect = imageSize.width / imageSize.height
            let containerAspect = containerFrame.width / containerFrame.height
            
            let displaySize: CGSize
            let displayOrigin: CGPoint
            
            if imageAspect > containerAspect {
                // 画像の方が横長 → 幅に合わせる
                displaySize = CGSize(width: containerFrame.width, height: containerFrame.width / imageAspect)
                displayOrigin = CGPoint(
                    x: containerFrame.origin.x,
                    y: containerFrame.origin.y + (containerFrame.height - displaySize.height) / 2
                )
            } else {
                // 画像の方が縦長 → 高さに合わせる
                displaySize = CGSize(width: containerFrame.height * imageAspect, height: containerFrame.height)
                displayOrigin = CGPoint(
                    x: containerFrame.origin.x + (containerFrame.width - displaySize.width) / 2,
                    y: containerFrame.origin.y
                )
            }
            
            let imageFrame = CGRect(origin: displayOrigin, size: displaySize)
            
            guard imageFrame.width > 0 && imageFrame.height > 0 else {
                borderView.isHidden = true
                return
            }
            
            // スクロールビューのオフセットを考慮
            let scrollOffset = scrollView.contentOffset
            
            // 実際の画像フレーム（スクロールビュー座標系）
            let actualImageFrame = CGRect(
                x: imageFrame.origin.x + scrollOffset.x,
                y: imageFrame.origin.y + scrollOffset.y,
                width: imageFrame.width,
                height: imageFrame.height
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
        
        // MARK: - テキストビュー更新処理（コメントアウト）
        // func updateTextViews(in scrollView: UIScrollView, contentContainer: UIView) {
        //     guard imageView != nil else { return }
        //     
        //     // 既存のテキストビューを削除
        //     for (id, textView) in textViews {
        //         if !textLayers.contains(where: { $0.id == id }) {
        //             textView.removeFromSuperview()
        //             textViews.removeValue(forKey: id)
        //         }
        //     }
        //     
        //     // 新しいテキストレイヤーを追加または更新
        //     for textLayer in textLayers {
        //         if let existingView = textViews[textLayer.id] {
        //             // 既存のビューを更新
        //             existingView.textLayer = textLayer
        //             updateTextViewFrame(existingView, textLayer: textLayer, in: scrollView, contentContainer: contentContainer)
        //         } else {
        //             // 新しいテキストビューを作成
        //             let textContainer = EditableTextContainerView()
        //             textContainer.textLayer = textLayer
        //             let layerId = textLayer.id
        //             
        //             // UITextViewを作成
        //             let textView = UITextView()
        //             textView.text = textLayer.text
        //             textView.font = UIFont(name: textLayer.fontName, size: textLayer.fontSize) ?? UIFont.systemFont(ofSize: textLayer.fontSize)
        //             textView.textColor = textLayer.textColor
        //             textView.backgroundColor = textLayer.backgroundColor ?? .clear
        //             textView.textAlignment = textLayer.alignment
        //             textView.isScrollEnabled = false
        //             textView.isEditable = true
        //             textView.layer.cornerRadius = 4
        //             textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        //             textView.translatesAutoresizingMaskIntoConstraints = false
        //             let textDelegate = TextTextViewDelegate(
        //                 onTextChanged: { [weak self] (newText: String) in
        //                     guard let self = self else { return }
        //                     if let index = self.textLayers.firstIndex(where: { $0.id == layerId }) {
        //                         self.textLayers[index].text = newText
        //                         DispatchQueue.main.async {
        //                             self.onTextLayersUpdate?(self.textLayers)
        //                         }
        //                     }
        //                 }
        //             )
        //             textView.delegate = textDelegate
        //             // delegateを保持するために、textContainerに保存
        //             objc_setAssociatedObject(textContainer, "textDelegate", textDelegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        //             textContainer.addSubview(textView)
        //             textContainer.textView = textView
        //             
        //             // 制約を設定
        //             NSLayoutConstraint.activate([
        //                 textView.topAnchor.constraint(equalTo: textContainer.topAnchor),
        //                 textView.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor),
        //                 textView.trailingAnchor.constraint(equalTo: textContainer.trailingAnchor),
        //                 textView.bottomAnchor.constraint(equalTo: textContainer.bottomAnchor)
        //             ])
        //             
        //             textContainer.onTap = { [weak self] in
        //                 guard let self = self else { return }
        //                 if let layer = self.textLayers.first(where: { $0.id == layerId }) {
        //                     DispatchQueue.main.async {
        //                         self.onEditingTextLayerUpdate?(layer)
        //                         self.onShowingTextEditorUpdate?(true)
        //                     }
        //                 }
        //             }
        //             textContainer.onDelete = { [weak self] in
        //                 guard let self = self else { return }
        //                 self.textLayers.removeAll { $0.id == layerId }
        //                 DispatchQueue.main.async {
        //                     self.onTextLayersUpdate?(self.textLayers)
        //                 }
        //             }
        //             
        //             updateTextViewFrame(textContainer, textLayer: textLayer, in: scrollView, contentContainer: contentContainer)
        //             scrollView.addSubview(textContainer)
        //             textViews[textLayer.id] = textContainer
        //         }
        //     }
        // }
        // 
        // func updateTextViewFrame(_ textView: EditableTextContainerView, textLayer: TextLayer, in scrollView: UIScrollView, contentContainer: UIView) {
        //     // テキストの位置をスクロールビュー座標系に変換
        //     let position = textLayer.position
        //     
        //     // フォントサイズを計算
        //     let font = UIFont(name: textLayer.fontName, size: textLayer.fontSize) ?? UIFont.systemFont(ofSize: textLayer.fontSize)
        //     let attributes: [NSAttributedString.Key: Any] = [.font: font]
        //     let textSize = (textLayer.text as NSString).size(withAttributes: attributes)
        //     
        //     // フレームを計算（スクロールビュー座標系）
        //     let frame = CGRect(
        //         x: position.x - textSize.width / 2,
        //         y: position.y - textSize.height / 2,
        //         width: max(100, textSize.width + 16),
        //         height: max(50, textSize.height + 16)
        //     )
        //     textView.frame = frame
        // }
        
        // MARK: - PKToolPicker.Delegate & Actions
        
        // MARK: - テキスト追加関連のアクション（コメントアウト）
        // @objc func handleAddButtonTap() {
        //     // +ボタンがタップされたら、メニューを表示
        //     if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
        //        let window = windowScene.windows.first {
        //         // ツールピッカーの位置を取得（画面下部中央あたり）
        //         let menuPosition = CGPoint(
        //             x: window.bounds.width / 2,
        //             y: window.bounds.height - 100
        //         )
        //         DispatchQueue.main.async {
        //             self.onShowAddMenu?(menuPosition)
        //         }
        //     }
        // }
        // 
        // @objc func handleImageTap(_ gesture: UITapGestureRecognizer) {
        //     // ペンが表示されている時は描画を優先（タップでテキスト追加しない）
        //     guard let toolPicker = toolPicker,
        //           !toolPicker.isVisible else {
        //         // ペンが非表示の時のみ、タップ位置にテキストを追加
        //         let location = gesture.location(in: gesture.view)
        //         // スクロールビューの座標系に変換
        //         if let scrollView = scrollView {
        //             let scrollViewLocation = gesture.view?.convert(location, to: scrollView) ?? location
        //             DispatchQueue.main.async {
        //                 self.onAddTextAtPosition?(scrollViewLocation)
        //             }
        //         }
        //         return
        //     }
        // }
    }
}

// MARK: - Text TextView Delegate

class TextTextViewDelegate: NSObject, UITextViewDelegate {
    let onTextChanged: (String) -> Void
    
    init(onTextChanged: @escaping (String) -> Void) {
        self.onTextChanged = onTextChanged
    }
    
    func textViewDidChange(_ textView: UITextView) {
        onTextChanged(textView.text)
    }
}

