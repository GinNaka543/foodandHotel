import SwiftUI

struct PublishPlanDialog: View {
    let planTitle: String
    @Binding var planDescription: String
    @Binding var planPrice: Int
    @Binding var planBudget: Int
    let onPublish: () -> Void
    let onCancel: () -> Void
    
    @State private var showingPaymentInfo = false
    @State private var userPoints: Int = 0
    @State private var isLoadingPoints = true
    @State private var showingPurchaseSheet = false
    @State private var errorMessage = ""
    @State private var showingCurrencyPicker = false
    @StateObject private var currencyManager = CurrencyManager.shared
    
    private let publicationCost = 5000 // 5,000ポイント
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Text(NSLocalizedString("plan_publish", comment: "Publish Plan"))
                        .font(.system(size: 20, weight: .bold))
                    Spacer()
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // 公開料金の説明
                        VStack(alignment: .leading, spacing: 12) {
                            Label(NSLocalizedString("plan_publish_fee", comment: "Plan Publication Fee"), systemImage: "dollarsign.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.purple)
                            
                            Text(NSLocalizedString("plan_publish_fee_description", comment: "5,000 points required to publish plan"))
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            VStack(spacing: 12) {
                                HStack {
                                    Text(NSLocalizedString("publication_fee", comment: "Publication fee:"))
                                        .font(.system(size: 14))
                                    Spacer()
                                    Text(NSLocalizedString("points_5000", comment: "5,000 points"))
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.purple)
                                }
                                .padding()
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(12)
                                
                                // 現在のポイント表示
                                HStack {
                                    Text(NSLocalizedString("current_points", comment: "Current points:"))
                                        .font(.system(size: 14))
                                    Spacer()
                                    if isLoadingPoints {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Text(String(format: NSLocalizedString("points_format", comment: "%d points"), userPoints))
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(userPoints >= publicationCost ? .green : .red)
                                    }
                                }
                                
                                if !isLoadingPoints && userPoints < publicationCost {
                                    Text(String(format: NSLocalizedString("points_insufficient", comment: "Points insufficient. %d more points needed."), publicationCost - userPoints))
                                        .font(.system(size: 12))
                                        .foregroundColor(.red)
                                        .padding(.top, 4)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // プラン情報
                        VStack(alignment: .leading, spacing: 16) {
                            Text(NSLocalizedString("plan_info", comment: "Plan Information"))
                                .font(.system(size: 18, weight: .semibold))
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(NSLocalizedString("title", comment: "Title"))
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                Text(planTitle)
                                    .font(.system(size: 16))
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(NSLocalizedString("plan_description", comment: "Plan Description"))
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                TextField(NSLocalizedString("plan_description_placeholder", comment: "Describe the appeal of this plan"), text: $planDescription, axis: .vertical)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .lineLimit(3...6)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(NSLocalizedString("sales_price", comment: "Sales Price"))
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                HStack {
                                    TextField("0", value: $planPrice, format: .number)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .frame(width: 120)
                                        .keyboardType(.numberPad)
                                    
                                    Button(action: { showingCurrencyPicker = true }) {
                                        HStack(spacing: 4) {
                                            Text(currencyManager.getCurrencyFlag())
                                                .font(.system(size: 16))
                                            Text(currencyManager.currencyCode)
                                                .font(.system(size: 16, weight: .medium))
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 12))
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                    
                                    Spacer()
                                }
                                Text(NSLocalizedString("free_plan_note", comment: "* Setting to 0 makes it a free plan"))
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(NSLocalizedString("budget", comment: "Budget"))
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                HStack {
                                    TextField("0", value: $planBudget, format: .number)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .frame(width: 120)
                                        .keyboardType(.numberPad)
                                    
                                    // Display current currency (same as price field)
                                    HStack(spacing: 4) {
                                        Text(currencyManager.getCurrencyFlag())
                                            .font(.system(size: 16))
                                        Text(currencyManager.currencyCode)
                                            .font(.system(size: 16, weight: .medium))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.gray.opacity(0.05))
                                    .cornerRadius(8)
                                    
                                    Spacer()
                                }
                                Text(NSLocalizedString("budget_note", comment: "* Please enter the approximate budget for this plan (required)"))
                                    .font(.system(size: 12))
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Divider()
                        
                        // 注意事項
                        VStack(alignment: .leading, spacing: 12) {
                            Label(NSLocalizedString("notes", comment: "Notes"), systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(NSLocalizedString("note_no_edit_after_publish", comment: "• Cannot edit or delete plan after publication"))
                                Text(NSLocalizedString("note_receive_sales_price", comment: "• You can receive sales price when other users purchase the plan"))
                                Text(NSLocalizedString("note_inappropriate_content", comment: "• Inappropriate content may be deleted"))
                            }
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                
                // 公開ボタン
                VStack(spacing: 12) {
                    if userPoints >= publicationCost {
                        // ポイントが足りている場合
                        Button(action: {
                            if planBudget <= 0 {
                                errorMessage = NSLocalizedString("error_budget_required", comment: "Please enter budget")
                                return
                            }
                            onPublish()
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                Text(NSLocalizedString("publish_with_5000_points", comment: "Publish with 5,000 points"))
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.purple)
                            )
                        }
                        .disabled(planBudget <= 0)
                    } else {
                        // ポイントが不足している場合
                        Button(action: {
                            showingPurchaseSheet = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text(NSLocalizedString("purchase_points", comment: "Purchase Points"))
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.orange)
                            )
                        }
                    }
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            loadUserPoints()
        }
        .sheet(isPresented: $showingPurchaseSheet) {
            PointPurchaseView(
                onPurchaseComplete: {
                    loadUserPoints()
                }
            )
        }
        .sheet(isPresented: $showingCurrencyPicker) {
            CurrencyPickerView(isPresented: $showingCurrencyPicker)
        }
    }
    
    private func loadUserPoints() {
        guard let userId = UserDefaults.standard.string(forKey: "userId"), !userId.isEmpty else {
            isLoadingPoints = false
            return
        }
        
        FirebaseManager.shared.getUserPoints(userId: userId) { result in
            DispatchQueue.main.async {
                isLoadingPoints = false
                switch result {
                case .success(let pointsModel):
                    userPoints = pointsModel.points
                case .failure(let error):
                    userPoints = 0
                }
            }
        }
    }
}