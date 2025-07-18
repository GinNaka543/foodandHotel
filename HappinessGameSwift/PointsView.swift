import SwiftUI

struct PointsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var firebaseManager = FirebaseManager.shared
    @StateObject private var stripeManager = StripePaymentManager.shared
    @State private var userPoints: UserPointsModel?
    @State private var pointTransactions: [PointTransactionModel] = []
    @State private var showingPurchaseSheet = false
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var userId: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                ZStack {
                    Text("ポイント")
                        .font(.system(size: 24, weight: .bold))
                    
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                                .frame(width: 30, height: 30)
                        }
                        
                        Spacer()
                        
                        Button(action: { showingPurchaseSheet = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                Text("購入")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.purple)
                            .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                if isLoading {
                    Spacer()
                    ProgressView("読み込み中...")
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // ポイント残高カード
                            VStack(spacing: 16) {
                                HStack {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                        .font(.system(size: 24))
                                    Text("現在のポイント")
                                        .font(.system(size: 18, weight: .semibold))
                                    Spacer()
                                }
                                
                                HStack {
                                    Text("\(userPoints?.points ?? 0)")
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(.purple)
                                    Text("ポイント")
                                        .font(.system(size: 18))
                                        .foregroundColor(.gray)
                                    Spacer()
                                }
                            }
                            .padding(20)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                            )
                            
                            // ポイント使用ガイド
                            VStack(alignment: .leading, spacing: 12) {
                                Text("ポイントの使い方")
                                    .font(.system(size: 18, weight: .semibold))
                                
                                VStack(spacing: 8) {
                                    PointUsageRow(icon: "map", title: "プラン作成", points: "50ポイント", description: "オリジナルの旅行プランを作成")
                                    PointUsageRow(icon: "doc.text", title: "プラン購入", points: "設定価格", description: "他のユーザーのプランを購入")
                                }
                            }
                            .padding(20)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            
                            // 取引履歴
                            if !pointTransactions.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("取引履歴")
                                        .font(.system(size: 18, weight: .semibold))
                                    
                                    LazyVStack(spacing: 8) {
                                        ForEach(pointTransactions.prefix(10), id: \.id) { transaction in
                                            TransactionRow(transaction: transaction)
                                        }
                                    }
                                }
                                .padding(20)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
                            }
                        }
                        .padding(20)
                    }
                }
                
                if !errorMessage.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        if userId.isEmpty {
                            Text("ユーザーID: 未設定")
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                        } else {
                            Text("ユーザーID: \(userId)")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .onAppear {
            // UserDefaultsからユーザーIDを取得
            if let storedUserId = UserDefaults.standard.string(forKey: "userId"), !storedUserId.isEmpty {
                userId = storedUserId
                print("✅ ポイントビュー: userId=\(userId)")
                loadUserPoints()
            } else {
                errorMessage = "ログインが必要です"
                isLoading = false
            }
        }
        .sheet(isPresented: $showingPurchaseSheet) {
            PointPurchaseView(
                onPurchaseComplete: {
                    loadUserPoints()
                }
            )
        }
    }
    
    private func loadUserPoints() {
        guard !userId.isEmpty else {
            errorMessage = "ユーザーIDが見つかりません"
            isLoading = false
            return
        }
        
        isLoading = true
        
        // ポイント残高を取得
        firebaseManager.getUserPoints(userId: userId) { result in
            switch result {
            case .success(let points):
                userPoints = points
            case .failure(let error):
                errorMessage = "ポイント情報の取得に失敗しました: \(error.localizedDescription)"
            }
        }
        
        // 取引履歴を取得
        firebaseManager.getPointTransactions(userId: userId) { result in
            switch result {
            case .success(let transactions):
                pointTransactions = transactions.sorted { $0.createdAt > $1.createdAt }
            case .failure(let error):
                print("取引履歴の取得に失敗: \(error)")
            }
            isLoading = false
        }
    }
}

struct PointUsageRow: View {
    let icon: String
    let title: String
    let points: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .font(.system(size: 20))
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text(points)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.purple)
        }
        .padding(.vertical, 8)
    }
}

struct TransactionRow: View {
    let transaction: PointTransactionModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.system(size: 16, weight: .medium))
                Text(formatDate(transaction.createdAt))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Text(transaction.amount > 0 ? "+\(transaction.amount)" : "\(transaction.amount)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(transaction.amount > 0 ? .green : .red)
                Text("pt")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    PointsView()
}