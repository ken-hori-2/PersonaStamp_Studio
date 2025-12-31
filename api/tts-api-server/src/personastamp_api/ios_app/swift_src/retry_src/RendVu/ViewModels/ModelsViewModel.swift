//
//  ModelsViewModel.swift
//  RendVu
//
//  Created on 2025-11-23.
//

import Foundation
import Combine

@MainActor
class ModelsViewModel: ObservableObject {
    @Published var models: [VoiceModel] = []
    @Published var errorMessage: String?
    
    func loadModels(authManager: AuthManager) async {
        guard let idToken = authManager.idToken else {
            errorMessage = "認証トークンが見つかりません"
            return
        }
        
        do {
            models = try await APIClient.shared.getVoiceModels(idToken: idToken)
        } catch {
            errorMessage = "モデルの読み込みに失敗しました: \(error.localizedDescription)"
        }
    }
    
    func deleteModel(modelId: String, authManager: AuthManager) async {
        guard let idToken = authManager.idToken else {
            errorMessage = "認証トークンが見つかりません"
            return
        }
        
        do {
            try await APIClient.shared.deleteVoiceModel(modelId: modelId, idToken: idToken)
            // リストから削除
            models.removeAll { $0.id == modelId }
        } catch {
            errorMessage = "モデルの削除に失敗しました: \(error.localizedDescription)"
        }
    }
}

