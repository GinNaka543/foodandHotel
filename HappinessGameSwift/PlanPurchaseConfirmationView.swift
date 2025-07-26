import SwiftUI

struct PlanPurchaseConfirmationView: View {
    let plan: VisitPlanModel
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var userPoints: Int = 0
    @State private var isLoadingPoints = true
    @State private var isProcessing = false
    @State private var showingPurchaseSheet = false
    @State private var showStreamingSheet = false
    
    var body: some View {
        
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Text(NSLocalizedString("plan_purchase_confirm", comment: "Plan purchase confirmation"))
                        .font(.system(size: 20, weight: .bold))
                    Spacer()
                    
                    // Watch Anime Button - 常に表示
                    Button(action: {
                        showStreamingSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 14))
                            Text(NSLocalizedString("watch", comment: "Watch"))
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [Color.purple, Color.yellow]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                        )
                    }
                    
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 確認メッセージ
                        VStack(spacing: 16) {
                            Text(NSLocalizedString("confirm_purchase_plan", comment: "Purchase this plan?"))
                                .font(.system(size: 20, weight: .semibold))
                                .multilineTextAlignment(.center)
                        }
                        
                        // プランサムネイル
                        if let thumbnailUrl = plan.thumbnailUrl,
                           let url = URL(string: thumbnailUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 160)
                                    .clipped()
                                    .cornerRadius(12)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                    .frame(height: 160)
                                    .cornerRadius(12)
                                    .overlay(
                                        ProgressView()
                                    )
                            }
                        }
                        
                        // プラン情報
                        VStack(alignment: .leading, spacing: 12) {
                            Text(NSLocalizedString("plan_name", comment: "Plan name"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            Text(plan.title)
                                .font(.system(size: 18, weight: .semibold))
                            
                            Divider()
                            
                            Text(NSLocalizedString("anime", comment: "Anime"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            Text(plan.animeName)
                                .font(.system(size: 16))
                            
                            Divider()
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(NSLocalizedString("spot_count", comment: "Number of spots"))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    Text(String(format: NSLocalizedString("spots_count_format", comment: "%d spots"), plan.spots.count))
                                        .font(.system(size: 16))
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(NSLocalizedString("duration", comment: "Duration"))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    Text(plan.duration)
                                        .font(.system(size: 16))
                                }
                            }
                            
                            if !plan.description.isEmpty {
                                Divider()
                                
                                Text(NSLocalizedString("description", comment: "Description"))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                Text(plan.description)
                                    .font(.system(size: 16))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // ポイント情報
                        VStack(spacing: 12) {
                            HStack {
                                Text(NSLocalizedString("purchase_fee", comment: "Purchase fee:"))
                                    .font(.system(size: 16))
                                Spacer()
                                Text(String(format: NSLocalizedString("points_format", comment: "%d points"), plan.price))
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.purple)
                            }
                            
                            HStack {
                                Text(NSLocalizedString("current_points", comment: "Current points:"))
                                    .font(.system(size: 16))
                                Spacer()
                                if isLoadingPoints {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Text(String(format: NSLocalizedString("points_format", comment: "%d points"), userPoints))
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            if !isLoadingPoints {
                                HStack {
                                    Text(NSLocalizedString("points_after_purchase", comment: "Points after purchase:"))
                                        .font(.system(size: 16))
                                    Spacer()
                                    Text(String(format: NSLocalizedString("points_format", comment: "%d points"), max(0, userPoints - plan.price)))
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.green)
                                }
                                
                                if userPoints < plan.price {
                                    Text(String(format: NSLocalizedString("points_insufficient", comment: "Points insufficient. %d more points required."), plan.price - userPoints))
                                        .font(.system(size: 14))
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.center)
                                        .padding(.top, 8)
                                }
                            }
                        }
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(12)
                        
                        // 注意事項
                        VStack(alignment: .leading, spacing: 12) {
                            Label(NSLocalizedString("notes", comment: "Notes"), systemImage: "info.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(NSLocalizedString("note_plan_saved_to_original", comment: "• Purchased plans are saved to the Original tab"))
                                Text(String(format: NSLocalizedString("note_points_consumed", comment: "• %d points will be consumed"), plan.price))
                                Text(NSLocalizedString("note_can_edit_after_purchase", comment: "• You can edit or delete the plan after purchase"))
                                Text(NSLocalizedString("note_can_use_multiple_times", comment: "• Purchased plans can be used multiple times"))
                            }
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                }
                
                // 確認ボタン
                VStack(spacing: 12) {
                    if userPoints >= plan.price {
                        // ポイントが足りている場合
                        Button(action: {
                            isProcessing = true
                            onConfirm()
                        }) {
                            HStack {
                                if isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                    Text(NSLocalizedString("purchasing", comment: "Purchasing..."))
                                } else {
                                    Image(systemName: "checkmark.circle")
                                    Text(String(format: NSLocalizedString("purchase_with_points", comment: "Purchase with %d points"), plan.price))
                                }
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isProcessing ? Color.gray : Color.purple)
                            )
                        }
                        .disabled(isProcessing || isLoadingPoints)
                    } else {
                        // ポイントが不足している場合
                        Button(action: {
                            showingPurchaseSheet = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text(NSLocalizedString("purchase_points", comment: "Purchase points"))
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
                        .disabled(isLoadingPoints)
                    }
                    
                    Button(action: onCancel) {
                        Text(NSLocalizedString("cancel", comment: "Cancel"))
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                    }
                    .disabled(isProcessing)
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
        .sheet(isPresented: $showStreamingSheet) {
            StreamingServicesSheet(
                animeName: plan.animeName,
                streamingServices: plan.streamingUrls,
                isPresented: $showStreamingSheet,
                thumbnailUrl: plan.thumbnailUrl
            )
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

struct PlanPurchaseConfirmationView_Previews: PreviewProvider {
    static var previews: some View {
        PlanPurchaseConfirmationView(
            plan: VisitPlanModel(
                id: "preview",
                userId: "admin",
                animeName: "青春ブタ野郎",
                title: "青豚の聖地巡り",
                description: "アニメ青春ブタ野郎の聖地を巡る旅行プラン",
                duration: "4時間30分",
                spots: [],
                thumbnailUrl: "",
                price: 500,
                budget: 500,
                createdDate: Date(),
                startTime: Date(),
                numberOfDays: 1,
                totalCost: 500,
                isPublic: true,
                purchasedBy: [],
                createdAt: Date(),
                updatedAt: Date()
            ),
            onConfirm: {},
            onCancel: {}
        )
    }
}