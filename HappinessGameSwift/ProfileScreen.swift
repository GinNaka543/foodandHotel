import SwiftUI

struct ProfileScreen: View {
    @State private var userName = NSLocalizedString("user", comment: "User")
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
                        StatCard(title: NSLocalizedString("photos", comment: "Photos"), count: totalPhotos, icon: "photo.fill")
                        StatCard(title: NSLocalizedString("videos", comment: "Videos"), count: totalVideos, icon: "video.fill")
                    }
                    
                    // メニュー項目
                    VStack(spacing: 12) {
                        MenuRow(title: NSLocalizedString("settings", comment: "Settings"), icon: "gear", action: { showingSettings = true })
                        MenuRow(title: NSLocalizedString("help", comment: "Help"), icon: "questionmark.circle", action: {})
                        MenuRow(title: NSLocalizedString("contact", comment: "Contact"), icon: "envelope", action: {})
                        MenuRow(title: NSLocalizedString("privacy_policy", comment: "Privacy Policy"), icon: "hand.raised", action: {})
                        MenuRow(title: NSLocalizedString("terms_of_service", comment: "Terms of Service"), icon: "doc.text", action: {})
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
                            Text(NSLocalizedString("purchase_history", comment: "Purchase history"))
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
                        Text(NSLocalizedString("logout", comment: "Logout"))
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
            .navigationTitle(NSLocalizedString("profile", comment: "Profile"))
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
        UserDefaults.standard.string(forKey: "userId") ?? NSLocalizedString("user_id_not_found", comment: "ID not found")
    }
    
    private var username: String {
        UserDefaults.standard.string(forKey: "username") ?? NSLocalizedString("username_not_set", comment: "Not set")
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
                    
                    Text(NSLocalizedString("important_logout_notice", comment: "Important: Check before logout"))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                }
                .padding(.top, 40)
                .padding(.bottom, 20)
                
                // 警告メッセージ
                VStack(spacing: 16) {
                    Text(NSLocalizedString("save_info_below", comment: "Please save the following information"))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.red)
                    
                    Text(NSLocalizedString("cannot_recover_without_info", comment: "Cannot recover account without this information"))
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
                        Text(NSLocalizedString("user_id", comment: "User ID"))
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
                                    Text(NSLocalizedString(copiedUserId ? "copied" : "copy", comment: "Copy/Copied"))
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
                        Text(NSLocalizedString("username", comment: "Username"))
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
                                    Text(NSLocalizedString(copiedUsername ? "copied" : "copy", comment: "Copy/Copied"))
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
                        Text(NSLocalizedString("take_screenshot_or_memo", comment: "Take screenshot or save to memo"))
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                    }
                    
                    Text(NSLocalizedString("cannot_access_after_logout", comment: "Cannot access account without this info after logout"))
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
                        Text(NSLocalizedString("cancel", comment: "Cancel"))
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
                        Text(NSLocalizedString("logout", comment: "Logout"))
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
                Section(NSLocalizedString("notifications", comment: "Notifications")) {
                    Toggle(NSLocalizedString("push_notifications", comment: "Push notifications"), isOn: $notificationsEnabled)
                    Toggle(NSLocalizedString("new_alerts", comment: "New alerts"), isOn: $notificationsEnabled)
                }
                
                Section(NSLocalizedString("data", comment: "Data")) {
                    Toggle(NSLocalizedString("auto_save", comment: "Auto save"), isOn: $autoSaveEnabled)
                    Toggle(NSLocalizedString("cloud_sync", comment: "Cloud sync"), isOn: $autoSaveEnabled)
                }
                
                Section(NSLocalizedString("display", comment: "Display")) {
                    Toggle(NSLocalizedString("dark_mode", comment: "Dark mode"), isOn: $darkModeEnabled)
                }
                
                Section(NSLocalizedString("purchase_info", comment: "Purchase info")) {
                    Button(action: {
                        showingPurchaseHistory = true
                    }) {
                        HStack {
                            Text(NSLocalizedString("purchase_history", comment: "Purchase history"))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                
                Section(NSLocalizedString("app_info", comment: "App info")) {
                    HStack {
                        Text(NSLocalizedString("version", comment: "Version"))
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("settings", comment: "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("done", comment: "Done")) {
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
                        
                        Text(NSLocalizedString("no_purchase_history", comment: "No purchase history"))
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text(NSLocalizedString("purchase_history_description", comment: "Purchase history description"))
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
            .navigationTitle(NSLocalizedString("purchase_history", comment: "Purchase history"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("done", comment: "Done")) {
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
                        
                        Text(NSLocalizedString("purchase_receipt", comment: "Purchase receipt"))
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(NSLocalizedString("thank_you", comment: "Thank you"))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Receipt Details
                    VStack(spacing: 16) {
                        ReceiptDetailRow(title: NSLocalizedString("receipt_number", comment: "Receipt number"), value: receipt.receiptNumber)
                        ReceiptDetailRow(title: NSLocalizedString("purchase_date", comment: "Purchase date"), value: receipt.formattedDate)
                        ReceiptDetailRow(title: NSLocalizedString("transaction_type", comment: "Transaction type"), value: receipt.transactionType.displayName)
                        ReceiptDetailRow(title: NSLocalizedString("product_name", comment: "Product name"), value: receipt.description)
                        ReceiptDetailRow(title: NSLocalizedString("payment_method", comment: "Payment method"), value: receipt.paymentMethod.displayName)
                        ReceiptDetailRow(title: NSLocalizedString("status", comment: "Status"), value: receipt.status.displayName)
                        
                        Divider()
                        
                        ReceiptDetailRow(title: NSLocalizedString("amount", comment: "Amount"), value: receipt.formattedAmount, isTotal: true)
                        
                        if receipt.points > 0 {
                            ReceiptDetailRow(title: NSLocalizedString("earned_points", comment: "Earned points"), value: String(format: NSLocalizedString("points_format", comment: "Points format"), receipt.points), isHighlight: true)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Footer
                    VStack(spacing: 8) {
                        Text(NSLocalizedString("app_name", comment: "App name"))
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text(NSLocalizedString("electronic_receipt_note", comment: "Electronic receipt note"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom)
                }
                .padding()
            }
            .navigationTitle(NSLocalizedString("receipt", comment: "Receipt"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("done", comment: "Done")) {
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