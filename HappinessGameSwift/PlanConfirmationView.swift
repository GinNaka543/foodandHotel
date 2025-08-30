import SwiftUI

struct PlanConfirmationView: View {
    let planTitle: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let onPurchasePoints: () -> Void
    
    @State private var userPoints: Int = 0
    @State private var isLoading = true
    @StateObject private var firebaseManager = FirebaseManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Text(NSLocalizedString("plan_confirmation_title", comment: "Plan confirmation"))
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
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // プラン名表示
                            VStack(alignment: .leading, spacing: 8) {
                                Text(NSLocalizedString("plan_name_label", comment: "Plan name"))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                Text(planTitle)
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            
                            // 支払い情報
                            VStack(spacing: 16) {
                                HStack {
                                    Image(systemName: "star.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.orange)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(NSLocalizedString("points_required_for_plan", comment: "Points required for plan"))
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                        Text(String(format: NSLocalizedString("points_unit", comment: "Points unit"), 50))
                                            .font(.system(size: 24, weight: .bold))
                                    }
                                    
                                    Spacer()
                                }
                                
                                Divider()
                                
                                // 現在のポイント残高
                                HStack {
                                    Text(NSLocalizedString("current_points_balance", comment: "Current points balance"))
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text(String(format: NSLocalizedString("points_unit", comment: "Points unit"), userPoints))
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(userPoints >= 50 ? .primary : .red)
                                }
                                
                                // 支払い後の残高
                                if userPoints >= 50 {
                                    HStack {
                                        Text(NSLocalizedString("balance_after_payment", comment: "Balance after payment"))
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                        Spacer()
                                        Text(String(format: NSLocalizedString("points_unit", comment: "Points unit"), userPoints - 50))
                                            .font(.system(size: 16))
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            
                            // ポイント不足の警告
                            if userPoints < 50 {
                                VStack(spacing: 12) {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text(NSLocalizedString("points_insufficient_warning", comment: "Insufficient points"))
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.orange)
                                    }
                                    
                                    Text(String(format: NSLocalizedString("points_needed_message", comment: "Points needed message"), 50 - userPoints))
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                            }
                            
                            // 説明テキスト
                            VStack(alignment: .leading, spacing: 8) {
                                Label(NSLocalizedString("plan_confirm_description_1", comment: "Plan confirm description 1"), systemImage: "checkmark.circle")
                                Label(NSLocalizedString("plan_confirm_description_2", comment: "Plan confirm description 2"), systemImage: "lock")
                                Label(NSLocalizedString("plan_confirm_description_3", comment: "Plan confirm description 3"), systemImage: "folder")
                            }
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
                
                // ボタン
                VStack(spacing: 12) {
                    if userPoints >= 50 {
                        Button(action: onConfirm) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text(String(format: NSLocalizedString("pay_and_confirm_button", comment: "Pay and confirm"), 50))
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                    } else {
                        Button(action: onPurchasePoints) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text(NSLocalizedString("purchase_points_button", comment: "Purchase points"))
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.orange)
                            .cornerRadius(12)
                        }
                    }
                    
                    Button(action: onCancel) {
                        Text(NSLocalizedString("cancel", comment: "Cancel"))
                            .font(.system(size: 17))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .background(Color(.systemBackground))
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            loadUserPoints()
        }
    }
    
    private func loadUserPoints() {
        let userId = UserDefaults.standard.string(forKey: "userId") ?? ""
        
        // ローカルからポイントを取得
        DispatchQueue.main.async {
            let points = UserDefaults.standard.integer(forKey: "userPoints_\(userId)")
            self.userPoints = points
            self.isLoading = false
        }
    }
}
