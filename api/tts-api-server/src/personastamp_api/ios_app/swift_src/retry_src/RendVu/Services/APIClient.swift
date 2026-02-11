//
//  APIClient.swift
//  RendVu
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
    
    // 共通のURLSession（タイムアウト設定済み）
    private lazy var defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        // Render.comなどのホスティングサービスでは、サーバーがスリープ状態から起動するのに時間がかかることがあるため、タイムアウトを60秒に設定
        configuration.timeoutIntervalForRequest = 60.0
        configuration.timeoutIntervalForResource = 60.0
        return URLSession(configuration: configuration)
    }()
    
    // 長時間処理用のURLSession（音声処理など）
    private lazy var longRunningSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 600.0  // 10分
        configuration.timeoutIntervalForResource = 600.0  // 10分
        return URLSession(configuration: configuration)
    }()
    
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
        request.timeoutInterval = 60.0
        
        let (data, response) = try await defaultSession.data(for: request)
        
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
        request.timeoutInterval = 60.0

        let (data, response) = try await defaultSession.data(for: request)

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
        request.timeoutInterval = 60.0

        let (data, response) = try await defaultSession.data(for: request)

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
        transcription: String? = nil,
        idToken: String
    ) async throws -> CloneResponse {
        let url = URL(string: "\(baseURL)/api/v2/clone")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let audioBase64 = audioData.base64EncodedString()
        var body: [String: Any] = [
            "audio_base64": audioBase64,
            "reference_name": referenceName
        ]
        
        // 文字起こしが提供されている場合は追加
        if let transcription = transcription, !transcription.isEmpty {
            body["transcription"] = transcription
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120.0  // Voice Cloningは少し長めに
        
        let (data, response) = try await defaultSession.data(for: request)
        
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
        request.timeoutInterval = 60.0
        
        let (data, response) = try await defaultSession.data(for: request)
        
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
        request.timeoutInterval = 60.0
        
        let (_, response) = try await defaultSession.data(for: request)
        
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
        request.timeoutInterval = 60.0
        
        let (data, response) = try await defaultSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(UsageStats.self, from: data)
    }
    
    // MARK: - 音声処理（音源分離・無音区間削除）
    
    struct AudioProcessResponse: Codable {
        let output_audio_base64: String
        let vocals_audio_base64: String?
        let message: String
    }
    
    func processAudio(
        audioData: Data,
        separateVocals: Bool = true,
        removeSilence: Bool = true,
        separationModel: String = "htdemucs",
        silenceThresh: Float = -40.0,
        minSilenceLen: Int = 500,
        keepSilence: Int = 200,
        idToken: String
    ) async throws -> AudioProcessResponse {
        let url = URL(string: "\(baseURL)/api/v2/audio/process")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 音源分離処理は時間がかかるため、タイムアウトを延長（10分）
        request.timeoutInterval = 600.0
        
        let audioBase64 = audioData.base64EncodedString()
        let body: [String: Any] = [
            "audio_base64": audioBase64,
            "separate_vocals": separateVocals,
            "remove_silence": removeSilence,
            "separation_model": separationModel,
            "silence_thresh": silenceThresh,
            "min_silence_len": minSilenceLen,
            "keep_silence": keepSilence
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // 音源分離処理は時間がかかるため、長時間処理用のセッションを使用
        let (data, response) = try await longRunningSession.data(for: request)
        
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
        return try decoder.decode(AudioProcessResponse.self, from: data)
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
            // 502エラーの場合は特別なメッセージを返す
            if code == 502 {
                // return "サーバーが一時的に利用できません（502 Bad Gateway）。音源分離処理には時間がかかるため、サーバーのタイムアウトが発生している可能性があります。しばらく待ってから再度お試しください。"
                return "サーバーが一時的に利用できません（502 Bad Gateway）。サーバーのタイムアウトが発生している可能性があります。しばらく待ってから再度お試しください。"
            } else if code == 503 {
                // return "サーバーが一時的に過負荷です（503 Service Unavailable）。\n\n音源分離処理は非常に重い処理のため、Render.comの無料プラン（512MB RAM、0.1 CPU）では処理できない可能性があります。\n\n対処方法：\n・音源分離を無効にして、無音区間削除のみを試す\n・Render.comの有料プラン（Standardプラン推奨：2GB RAM、1 CPU）にアップグレード\n・しばらく待ってから再度お試しください"
                return "サーバーが一時的に過負荷です（503 Service Unavailable）。しばらく待ってから再度お試しください"
            } else if code == 504 {
                // return "サーバーの処理がタイムアウトしました（504 Gateway Timeout）。音源分離処理には時間がかかるため、もう一度お試しください。"
                return "サーバーの処理がタイムアウトしました（504 Gateway Timeout）。もう一度お試しください。"
            }
            return "HTTPエラー: \(code)"
        case .serverError(let message):
            return message
        }
    }
}

