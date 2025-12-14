//
//  EmotionPickerView.swift
//  RendVu
//
//  Created on 2025-01-XX.
//

import SwiftUI

struct EmotionPickerView: View {
    @Binding var selectedTag: EmotionTag?
    @Binding var text: String
    @Binding var isPresented: Bool
    @State private var cursorPosition: Int = 0
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("感情タグを選択")) {
                    ForEach(EmotionTag.allTags) { tag in
                        Button(action: {
                            insertTag(tag)
                            // タグを挿入したらシートを閉じる
                            isPresented = false
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(tag.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(tag.tagString)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(6)
                                }
                                
                                Text(tag.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text(tag.example)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .italic()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Section(header: Text("使い方")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• 感情タグを選択すると、テキストの末尾に挿入されます")
                        Text("• タグはテキスト内の任意の位置に手動で移動できます")
                        Text("• 複数の感情タグを組み合わせて使用できます")
                        Text("• タグの直後にスペースを入れて、その後にテキストを入力してください")
                        Text("• 例: (happy) こんにちは！(excited) 今日は良い天気ですね！")
                        Text("")
                        Text("⚠️ 注意: タグ名が読み上げられる場合は、タグの直後にスペースを入れてください")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("感情タグ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func insertTag(_ tag: EmotionTag) {
        // テキストの末尾に挿入
        let tagString = tag.tagString + " "
        if text.isEmpty {
            text = tagString
        } else {
            text = text + (text.hasSuffix(" ") ? "" : " ") + tagString
        }
    }
}

#Preview {
    EmotionPickerView(
        selectedTag: .constant(nil),
        text: .constant(""),
        isPresented: .constant(true)
    )
}

