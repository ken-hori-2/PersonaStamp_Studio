//
//  ModelsView.swift
//  RendVu
//
//  Created on 2025-11-23.
//

import SwiftUI

struct ModelsView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = ModelsViewModel()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.models) { model in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.reference_name)
                            .font(.headline)
                        Text("ID: \(model.id)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("作成日: \(formatDate(model.created_at))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.deleteModel(modelId: model.id, authManager: authManager)
                            }
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Voice Models")
            .refreshable {
                await viewModel.loadModels(authManager: authManager)
            }
            .onAppear {
                Task {
                    await viewModel.loadModels(authManager: authManager)
                }
            }
            .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

#Preview {
    ModelsView()
        .environmentObject(AuthManager())
}

