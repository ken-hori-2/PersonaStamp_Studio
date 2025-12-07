//
//  VoiceModel.swift
//  PersonaStampStudio
//
//  Created on 2025-11-23.
//

import Foundation

struct VoiceModel: Codable, Identifiable {
    let id: String
    let reference_name: String
    let created_at: String
    
    enum CodingKeys: String, CodingKey {
        case id = "model_id"
        case reference_name
        case created_at
    }
}

struct CloneResponse: Codable {
    let model_id: String
    let reference_name: String
    let message: String
}

struct UsageStats: Codable {
    let daily_usage: Int
    let daily_tts: Int
    let daily_clone: Int
    let daily_cost: Double
    let monthly_cost: Double
    let daily_tts_limit: Int
    let daily_clone_limit: Int
    let monthly_cost_limit: Double
}

