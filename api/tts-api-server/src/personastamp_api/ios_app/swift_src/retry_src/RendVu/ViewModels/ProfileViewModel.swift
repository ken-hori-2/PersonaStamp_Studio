//
//  ProfileViewModel.swift
//  RendVu
//
//  Created on 2025-11-23.
//

import Foundation
import Combine

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var stats: UsageStats?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func loadStats(authManager: AuthManager) async {
        guard let idToken = authManager.idToken else {
            errorMessage = "認証トークンが見つかりません"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            stats = try await APIClient.shared.getUserStats(idToken: idToken)
        } catch {
            // タイムアウトエラーの場合は特別なメッセージを表示
            if let urlError = error as? URLError, urlError.code == .timedOut {
                errorMessage = "統計の読み込みがタイムアウトしました。サーバーが起動中かもしれません。もう一度お試しください。"
            } else if let apiError = error as? APIError {
                errorMessage = "統計の読み込みに失敗しました: \(apiError.localizedDescription)"
            } else {
                errorMessage = "統計の読み込みに失敗しました: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
}

