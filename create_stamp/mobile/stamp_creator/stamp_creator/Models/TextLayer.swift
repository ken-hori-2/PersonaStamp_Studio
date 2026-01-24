//
//  TextLayer.swift
//  stamp_creator
//
//  テキストレイヤーモデル
//

import SwiftUI
import UIKit

struct TextLayer: Identifiable {
    let id = UUID()
    var text: String
    var position: CGPoint
    var fontSize: CGFloat
    var fontName: String
    var textColor: UIColor
    var backgroundColor: UIColor?
    var alignment: NSTextAlignment
    var isSelected: Bool = false
    
    init(text: String = "テキスト",
         position: CGPoint = .zero,
         fontSize: CGFloat = 32,
         fontName: String = "HelveticaNeue-Bold",
         textColor: UIColor = .white,
         backgroundColor: UIColor? = nil,
         alignment: NSTextAlignment = .center) {
        self.text = text
        self.position = position
        self.fontSize = fontSize
        self.fontName = fontName
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.alignment = alignment
    }
}

// 利用可能なフォントリスト
struct FontOption: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let displayName: String
    let fontName: String
    
    static func == (lhs: FontOption, rhs: FontOption) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static let availableFonts: [FontOption] = [
        FontOption(id: "system", name: "system", displayName: "システム", fontName: "HelveticaNeue"),
        FontOption(id: "bold", name: "bold", displayName: "太字", fontName: "HelveticaNeue-Bold"),
        FontOption(id: "italic", name: "italic", displayName: "斜体", fontName: "HelveticaNeue-Italic"),
        FontOption(id: "condensed", name: "condensed", displayName: "コンデンス", fontName: "HelveticaNeue-CondensedBold"),
        FontOption(id: "light", name: "light", displayName: "細字", fontName: "HelveticaNeue-Light"),
        FontOption(id: "medium", name: "medium", displayName: "中太", fontName: "HelveticaNeue-Medium"),
        FontOption(id: "thin", name: "thin", displayName: "極細", fontName: "HelveticaNeue-Thin"),
        FontOption(id: "ultraLight", name: "ultraLight", displayName: "超細", fontName: "HelveticaNeue-UltraLight"),
    ]
}
