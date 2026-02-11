//
//  EditableTextView.swift
//  stamp_creator
//
//  画像上に直接配置できる編集可能なテキストビュー（iOS Photosアプリ風）
//

import SwiftUI
import UIKit

struct EditableTextView: UIViewRepresentable {
    @Binding var textLayer: TextLayer
    let imageFrame: CGRect
    let onTap: () -> Void
    let onDelete: () -> Void
    let onTextChanged: (String) -> Void
    
    func makeUIView(context: Context) -> EditableTextContainerView {
        let containerView = EditableTextContainerView()
        containerView.textLayer = textLayer
        containerView.imageFrame = imageFrame
        containerView.onTap = onTap
        containerView.onDelete = onDelete
        containerView.onTextChanged = onTextChanged
        
        // UITextViewを作成
        let textView = UITextView()
        textView.text = textLayer.text
        textView.font = UIFont(name: textLayer.fontName, size: textLayer.fontSize) ?? UIFont.systemFont(ofSize: textLayer.fontSize)
        textView.textColor = textLayer.textColor
        textView.backgroundColor = textLayer.backgroundColor ?? .clear
        textView.textAlignment = textLayer.alignment
        textView.isScrollEnabled = false
        textView.isEditable = true
        textView.delegate = context.coordinator
        textView.layer.cornerRadius = 4
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(textView)
        containerView.textView = textView
        
        // 削除ボタン
        let deleteButton = UIButton(type: .system)
        deleteButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        deleteButton.tintColor = .white
        deleteButton.backgroundColor = .red
        deleteButton.layer.cornerRadius = 12
        deleteButton.addTarget(context.coordinator, action: #selector(Coordinator.deleteText), for: .touchUpInside)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.isHidden = true
        containerView.addSubview(deleteButton)
        containerView.deleteButton = deleteButton
        
        // 制約を設定
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: containerView.topAnchor),
            textView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            deleteButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: -8),
            deleteButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: 8),
            deleteButton.widthAnchor.constraint(equalToConstant: 24),
            deleteButton.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        context.coordinator.containerView = containerView
        context.coordinator.textView = textView
        
        return containerView
    }
    
    func updateUIView(_ uiView: EditableTextContainerView, context: Context) {
        uiView.textLayer = textLayer
        uiView.imageFrame = imageFrame
        
        // テキストビューを更新
        if let textView = uiView.textView {
            if textView.text != textLayer.text {
                textView.text = textLayer.text
            }
            
            let font = UIFont(name: textLayer.fontName, size: textLayer.fontSize) ?? UIFont.systemFont(ofSize: textLayer.fontSize)
            if textView.font != font {
                textView.font = font
            }
            
            if textView.textColor != textLayer.textColor {
                textView.textColor = textLayer.textColor
            }
            
            if textView.backgroundColor != (textLayer.backgroundColor ?? .clear) {
                textView.backgroundColor = textLayer.backgroundColor ?? .clear
            }
            
            if textView.textAlignment != textLayer.alignment {
                textView.textAlignment = textLayer.alignment
            }
        }
        
        // 位置を更新
        let position = textLayer.position
        uiView.frame = CGRect(
            x: position.x - 50,
            y: position.y - 25,
            width: 100,
            height: 50
        )
        
        // テキストサイズに合わせてフレームを調整
        if let textView = uiView.textView {
            let size = textView.sizeThatFits(CGSize(width: 200, height: CGFloat.greatestFiniteMagnitude))
            uiView.frame = CGRect(
                x: position.x - size.width / 2,
                y: position.y - size.height / 2,
                width: max(100, size.width),
                height: max(50, size.height)
            )
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: EditableTextView
        var containerView: EditableTextContainerView?
        var textView: UITextView?
        
        init(_ parent: EditableTextView) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.onTextChanged(textView.text)
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            // 編集中は削除ボタンを表示
            containerView?.deleteButton?.isHidden = false
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            // 編集終了時は削除ボタンを非表示
            containerView?.deleteButton?.isHidden = true
        }
        
        @objc func deleteText() {
            parent.onDelete()
        }
    }
}

class EditableTextContainerView: UIView {
    var textLayer: TextLayer?
    var imageFrame: CGRect = .zero
    var textView: UITextView?
    var deleteButton: UIButton?
    var onTap: (() -> Void)?
    var onDelete: (() -> Void)?
    var onTextChanged: ((String) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGestures()
    }
    
    private func setupGestures() {
        // タップジェスチャー
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        
        // ドラッグジェスチャー
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)
        
        // ピンチジェスチャー（文字サイズ変更用）
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinchGesture)
    }
    
    @objc private func handleTap() {
        onTap?()
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = superview else { return }
        let translation = gesture.translation(in: superview)
        
        switch gesture.state {
        case .began, .changed:
            center = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
            gesture.setTranslation(.zero, in: superview)
            
            // テキストレイヤーの位置を更新
            if var layer = textLayer {
                layer.position = center
                textLayer = layer
            }
        case .ended:
            // 位置を確定
            if var layer = textLayer {
                layer.position = center
                textLayer = layer
            }
        default:
            break
        }
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard var layer = textLayer else { return }
        
        switch gesture.state {
        case .began:
            // 初期サイズを保存
            gesture.scale = layer.fontSize / 32.0 // 基準サイズで正規化
        case .changed:
            // フォントサイズを更新（最小12、最大200）
            let newSize = max(12, min(200, 32.0 * gesture.scale))
            layer.fontSize = newSize
            textLayer = layer
            
            // テキストビューを更新
            if let textView = textView {
                textView.font = UIFont(name: layer.fontName, size: newSize) ?? UIFont.systemFont(ofSize: newSize)
                // フレームを再計算
                let font = UIFont(name: layer.fontName, size: newSize) ?? UIFont.systemFont(ofSize: newSize)
                let attributes: [NSAttributedString.Key: Any] = [.font: font]
                let textSize = (layer.text as NSString).size(withAttributes: attributes)
                frame = CGRect(
                    x: center.x - textSize.width / 2,
                    y: center.y - textSize.height / 2,
                    width: max(100, textSize.width + 16),
                    height: max(50, textSize.height + 16)
                )
            }
        case .ended:
            // サイズを確定
            textLayer = layer
        default:
            break
        }
    }
}
