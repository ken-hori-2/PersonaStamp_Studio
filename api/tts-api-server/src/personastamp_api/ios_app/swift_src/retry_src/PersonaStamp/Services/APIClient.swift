//
//  APIClient.swift
//  PersonaStampStudio
//
//  Created on 2025-11-23.
//

import Foundation

class APIClient {
    static let shared = APIClient()
    
    // 本番環境ではリモートAPIに接続
    #if DEBUG
    // シミュレーターと実機の両方に対応
    #if targetEnvironment(simulator)
    let baseURL = "http://127.0.0.1:8000" // IPv6による::1解決を避ける
    #else
    // 実機用（MacのIPアドレス）
    let baseURL = "http://172.20.10.5:9000"
    #endif
    #else
    let baseURL = "https://personastamp-studio.onrender.com"
    #endif
    
    private init() {}
    
    // MARK: - TTS生成
    
    func generateTTS(
        text: String,
        modelId: String? = nil,
        format: String = "mp3",
        speed: Double = 1.0,
        volume: Int = 0,
        idToken: String
    ) async throws -> Data {
        let url = URL(string: "\(baseURL)/api/v2/tts/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "text": text,
            "format": format,
            "speed": speed,
            "volume": volume
        ]
        if let modelId = modelId {
            body["model_id"] = modelId
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? String {
                throw APIError.serverError(detail)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        return data
    }

    // MARK: - TTS履歴

    func fetchTTSHistory(idToken: String) async throws -> [TTSHistoryItem] {
        let url = URL(string: "\(baseURL)/api/v2/tts/history")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode([TTSHistoryItem].self, from: data)
    }

    func downloadTTSHistory(
        historyId: Int,
        idToken: String
    ) async throws -> Data {
        let url = URL(string: "\(baseURL)/api/v2/tts/history/\(historyId)/download")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode)
        }

        return data
    }
    
    // MARK: - Voice Cloning
    
    func cloneVoice(
        audioData: Data,
        referenceName: String,
        idToken: String
    ) async throws -> CloneResponse {
        let url = URL(string: "\(baseURL)/api/v2/clone")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let audioBase64 = audioData.base64EncodedString()
        let body: [String: Any] = [
            "audio_base64": audioBase64,
            "reference_name": referenceName
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? String {
                throw APIError.serverError(detail)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(CloneResponse.self, from: data)
    }
    
    // MARK: - モデル一覧取得
    
    func getVoiceModels(idToken: String) async throws -> [VoiceModel] {
        let url = URL(string: "\(baseURL)/api/v2/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([VoiceModel].self, from: data)
    }
    
    // MARK: - モデル削除
    
    func deleteVoiceModel(modelId: String, idToken: String) async throws {
        let url = URL(string: "\(baseURL)/api/v2/models/\(modelId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode)
        }
    }
    
    // MARK: - 利用統計取得
    
    func getUserStats(idToken: String) async throws -> UsageStats {
        let url = URL(string: "\(baseURL)/api/v2/users/me/stats")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(UsageStats.self, from: data)
    }
}

enum APIError: LocalizedError {
    case unauthorized
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "認証が必要です"
        case .invalidResponse:
            return "無効なレスポンスです"
        case .httpError(let code):
            return "HTTPエラー: \(code)"
        case .serverError(let message):
            return message
        }
    }
}

