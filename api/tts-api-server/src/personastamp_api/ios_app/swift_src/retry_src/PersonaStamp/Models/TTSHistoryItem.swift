//
//  TTSHistoryItem.swift
//  PersonaStamp
//
//  Created on 2025-11-24.
//

import Foundation

struct TTSHistoryItem: Codable, Identifiable {
    let id: Int
    let text: String
    let model_id: String?
    let format: String
    let file_name: String
    let size_bytes: Int?
    let created_at: String
}



