import SwiftUI

struct PointPurchaseView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var stripeManager = StripePaymentManager.shared
    @StateObject private var firebaseManager = FirebaseManager.shared
    @State private var selectedPackage: PointPackage?
    @State private var isPurchasing = false
    @State private var showingSuccess = false
    @State private var errorMessage = ""
    @State private var shouldDismissBeforePayment = false
    @State private var showCustomAmount = false
    @State private var customAmount = ""
    
    let onPurchaseComplete: () -> Void
    
    let pointPackages = [
        PointPackage(points: 1000, price: 1000, isPopular: false),
        PointPackage(points: 3000, price: 3000, isPopular: false),
        PointPackage(points: 5000, price: 5000, isPopular: true),
        PointPackage(points: 10000, price: 10000, isPopular: false),
        PointPackage(points: 20000, price: 20000, isPopular: false)
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Text("ポイント購入")
                        .font(.system(size: 20, weight: .bold))
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 説明
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ポイントパッケージを選択")
                                .font(.system(size: 18, weight: .semibold))
                            
                            Text("1円 = 1ポイントでお得にポイントを購入できます。\nポイントはプランの公開や購入に使用できます。")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // ポイントパッケージ
                        LazyVStack(spacing: 12) {
                            // カスタム金額入力
                            Button(action: {
                                showCustomAmount.toggle()
                                if showCustomAmount {
                                    selectedPackage = nil
                                }
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("カスタム金額")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.primary)
                                        
                                        if showCustomAmount {
                                            TextField("金額を入力 (円)", text: $customAmount)
                                                .keyboardType(.numberPad)
                                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                                .onChange(of: customAmount) { newValue in
                                                    if let amount = Int(newValue), amount > 0 {
                                                        selectedPackage = PointPackage(points: amount, price: amount, isPopular: false)
                                                    } else {
                                                        selectedPackage = nil
                                                    }
                                                }
                                        } else {
                                            Text("お好きな金額を入力できます")
                                                .font(.system(size: 16))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: showCustomAmount ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 24))
                                        .foregroundColor(showCustomAmount ? .purple : .gray)
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemBackground))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    showCustomAmount ? Color.purple : Color.gray.opacity(0.3),
                                                    lineWidth: showCustomAmount ? 2 : 1
                                                )
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            ForEach(pointPackages, id: \.points) { package in
                                PointPackageCard(
                                    package: package,
                                    isSelected: selectedPackage?.points == package.points && !showCustomAmount,
                                    onSelect: { 
                                        selectedPackage = package
                                        showCustomAmount = false
                                        customAmount = ""
                                    }
                                )
                            }
                        }
                        
                        // エラーメッセージ
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.system(size: 14))
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding(20)
                }
                
                // 購入ボタン
                VStack(spacing: 16) {
                    if let package = selectedPackage {
                        HStack {
                            Text("合計: ¥\(package.price)")
                                .font(.system(size: 18, weight: .semibold))
                            Spacer()
                            Text("\(package.points)ポイント")
                                .font(.system(size: 16))
                                .foregroundColor(.purple)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Button(action: purchasePoints) {
                        HStack {
                            if isPurchasing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(isPurchasing ? "処理中..." : "購入する")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            selectedPackage != nil && !isPurchasing ? 
                            Color.purple : Color.gray
                        )
                        .cornerRadius(12)
                    }
                    .disabled(selectedPackage == nil || isPurchasing)
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
        }
        .alert("購入完了", isPresented: $showingSuccess) {
            Button("OK") {
                dismiss()
                onPurchaseComplete()
            }
        } message: {
            if let package = selectedPackage {
                Text("\(package.points)ポイントを購入しました！")
            }
        }
    }
    
    private func purchasePoints() {
        guard let package = selectedPackage else { return }
        
        isPurchasing = true
        errorMessage = ""
        
        guard let userId = UserDefaults.standard.string(forKey: "userId"), !userId.isEmpty else {
            errorMessage = "ユーザーIDが見つかりません。再度ログインしてください。"
            isPurchasing = false
            return
        }
        
        // Stripe決済処理
        stripeManager.purchasePoints(userId: userId, package: package) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // ポイントをFirebaseに追加
                    firebaseManager.addPointsToUser(userId: userId, points: package.points, description: "\(package.points)ポイント購入") { pointResult in
                        DispatchQueue.main.async {
                            isPurchasing = false
                            switch pointResult {
                            case .success:
                                showingSuccess = true
                            case .failure(let error):
                                errorMessage = "ポイントの追加に失敗しました: \(error.localizedDescription)"
                            }
                        }
                    }
                case .failure(let error):
                    isPurchasing = false
                    // キャンセルの場合はエラーメッセージを表示しない
                    if (error as NSError).code != 1004 {
                        errorMessage = "決済に失敗しました: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}

struct PointPackageCard: View {
    let package: PointPackage
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(package.points)ポイント")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        
                        if package.isPopular {
                            Text("人気")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange)
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                    }
                    
                    Text("¥\(package.price)")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    
                    Text("1ポイント = ¥\(String(format: "%.0f", package.pricePerPoint))")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .purple : .gray)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color.purple : Color.gray.opacity(0.3),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    PointPurchaseView(onPurchaseComplete: {})
}