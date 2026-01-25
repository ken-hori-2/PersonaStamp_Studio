//
//  TextEditorView.swift
//  stamp_creator
//
//  テキストエディタビュー
//

import SwiftUI

struct TextEditorView: View {
    @Binding var textLayer: TextLayer
    let imageFrame: CGRect
    @Environment(\.dismiss) var dismiss
    @State private var text: String
    @State private var selectedFont: FontOption
    @State private var fontSize: CGFloat
    @State private var textColor: Color
    @State private var backgroundColor: Color?
    
    init(textLayer: Binding<TextLayer>, imageFrame: CGRect) {
        self._textLayer = textLayer
        self.imageFrame = imageFrame
        _text = State(initialValue: textLayer.wrappedValue.text)
        _fontSize = State(initialValue: textLayer.wrappedValue.fontSize)
        _textColor = State(initialValue: Color(textLayer.wrappedValue.textColor))
        _backgroundColor = State(initialValue: textLayer.wrappedValue.backgroundColor != nil ? Color(textLayer.wrappedValue.backgroundColor!) : nil)
        
        // フォント選択の初期値
        let currentFontName = textLayer.wrappedValue.fontName
        _selectedFont = State(initialValue: FontOption.availableFonts.first { $0.fontName == currentFontName } ?? FontOption.availableFonts[0])
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Text")) {
                    TextField("Enter text", text: $text)
                        .onChange(of: text) { _, newValue in
                            textLayer.text = newValue
                        }
                }
                
                Section(header: Text("Font")) {
                    Picker("Font", selection: $selectedFont) {
                        ForEach(FontOption.availableFonts) { font in
                            Text(font.displayName).tag(font)
                        }
                    }
                    .onChange(of: selectedFont) { _, newValue in
                        textLayer.fontName = newValue.fontName
                    }
                    
                    Stepper("サイズ: \(Int(fontSize))", value: $fontSize, in: 12...200, step: 1)
                        .onChange(of: fontSize) { _, newValue in
                            textLayer.fontSize = newValue
                        }
                }
                
                Section(header: Text("Color")) {
                    ColorPicker("Text color", selection: $textColor)
                        .onChange(of: textColor) { _, newValue in
                            textLayer.textColor = UIColor(newValue)
                        }
                    
                    Toggle("Add background color", isOn: Binding(
                        get: { backgroundColor != nil },
                        set: { enabled in
                            if enabled {
                                backgroundColor = Color.white.opacity(0.5)
                                textLayer.backgroundColor = UIColor.white.withAlphaComponent(0.5)
                            } else {
                                backgroundColor = nil
                                textLayer.backgroundColor = nil
                            }
                        }
                    ))
                    
                    if backgroundColor != nil {
                        ColorPicker("背景色", selection: Binding(
                            get: { backgroundColor ?? .white },
                            set: { newValue in
                                backgroundColor = newValue
                                textLayer.backgroundColor = UIColor(newValue)
                            }
                        ))
                    }
                }
            }
            .navigationTitle("Edit Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
