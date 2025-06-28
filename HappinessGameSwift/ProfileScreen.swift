import SwiftUI

struct ProfileScreen: View {
    @State private var userName = "ユーザー"
    @State private var userEmail = "user@example.com"
    @State private var totalPhotos = 0
    @State private var totalVideos = 0
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // プロフィールヘッダー
                    VStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.orange)
                        
                        VStack(spacing: 4) {
                            Text(userName)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(userEmail)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    
                    // 統計情報
                    HStack(spacing: 16) {
                        StatCard(title: "写真", count: totalPhotos, icon: "photo.fill")
                        StatCard(title: "動画", count: totalVideos, icon: "video.fill")
                    }
                    
                    // メニュー項目
                    VStack(spacing: 12) {
                        MenuRow(title: "設定", icon: "gear", action: { showingSettings = true })
                        MenuRow(title: "ヘルプ", icon: "questionmark.circle", action: {})
                        MenuRow(title: "お問い合わせ", icon: "envelope", action: {})
                        MenuRow(title: "プライバシーポリシー", icon: "hand.raised", action: {})
                        MenuRow(title: "利用規約", icon: "doc.text", action: {})
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    
                    // ログアウトボタン
                    Button(action: {
                        // ログアウト処理
                    }) {
                        Text("ログアウト")
                            .font(.headline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .background(Color.orange.opacity(0.1))
            .navigationTitle("プロフィール")
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let count: Int
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.orange)
            
            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct MenuRow: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.orange)
                    .frame(width: 24)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notificationsEnabled = true
    @State private var autoSaveEnabled = true
    @State private var darkModeEnabled = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("通知") {
                    Toggle("プッシュ通知", isOn: $notificationsEnabled)
                    Toggle("新着アラート", isOn: $notificationsEnabled)
                }
                
                Section("データ") {
                    Toggle("自動保存", isOn: $autoSaveEnabled)
                    Toggle("クラウド同期", isOn: $autoSaveEnabled)
                }
                
                Section("表示") {
                    Toggle("ダークモード", isOn: $darkModeEnabled)
                }
                
                Section("アプリ情報") {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileScreen()
} 