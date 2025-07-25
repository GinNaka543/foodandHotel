import SwiftUI

struct ReceiptDetailView: View {
    let receipt: PurchaseReceipt
    @Environment(\.dismiss) var dismiss
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // ヘッダー
                    receiptHeader
                    
                    // 明細書本文
                    receiptContent
                    
                    // アクションボタン
                    actionButtons
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("購入明細書")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [generateReceiptText()])
        }
    }
    
    private var receiptHeader: some View {
        VStack(spacing: 16) {
            // アプリアイコン・タイトル
            VStack(spacing: 8) {
                Image(systemName: "app.badge")
                    .font(.system(size: 50))
                    .foregroundColor(.purple)
                
                Text("アニレコ")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("購入明細書")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            // 明細書番号・日付
            VStack(spacing: 8) {
                HStack {
                    Text("明細書番号:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(receipt.receiptNumber)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("発行日時:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(receipt.formattedDate)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private var receiptContent: some View {
        VStack(spacing: 20) {
            // 取引詳細
            transactionDetails
            
            // 料金明細
            paymentBreakdown
            
            // 会社情報
            companyInfo
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private var transactionDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("取引詳細")
                .font(.headline)
                .fontWeight(.bold)
            
            Divider()
            
            DetailRow(label: "取引種別", value: receipt.transactionType.displayName)
            DetailRow(label: "商品名", value: receipt.description)
            DetailRow(label: "決済方法", value: receipt.paymentMethod.displayName)
            DetailRow(label: "取引状況", value: receipt.status.displayName)
            
            if receipt.points > 0 {
                DetailRow(label: "獲得ポイント", value: "\(receipt.points) ポイント")
            }
        }
    }
    
    private var paymentBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("料金明細")
                .font(.headline)
                .fontWeight(.bold)
            
            Divider()
            
            if receipt.transactionType == .pointPurchase {
                DetailRow(label: "ポイント購入", value: receipt.formattedAmount)
                DetailRow(label: "消費税", value: "¥0")
            } else {
                DetailRow(label: "商品代金", value: receipt.formattedAmount)
            }
            
            Divider()
            
            HStack {
                Text("合計金額")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Text(receipt.formattedAmount)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.purple)
            }
        }
    }
    
    private var companyInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("販売事業者")
                .font(.headline)
                .fontWeight(.bold)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("アニレコ運営事務局")
                    .font(.body)
                
                Text("お問い合わせ: support@anireco.app")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("本明細書は電子データとして発行されています")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: { showingShareSheet = true }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("明細書を共有")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.purple)
                .cornerRadius(12)
            }
            
            Button(action: { dismiss() }) {
                Text("閉じる")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.purple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(12)
            }
        }
    }
    
    private func generateReceiptText() -> String {
        return """
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        　　　　　　　　　　　　　アニレコ　購入明細書
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        明細書番号: \(receipt.receiptNumber)
        発行日時: \(receipt.formattedDate)
        
        ■ 取引詳細
        取引種別: \(receipt.transactionType.displayName)
        商品名: \(receipt.description)
        決済方法: \(receipt.paymentMethod.displayName)
        取引状況: \(receipt.status.displayName)
        \(receipt.points > 0 ? "獲得ポイント: \(receipt.points) ポイント" : "")
        
        ■ 料金明細
        \(receipt.transactionType == .pointPurchase ? "ポイント購入" : "商品代金"): \(receipt.formattedAmount)
        消費税: ¥0
        ────────────────────────────────────────────────
        合計金額: \(receipt.formattedAmount)
        
        ■ 販売事業者
        アニレコ運営事務局
        お問い合わせ: support@anireco.app
        
        ※本明細書は電子データとして発行されています
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ReceiptDetailView(receipt: PurchaseReceipt(
        transactionType: .pointPurchase,
        amount: 1000,
        points: 1000,
        paymentMethod: .creditCard,
        description: "1000ポイント購入"
    ))
}