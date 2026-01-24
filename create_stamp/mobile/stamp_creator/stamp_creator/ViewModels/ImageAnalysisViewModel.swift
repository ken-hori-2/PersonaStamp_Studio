//
//  ImageAnalysisViewModel.swift
//  stamp_creator
//
//  ImageAnalysisのロジックを管理するViewModel
//

import SwiftUI
import VisionKit
import Combine

class ImageAnalysisViewModel: ObservableObject {
    let analyzer = ImageAnalyzer()
    let interaction = ImageAnalysisInteraction()
    
    @Published var isAnalyzing = false
    @Published var detectedSubjects: Set<ImageAnalysisInteraction.Subject> = []
    
    @MainActor
    func analyzeImage(_ image: UIImage) async throws {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        let configuration = ImageAnalyzer.Configuration([.visualLookUp])
        let analysis = try await analyzer.analyze(image, configuration: configuration)
        interaction.analysis = analysis
        detectedSubjects = await interaction.subjects
    }
    
    @MainActor
    func extractImage(for subjects: Set<ImageAnalysisInteraction.Subject>) async throws -> UIImage {
        return try await interaction.image(for: subjects)
    }
}
