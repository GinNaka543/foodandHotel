import SwiftUI

struct PurchaseHistoryView: View {
    @StateObject private var receiptManager = PurchaseReceiptManager.shared
    @State private var selectedReceipt: PurchaseReceipt?
    @State private var showingReceiptDetail = false
    @State private var selectedFilter: PurchaseReceipt.TransactionType?
    
    var filteredReceipts: [PurchaseReceipt] {
        if let filter = selectedFilter {
            return receiptManager.receipts.filter { $0.transactionType == filter }
        }
        return receiptManager.receipts
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // フィルター
                filterSection
                
                // 購入履歴リスト
                if filteredReceipts.isEmpty {
                    emptyState
                } else {
                    purchaseList
                }
            }
            .navigationTitle("購入履歴")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(item: $selectedReceipt) { receipt in
            ReceiptDetailView(receipt: receipt)
        }
    }
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterChip(
                    title: "すべて",
                    isSelected: selectedFilter == nil,
                    action: { selectedFilter = nil }
                )
                
                ForEach(PurchaseReceipt.TransactionType.allCases, id: \.self) { type in
                    FilterChip(
                        title: type.displayName,
                        isSelected: selectedFilter == type,
                        action: { selectedFilter = type }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(Color(.systemGroupedBackground))
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("購入履歴がありません")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.gray)
            
            Text("ポイントを購入すると履歴が表示されます")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var purchaseList: some View {
        List {
            // 統計情報
            statisticsSection
            
            // 購入履歴
            Section("取引履歴") {
                ForEach(filteredReceipts) { receipt in
                    PurchaseRowView(receipt: receipt) {
                        selectedReceipt = receipt
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .background(Color(.systemGroupedBackground))
    }
    
    private var statisticsSection: some View {
        Section("利用統計") {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("総支払金額")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("¥\(NumberFormatter.localizedString(from: NSNumber(value: receiptManager.getTotalSpent()), number: .decimal))")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("獲得ポイント")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(receiptManager.getTotalPointsPurchased())pt")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                    }
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("取引回数")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(receiptManager.receipts.count)回")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                }
            }
            .padding(.vertical, 8)
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.purple : Color(.systemGray5))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PurchaseRowView: View {
    let receipt: PurchaseReceipt
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // アイコン
                Image(systemName: iconForType(receipt.transactionType))
                    .font(.system(size: 20))
                    .foregroundColor(colorForType(receipt.transactionType))
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(colorForType(receipt.transactionType).opacity(0.1))
                    )
                
                // 詳細
                VStack(alignment: .leading, spacing: 4) {
                    Text(receipt.description)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text(receipt.formattedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(receipt.receiptNumber)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 金額
                VStack(alignment: .trailing, spacing: 4) {
                    Text(receipt.formattedAmount)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if receipt.points > 0 {
                        Text("+\(receipt.points)pt")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func iconForType(_ type: PurchaseReceipt.TransactionType) -> String {
        switch type {
        case .pointPurchase:
            return "plus.circle.fill"
        case .planPurchase:
            return "map.fill"
        case .subscription:
            return "crown.fill"
        }
    }
    
    private func colorForType(_ type: PurchaseReceipt.TransactionType) -> Color {
        switch type {
        case .pointPurchase:
            return .purple
        case .planPurchase:
            return .blue
        case .subscription:
            return .orange
        }
    }
}

#Preview {
    PurchaseHistoryView()
}