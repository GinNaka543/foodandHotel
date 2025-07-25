import SwiftUI

struct ProfileScreen: View {
    @State private var userName = "ユーザー"
    @State private var userEmail = "user@example.com"
    @State private var totalPhotos = 0
    @State private var totalVideos = 0
    @State private var showingSettings = false
    @State private var showingLogoutConfirmation = false
    @State private var showingPurchaseHistory = false
    @EnvironmentObject var authManager: AuthenticationManager
    
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
                    
                    // 購入履歴ボタン
                    Button(action: {
                        showingPurchaseHistory = true
                    }) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("購入履歴")
                        }
                        .font(.headline)
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // ログアウトボタン
                    Button(action: {
                        showingLogoutConfirmation = true
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
            .sheet(isPresented: $showingPurchaseHistory) {
                PurchaseHistoryView()
            }
        }
        .fullScreenCover(isPresented: $showingLogoutConfirmation) {
            ProfileLogoutConfirmationView(
                isPresented: $showingLogoutConfirmation,
                onLogout: {
                    authManager.logout()
                }
            )
        }
    }
}

struct ProfileLogoutConfirmationView: View {
    @Binding var isPresented: Bool
    let onLogout: () -> Void
    @State private var copiedUserId = false
    @State private var copiedUsername = false
    
    private var userId: String {
        UserDefaults.standard.string(forKey: "userId") ?? "IDが見つかりません"
    }
    
    private var username: String {
        UserDefaults.standard.string(forKey: "username") ?? "未設定"
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ヘッダー
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("重要：ログアウト前に確認")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                }
                .padding(.top, 40)
                .padding(.bottom, 20)
                
                // 警告メッセージ
                VStack(spacing: 16) {
                    Text("以下の情報を必ず保存してください")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.red)
                    
                    Text("これらの情報がないと、アカウントの復元ができません")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                
                // ユーザー情報
                VStack(spacing: 16) {
                    // ユーザーID
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ユーザーID")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        HStack {
                            Text(userId)
                                .font(.system(size: 16).monospaced())
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            
                            Spacer()
                            
                            Button(action: {
                                UIPasteboard.general.string = userId
                                copiedUserId = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    copiedUserId = false
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: copiedUserId ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 14))
                                    Text(copiedUserId ? "コピー済み" : "コピー")
                                        .font(.system(size: 14))
                                }
                                .foregroundColor(copiedUserId ? .green : .blue)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // ユーザー名
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ユーザー名")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        HStack {
                            Text(username)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: {
                                UIPasteboard.general.string = username
                                copiedUsername = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    copiedUsername = false
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: copiedUsername ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 14))
                                    Text(copiedUsername ? "コピー済み" : "コピー")
                                        .font(.system(size: 14))
                                }
                                .foregroundColor(copiedUsername ? .green : .blue)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
                
                // 注意事項
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        Text("スクリーンショットを撮るか、メモに保存してください")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                    }
                    
                    Text("ログアウト後はこれらの情報がないとアカウントにアクセスできません")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
                
                // ボタン
                HStack(spacing: 16) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("キャンセル")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(25)
                    }
                    
                    Button(action: {
                        isPresented = false
                        onLogout()
                    }) {
                        Text("ログアウト")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.red)
                            .cornerRadius(25)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: 400)
            .background(Color.white)
            .cornerRadius(24)
            .shadow(radius: 30)
            .padding(.horizontal, 20)
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
    @State private var showingPurchaseHistory = false
    
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
                
                Section("購入情報") {
                    Button(action: {
                        showingPurchaseHistory = true
                    }) {
                        HStack {
                            Text("購入履歴")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
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
        .sheet(isPresented: $showingPurchaseHistory) {
            PurchaseHistoryView()
        }
    }
}

// MARK: - Purchase History View
struct PurchaseHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var receiptManager = PurchaseReceiptManager.shared
    @State private var selectedReceipt: PurchaseReceipt?
    @State private var showingReceiptDetail = false
    
    var body: some View {
        NavigationView {
            VStack {
                if receiptManager.receipts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("購入履歴がありません")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("ポイントやプランを購入すると\nこちらに履歴が表示されます")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(receiptManager.receipts) { receipt in
                            PurchaseReceiptRow(receipt: receipt) {
                                selectedReceipt = receipt
                                showingReceiptDetail = true
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("購入履歴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingReceiptDetail) {
            if let receipt = selectedReceipt {
                ReceiptDetailView(receipt: receipt)
            }
        }
    }
}

struct PurchaseReceiptRow: View {
    let receipt: PurchaseReceipt
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(receipt.description)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(receipt.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(receipt.transactionType.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                        
                        Text(receipt.status.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(receipt.formattedAmount)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if receipt.points > 0 {
                        Text("+\(receipt.points)pt")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Receipt Detail View
struct ReceiptDetailView: View {
    let receipt: PurchaseReceipt
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("購入明細書")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("ありがとうございました")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Receipt Details
                    VStack(spacing: 16) {
                        ReceiptDetailRow(title: "明細書番号", value: receipt.receiptNumber)
                        ReceiptDetailRow(title: "購入日時", value: receipt.formattedDate)
                        ReceiptDetailRow(title: "取引種別", value: receipt.transactionType.displayName)
                        ReceiptDetailRow(title: "商品名", value: receipt.description)
                        ReceiptDetailRow(title: "支払方法", value: receipt.paymentMethod.displayName)
                        ReceiptDetailRow(title: "ステータス", value: receipt.status.displayName)
                        
                        Divider()
                        
                        ReceiptDetailRow(title: "金額", value: receipt.formattedAmount, isTotal: true)
                        
                        if receipt.points > 0 {
                            ReceiptDetailRow(title: "獲得ポイント", value: "\(receipt.points)ポイント", isHighlight: true)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Footer
                    VStack(spacing: 8) {
                        Text("アニレコ")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text("この明細書は電子レシートです")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom)
                }
                .padding()
            }
            .navigationTitle("明細書")
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

struct ReceiptDetailRow: View {
    let title: String
    let value: String
    var isTotal: Bool = false
    var isHighlight: Bool = false
    
    var body: some View {
        HStack {
            Text(title)
                .font(isTotal ? .headline : .body)
                .fontWeight(isTotal ? .semibold : .regular)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(isTotal ? .headline : .body)
                .fontWeight(isTotal ? .bold : .medium)
                .foregroundColor(isHighlight ? .green : .primary)
        }
    }
}

#Preview {
    ProfileScreen()
} 