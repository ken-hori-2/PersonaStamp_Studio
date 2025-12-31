//
//  EmotionTag.swift
//  RendVu
//
//  Created on 2025-01-XX.
//

import Foundation

struct EmotionTag: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let example: String
    
    static let allTags: [EmotionTag] = [
        EmotionTag(id: "happy", name: "嬉しい", description: "嬉しい気持ちを表現", example: "(happy) とても嬉しいニュースです！"),
        EmotionTag(id: "sad", name: "悲しい", description: "悲しい気持ちを表現", example: "(sad) 残念ながら、期待通りではありませんでした。"),
        EmotionTag(id: "excited", name: "興奮", description: "興奮した気持ちを表現", example: "(excited) これは素晴らしい発見です！"),
        EmotionTag(id: "calm", name: "穏やか", description: "穏やかな気持ちを表現", example: "(calm) それでは、説明を始めます。"),
        EmotionTag(id: "angry", name: "怒り", description: "怒りの気持ちを表現", example: "(angry) これは許せません！"),
        EmotionTag(id: "surprised", name: "驚き", description: "驚きの気持ちを表現", example: "(surprised) まさか、そんなことが！"),
        EmotionTag(id: "whispering", name: "ささやき", description: "ささやくような声で", example: "(whispering) これは秘密です。"),
        EmotionTag(id: "shouting", name: "叫び", description: "叫ぶような声で", example: "(shouting) 助けて！"),
        EmotionTag(id: "laughing", name: "笑い", description: "笑いながら", example: "(laughing) それは面白いですね！")
    ]
    
    var tagString: String {
        return "(\(id))"
    }
}

struct EmotionTagHelper {
    static func insertTag(_ tag: EmotionTag, into text: String, at cursorPosition: Int) -> (newText: String, newCursorPosition: Int) {
        let tagString = tag.tagString + " "
        let beforeCursor = String(text.prefix(cursorPosition))
        let afterCursor = String(text.suffix(text.count - cursorPosition))
        let newText = beforeCursor + tagString + afterCursor
        let newCursorPosition = cursorPosition + tagString.count
        return (newText, newCursorPosition)
    }
    
    static func extractTags(from text: String) -> [EmotionTag] {
        var foundTags: [EmotionTag] = []
        for tag in EmotionTag.allTags {
            if text.contains(tag.tagString) {
                foundTags.append(tag)
            }
        }
        return foundTags
    }
}

