//
//  ProfileView.swift
//  RendVu
//
//  Created on 2025-11-23.
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = ProfileViewModel()
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("ユーザー情報")) {
                    if let user = authManager.currentUser {
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(user.email ?? "未設定")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("User ID")
                            Spacer()
                            Text(user.uid)
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                
                Section(header: Text("利用統計")) {
                    if let stats = viewModel.stats {
                        HStack {
                            Text("今日のTTS")
                            Spacer()
                            Text("\(stats.daily_tts) / \(stats.daily_tts_limit)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("今日のClone")
                            Spacer()
                            Text("\(stats.daily_clone) / \(stats.daily_clone_limit)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("今日のコスト")
                            Spacer()
                            Text("¥\(String(format: "%.2f", stats.daily_cost))")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("今月のコスト")
                            Spacer()
                            Text("¥\(String(format: "%.2f", stats.monthly_cost)) / ¥\(String(format: "%.0f", stats.monthly_cost_limit))")
                                .foregroundColor(.secondary)
                        }
                    } else if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        authManager.signOut()
                    } label: {
                        HStack {
                            Spacer()
                            Text("ログアウト")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .onAppear {
                Task {
                    await viewModel.loadStats(authManager: authManager)
                }
            }
            .refreshable {
                await viewModel.loadStats(authManager: authManager)
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
}

