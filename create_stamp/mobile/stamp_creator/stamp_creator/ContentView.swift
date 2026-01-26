//
//  ContentView.swift
//  stamp_creator
//
//  メインビュー（タブバー付き）
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 背景除去タブ
            Group {
                if #available(iOS 16.0, *) {
                    NavigationStack {
                        BackgroundRemovalView()
                    }
                } else {
                    NavigationView {
                        BackgroundRemovalView()
                    }
                }
            }
            .tabItem {
                Label("Remove BG", systemImage: "wand.and.stars")
            }
            .tag(0)
            
            // 背景合成タブ
            Group {
                if #available(iOS 16.0, *) {
                    NavigationStack {
                        BackgroundCompositionView()
                    }
                } else {
                    NavigationView {
                        BackgroundCompositionView()
                    }
                }
            }
            .tabItem {
                Label("Compose", systemImage: "square.stack.3d.up")
            }
            .tag(1)
            
            // 画像編集タブ
            Group {
                if #available(iOS 16.0, *) {
                    NavigationStack {
                        ImageEditorView()
                    }
                } else {
                    NavigationView {
                        ImageEditorView()
                    }
                }
            }
            .tabItem {
                Label("Edit Sticker", systemImage: "pencil.tip")
            }
            .tag(2)
            
            // TTSスタンプタブ
            Group {
                if #available(iOS 16.0, *) {
                    NavigationStack {
                        TTSStampView()
                    }
                } else {
                    NavigationView {
                        TTSStampView()
                    }
                }
            }
            .tabItem {
                Label("Audio Sticker", systemImage: "waveform")
            }
            .tag(3)
        }
    }
}

