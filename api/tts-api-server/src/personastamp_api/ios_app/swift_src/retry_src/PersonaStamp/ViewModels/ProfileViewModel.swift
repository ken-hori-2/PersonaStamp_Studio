//
//  ProfileViewModel.swift
//  PersonaStampStudio
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
            errorMessage = "統計の読み込みに失敗しました: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

