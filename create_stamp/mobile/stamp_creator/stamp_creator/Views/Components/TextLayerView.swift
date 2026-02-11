//
//  TextLayerView.swift
//  stamp_creator
//
//  テキストレイヤー表示ビュー
//

import SwiftUI

struct TextLayerView: View {
    @Binding var textLayer: TextLayer
    let imageFrame: CGRect
    let onTap: () -> Void
    let onDelete: () -> Void
    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        Text(textLayer.text)
            .font(.custom(textLayer.fontName, size: textLayer.fontSize))
            .foregroundColor(Color(textLayer.textColor))
            .padding(textLayer.backgroundColor != nil ? 8 : 0)
            .background(
                textLayer.backgroundColor != nil ?
                    Color(textLayer.backgroundColor!)
                        .cornerRadius(4) : nil
            )
            .position(
                x: textLayer.position.x + dragOffset.width,
                y: textLayer.position.y + dragOffset.height
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                        }
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        textLayer.position = CGPoint(
                            x: textLayer.position.x + value.translation.width,
                            y: textLayer.position.y + value.translation.height
                        )
                        dragOffset = .zero
                        isDragging = false
                    }
            )
            .onTapGesture {
                onTap()
            }
            .contextMenu {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
    }
}
