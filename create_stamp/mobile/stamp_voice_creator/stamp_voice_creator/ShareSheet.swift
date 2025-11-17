//
//  ShareSheet.swift
//  stamp_voice_creator
//
//  Created by 堀内健司 on 2025/11/17.
//

import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: applicationActivities
        )
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // iPad対応: popoverの設定
        if let popover = uiViewController.popoverPresentationController {
            // sourceViewを設定（ウィンドウから取得）
            if let windowScene = uiViewController.view.window?.windowScene,
               let window = windowScene.windows.first {
                popover.sourceView = window
                let screenBounds = windowScene.screen.bounds
                popover.sourceRect = CGRect(
                    x: screenBounds.width / 2,
                    y: screenBounds.height / 2,
                    width: 0,
                    height: 0
                )
            } else {
                // フォールバック: viewから取得
                popover.sourceView = uiViewController.view
                let bounds = uiViewController.view.bounds
                popover.sourceRect = CGRect(
                    x: bounds.width / 2,
                    y: bounds.height / 2,
                    width: 0,
                    height: 0
                )
            }
            popover.permittedArrowDirections = []
        }
    }
}

