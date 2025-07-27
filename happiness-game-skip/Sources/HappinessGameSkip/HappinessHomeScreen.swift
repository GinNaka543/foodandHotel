import SwiftUI
import Foundation

// Simplified version of HomeScreen for Skip compatibility
struct HappinessHomeScreen: View {
    @State internal var selectedListTab: Int = 0
    @State internal var showCharacterList = false
    @State internal var showAnimeList = false
    @State internal var showBirthdayList = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack {
                Text("幸せゲーム")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("あなたの幸せを管理しよう")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            // Main buttons
            VStack(spacing: 16) {
                Button(action: {
                    showCharacterList = true
                }) {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                        Text("キャラクター")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(10)
                }
                
                Button(action: {
                    showAnimeList = true
                }) {
                    HStack {
                        Image(systemName: "tv.fill")
                            .foregroundColor(.green)
                        Text("アニメ")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(10)
                }
                
                Button(action: {
                    showBirthdayList = true
                }) {
                    HStack {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .foregroundColor(.orange)
                        Text("誕生日リマインダー")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Footer
            Text("Skip対応版")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
        }
        .navigationTitle("ホーム")
        .sheet(isPresented: $showCharacterList) {
            NavigationStack {
                Text("キャラクターリスト（準備中）")
                    .navigationTitle("キャラクター")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button("閉じる") {
                                showCharacterList = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showAnimeList) {
            NavigationStack {
                Text("アニメリスト（準備中）")
                    .navigationTitle("アニメ")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button("閉じる") {
                                showAnimeList = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showBirthdayList) {
            NavigationStack {
                Text("誕生日リマインダー（準備中）")
                    .navigationTitle("誕生日")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button("閉じる") {
                                showBirthdayList = false
                            }
                        }
                    }
            }
        }
    }
}