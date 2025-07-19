import SwiftUI
import Foundation
import UIKit
import FirebaseFirestore

// VisitTypes.swiftの型を使用するための明示的なimport

public struct VisitScreen: View {
    @State private var savedPlans: [VisitPlanData] = []
    @State private var selectedPlan: VisitPlanData?
    @State private var visitAds: [Advertisement] = []
    @State private var currentAdIndex = 0
    @State private var adTimer: Timer?
    @StateObject private var firebaseManager = FirebaseManager.shared
    @State private var publicPlans: [VisitPlanModel] = []
    @State private var userOriginalPlans: [VisitPlanModel] = []
    @State private var purchasedPlans: [VisitPlanModel] = []
    @State private var currentUserId: String = UserDefaults.standard.string(forKey: "userId") ?? UUID().uuidString
    @State private var showingDeleteConfirmation = false
    @State private var planToDelete: VisitPlanModel?
    @State private var planToPurchase: VisitPlanModel?
    @State private var showingPurchaseCompletion = false
    @State private var purchasedPlan: VisitPlanModel?
    @State private var selectedPlanForNavigation: VisitPlanModel?
    @State private var showNavigationMenu = false
    @State private var hiddenPlanIds: Set<String> = []
    @State private var selectedDraftPlan: VisitPlanData? = nil
    @State private var isLoadingDraft = false
    @EnvironmentObject var mainTab: MainTabSelection
    
    // タブ用
    enum VisitTab: String, CaseIterable {
        case all = "オール"
        case original = "オリジナル"
        case purchased = "購入済み"
    }
    @State private var selectedTab: VisitTab = .all
    @State private var showSearchBar = true
    @State private var searchText = ""
    @State private var activeSearchText = ""
    @State private var showingPlanningScreen = false
    
    public var body: some View {
        mainContent
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToVisitOriginalTab"))) { _ in
                selectedTab = .original
            }
            .fullScreenCover(isPresented: $showingPlanningScreen, onDismiss: {
                print("🔥 DEBUG: プランニング画面が閉じられました - データを再読み込みします")
                print("🔥 DEBUG: selectedTab: \(selectedTab.rawValue)")
                selectedDraftPlan = nil // クリア
                loadSavedPlans()
                loadFirebasePlans()
                
                // タブごとのプラン数を確認
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("🔥 DEBUG: 再読み込み後の状態:")
                    print("  - publicPlans: \(self.publicPlans.count)個")
                    print("  - userOriginalPlans: \(self.userOriginalPlans.count)個")
                    print("  - purchasedPlans: \(self.purchasedPlans.count)個")
                    print("  - savedPlans: \(self.savedPlans.count)個")
                }
            }) {
                if let draft = selectedDraftPlan {
                    VisitPlanningScreen(editingDraft: draft)
                } else {
                    VisitPlanningScreen()
                }
            }
            .sheet(item: $planToPurchase) { plan in
                let _ = print("💰 [DEBUG] purchase sheet が表示されます")
                let _ = print("💰 [DEBUG] planToPurchase: \(plan.title)")
                let _ = print("💰 [DEBUG] PlanPurchaseConfirmationView を作成中")
                
                PlanPurchaseConfirmationView(
                    plan: plan,
                    onConfirm: {
                        print("💰 [DEBUG] 購入確認ボタンが押されました")
                        planToPurchase = nil
                        purchasePlan(plan)
                    },
                    onCancel: {
                        print("💰 [DEBUG] キャンセルボタンが押されました")
                        planToPurchase = nil
                    }
                )
            }
            .sheet(isPresented: $showingPurchaseCompletion) {
                if let plan = purchasedPlan {
                    PlanPurchaseCompletionView(
                        plan: plan,
                        onViewPlan: {
                            showingPurchaseCompletion = false
                            selectedPlanForNavigation = plan
                        },
                        onClose: {
                            showingPurchaseCompletion = false
                        }
                    )
                }
            }
            .fullScreenCover(item: $selectedPlanForNavigation) { plan in
                let _ = print("🎮 [DEBUG] fullScreenCover呼び出し")
                let _ = print("🎮 [DEBUG] plan.id: \(plan.id)")
                let _ = print("🎮 [DEBUG] plan.title: \(plan.title)")
                let _ = print("🎮 [DEBUG] plan.spots.count: \(plan.spots.count)")
                
                VisitGameScreen(
                    animeName: plan.animeName,
                    duration: plan.duration,
                    planTitle: plan.title,
                    spots: plan.spots,
                    numberOfDays: plan.numberOfDays,
                    startTime: plan.startTime,
                    onClose: nil,
                    planId: UUID(uuidString: plan.id),
                    streamingUrls: plan.streamingUrls,
                    thumbnailUrl: plan.thumbnailUrl
                )
            }
            .alert("プランを削除しますか？", isPresented: $showingDeleteConfirmation, presenting: planToDelete) { plan in
                Button("削除", role: .destructive) {
                    deleteOriginalPlan(plan)
                }
                Button("キャンセル", role: .cancel) { }
            } message: { plan in
                Text("「\(plan.title)」を削除します。この操作は取り消せません。")
            }
            .onAppear {
                // userIdが設定されていない場合は新しいUUIDを生成
                if currentUserId.isEmpty || UserDefaults.standard.string(forKey: "userId") == nil {
                    let newUserId = UUID().uuidString
                    UserDefaults.standard.set(newUserId, forKey: "userId")
                    currentUserId = newUserId
                    print("DEBUG: 新しいユーザーIDを生成しました: \(newUserId)")
                }
                
                // データを読み込む
                loadHiddenPlanIds()
                loadSavedPlans()
                loadVisitAds()
                loadFirebasePlans()
                loadPurchasedPlansFromFirebase()
            }
            .onDisappear {
                stopAdTimer()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // アプリがフォアグラウンドに戻ったときにデータを再読み込み
                print("DEBUG: アプリがフォアグラウンドに戻りました - データを再読み込みします")
                loadSavedPlans()
                loadFirebasePlans()
                loadPurchasedPlansFromFirebase()
            }
    }
    
    @ViewBuilder
    private func planCard(for plan: VisitPlanModel) -> some View {
        let _ = print("🎯 [DEBUG] planCard - id: \(plan.id), userId: \(plan.userId), thumbnailUrl: \(plan.thumbnailUrl ?? "nil")")
        Button(action: {
            checkAndShowPlan(plan)
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // サムネイル画像
                ZStack {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(maxWidth: .infinity, maxHeight: 233)
                    
                    let _ = print("🖼️ [DEBUG] thumbnailUrl check - value: '\(plan.thumbnailUrl ?? "nil")', isEmpty: \(plan.thumbnailUrl?.isEmpty ?? true)")
                    
                    if let thumbnailUrl = plan.thumbnailUrl, !thumbnailUrl.isEmpty {
                        let _ = print("🖼️ [DEBUG] AsyncImage loading URL: \(thumbnailUrl)")
                        AsyncImage(url: URL(string: thumbnailUrl)) { phase in
                            switch phase {
                            case .empty:
                                let _ = print("🖼️ [DEBUG] AsyncImage loading...")
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(1.5)
                            case .success(let image):
                                let _ = print("🖼️ [DEBUG] AsyncImage success!")
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure(let error):
                                let _ = print("🖼️ [DEBUG] AsyncImage failed: \(error)")
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.orange)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else if let savedPlan = savedPlans.first(where: { $0.id.uuidString == plan.id }), 
                              let thumbnailData = savedPlan.thumbnailData,
                              let uiImage = UIImage(data: thumbnailData) {
                        // ローカルプランのサムネイル画像を表示
                        let _ = print("🖼️ [DEBUG] Using local thumbnail for plan: \(plan.id)")
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        let _ = print("🖼️ [DEBUG] No image available for plan: \(plan.id)")
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 233)
                .clipped()
                .overlay(
                    // バッジを表示 - overlayで統一された位置設定
                    Group {
                        if plan.isDraft {
                            // 下書きプランの場合は「下書き」バッジを表示
                            Text("下書き")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange)
                                .cornerRadius(8)
                        } else if selectedTab == .purchased {
                            // 購入済みタブでは「購入済み」バッジを表示
                            Text("購入済み")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .cornerRadius(8)
                        } else if selectedTab == .original && plan.price == 0 {
                            // オリジナルタブで無料プランの場合は「オリジナル」バッジを表示
                            Text("オリジナル")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple)
                                .cornerRadius(8)
                        } else if plan.price == 0 {
                            // その他のタブで無料プランの場合は「無料」バッジを表示
                            Text("無料")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green)
                                .cornerRadius(8)
                        }
                    }
                    .padding(8),
                    alignment: .bottomTrailing
                )
                .overlay(
                    // 管理者プランの場合は「PR」バッジを右上に表示
                    Group {
                        if plan.userId == "admin" && selectedTab == .all {
                            Text("PR")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.purple)
                                .cornerRadius(4)
                                .padding(8)
                        }
                    },
                    alignment: .topTrailing
                )
                
                // プラン情報
                HStack(alignment: .center, spacing: 12) {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "map.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.title)
                            .font(.headline)
                            .foregroundColor(.black)
                        Text("#\(plan.animeName)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    // オリジナルプランの場合は削除ボタンを表示
                    if selectedTab == .original {
                        Button(action: {
                            // オリジナルタブでは削除確認を表示
                            planToDelete = plan
                            showingDeleteConfirmation = true
                        }) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                                .frame(width: 32, height: 32)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Circle())
                        }
                    } else {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(plan.duration)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.blue)
                            Text("\(plan.spots.count)スポット")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func adCard(for ad: Advertisement) -> some View {
        Button(action: {
            if let url = URL(string: ad.linkURL) {
                firebaseManager.recordAdClick(advertisementId: ad.id ?? "")
                UIApplication.shared.open(url)
            }
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // 広告画像
                ZStack {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 233)
                    
                    if !ad.imageURL.isEmpty {
                        AsyncImage(url: URL(string: ad.imageURL)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(1.5)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure(_):
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.orange)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Image(systemName: "megaphone.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 233)
                .clipped()
                .overlay(
                    // 広告の場合は「PR」バッジを右上に表示
                    Text("PR")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black)
                        .cornerRadius(4)
                        .padding(8),
                    alignment: .topTrailing
                )
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "megaphone.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.orange)
                            Text(ad.title)
                                .font(.headline)
                                .foregroundColor(.black)
                        }
                        Text(ad.description)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            firebaseManager.recordAdImpression(advertisementId: ad.id ?? "")
        }
    }
    
    @ViewBuilder
    private var planListView: some View {
        let displayPlans = getDisplayPlans()
        let combinedItems = createCombinedItems(displayPlans)
        
        let _ = print("🔍 [DEBUG] planListView - selectedTab: \(selectedTab.rawValue)")
        let _ = print("🔍 [DEBUG] planListView - publicPlans.count: \(publicPlans.count)")
        let _ = print("🔍 [DEBUG] planListView - userOriginalPlans.count: \(userOriginalPlans.count)")
        let _ = print("🔍 [DEBUG] planListView - purchasedPlans.count: \(purchasedPlans.count)")
        let _ = print("🔍 [DEBUG] planListView - displayPlans.count: \(displayPlans.count)")
        
        if displayPlans.isEmpty && (selectedTab != .all || visitAds.isEmpty) {
            GeometryReader { geometry in
                VStack(spacing: 16) {
                Image(systemName: "map")
                    .font(.system(size: 50))
                    .foregroundColor(.purple)
                Text(selectedTab == .purchased ? "購入したプランがありません" : selectedTab == .original ? "オリジナルの旅行プランを作ろう" : "まだプランがありません")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                if selectedTab == .original {
                    Text("アニメの聖地を巡る、あなただけの旅行プランを作成しましょう")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    Button(action: { showingPlanningScreen = true }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("オリジナルプランを追加")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(red: 0.6, green: 0.4, blue: 0.9), Color(red: 0.8, green: 0.5, blue: 0.9)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                    }
                    .padding(.top, 20)
                } else if selectedTab == .purchased {
                    Text("お気に入りのプランを購入して\nアニメの世界を体験しよう")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    Button(action: { selectedTab = .all }) {
                        HStack {
                            Image(systemName: "cart")
                            Text("プランを購入する")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .cornerRadius(25)
                    }
                    .padding(.top, 20)
                }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            .frame(minHeight: 400)
        } else {
            ForEach(Array(combinedItems.enumerated()), id: \.offset) { index, item in
                if let plan = item as? VisitPlanModel {
                    planCard(for: plan)
                } else if let ad = item as? Advertisement {
                    adCard(for: ad)
                }
            }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        NavigationView {
            mainBodyContent
        }
    }
    
    @ViewBuilder
    private var mainBodyContent: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Button(action: { 
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showNavigationMenu = true
                        }
                    }) {
                        Image(systemName: "line.horizontal.3")
                            .font(.system(size: 28, weight: .regular))
                            .foregroundColor(.black)
                    }
                    Spacer()
                    // Amazon風検索バー（常時表示）
                    HStack(spacing: 0) {
                        HStack {
                            TextField("タイトルもしくはアニメから検索", text: $searchText)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .font(.system(size: 14))
                                .foregroundColor(.black)
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                    activeSearchText = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(Color(.systemGray3))
                                        .font(.system(size: 14))
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.white)
                        
                        // 検索ボタン
                        Button(action: {
                            // 検索を実行
                            activeSearchText = searchText
                            // キーボードを閉じる
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 45, height: 36)
                                .background(Color.red)
                        }
                    }
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.red, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 28) // さらに10px上げる
                .offset(y: -10) // さらに10px上にずらす
                // タブUI
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(VisitTab.allCases, id: \.self) { tab in
                            Button(action: { 
                                selectedTab = tab
                            }) {
                                Text(tab.rawValue)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(selectedTab == tab ? .white : .black)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(selectedTab == tab ? Color(.darkGray) : Color(.systemGray5))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                // ビジットプラン欄
                ScrollView {
                    VStack(spacing: 16) {
                        planListView
                    }
                    .padding(.top, 8)
                }
                Spacer()
            }
            // Createボタン（右下固定）
            Button(action: { showingPlanningScreen = true }) {
                Text("Create")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.red)
                    )
            }
            .padding(.bottom, 24)
            .padding(.trailing, 20)
        }
        .navigationBarHidden(true)
        .overlay(
            Group {
                if showNavigationMenu {
                    NavigationMenuView(
                        isPresented: $showNavigationMenu,
                        onShowCharacterOrder: nil,
                        onShowAnimeOrder: nil
                    )
                    .transition(.opacity)
                    .zIndex(2)
                }
            }
        )
        .overlay(
            Group {
                if isLoadingDraft {
                    ZStack {
                        Color.black.opacity(0.5)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text("下書きプランを読み込み中...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(40)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.black.opacity(0.8))
                        )
                    }
                    .transition(.opacity)
                    .zIndex(3)
                }
            }
        )
    }
    
    func loadSavedPlans() {
        print("🔍 DEBUG: loadSavedPlans開始")
        print("🔍 DEBUG: currentUserId: \(currentUserId)")
        guard let data = UserDefaultsHelper.shared.getData(forKey: "savedPlans") else {
            print("🔍 DEBUG: UserDefaultsにデータがありません")
            savedPlans = []
            userOriginalPlans = []
            return
        }
        
        do {
            let plans = try JSONDecoder().decode([VisitPlanData].self, from: data)
            savedPlans = plans
            
            // オリジナル作成プランのみ（購入プランを除外）
            print("🔍 DEBUG: フィルタリング前のプラン:")
            for plan in plans {
                print("  - \(plan.title): isPurchased=\(plan.isPurchased)")
            }
            
            let originalPlans = plans.filter { !$0.isPurchased }
            print("🔍 DEBUG: isPurchased=falseのプラン数: \(originalPlans.count)")
            
            userOriginalPlans = originalPlans.sorted(by: { $0.createdDate > $1.createdDate }).map { plan in
                VisitPlanModel(
                    id: plan.id.uuidString,
                    userId: currentUserId,
                    animeName: plan.animeName,
                    title: plan.title,
                    description: "", // ローカルプランにはdescriptionがない
                    duration: plan.duration,
                    spots: plan.spots,
                    thumbnailUrl: nil, // ローカルプランはサムネイルURLを持たない
                    price: 0, // ローカルプランは無料
                    budget: plan.totalCost,
                    createdDate: plan.createdDate,
                    startTime: plan.startTime,
                    numberOfDays: plan.numberOfDays,
                    totalCost: plan.totalCost,
                    isPublic: false, // ローカルプランは非公開
                    purchasedBy: [],
                    createdAt: plan.createdDate,
                    updatedAt: plan.createdDate,
                    isDraft: plan.isDraft, // 下書きフラグを設定
                    streamingUrls: plan.streamingUrls // ストリーミングURLを追加
                )
            }
            
            // 購入済みプランのみ（非表示を除外し、最新順にソート）
            purchasedPlans = plans.filter { $0.isPurchased && !hiddenPlanIds.contains($0.id.uuidString) }.sorted(by: { $0.createdDate > $1.createdDate }).map { plan in
                VisitPlanModel(
                    id: plan.id.uuidString,
                    userId: currentUserId,
                    animeName: plan.animeName,
                    title: plan.title,
                    description: "",
                    duration: plan.duration,
                    spots: plan.spots,
                    thumbnailUrl: plan.thumbnailUrl,
                    price: 0,
                    budget: plan.totalCost,
                    createdDate: plan.createdDate,
                    startTime: plan.startTime,
                    numberOfDays: plan.numberOfDays,
                    totalCost: plan.totalCost,
                    isPublic: false,
                    purchasedBy: [],
                    createdAt: plan.createdDate,
                    updatedAt: plan.createdDate,
                    isDraft: false, // 購入済みプランは下書きではない
                    streamingUrls: plan.streamingUrls // ストリーミングURLを追加
                )
            }
            
            print("🔍 DEBUG: 合計\(plans.count)個のプランを読み込みました")
            print("🔍 DEBUG: オリジナルプラン: \(userOriginalPlans.count)個")
            print("🔍 DEBUG: 購入済みプラン: \(purchasedPlans.count)個")
            for (index, plan) in plans.enumerated() {
                print("🔍 DEBUG: プラン[\(index)]: \(plan.title)")
                print("  - ID: \(plan.id)")
                print("  - スポット数: \(plan.spots.count)")
                print("  - 購入済み: \(plan.isPurchased)")
                print("  - 下書き: \(plan.isDraft)")
                print("  - 作成日: \(plan.createdDate)")
            }
        } catch {
            print("🚨 DEBUG: デコードエラー: \(error)")
            print("🚨 DEBUG: エラー詳細: \(error.localizedDescription)")
            savedPlans = []
            userOriginalPlans = []
            purchasedPlans = []
        }
        
        print("🔍 DEBUG: loadSavedPlans完了")
        print("  - savedPlans: \(savedPlans.count)個")
        print("  - userOriginalPlans: \(userOriginalPlans.count)個")
        print("  - purchasedPlans: \(purchasedPlans.count)個")
    }
    
    func loadVisitAds() {
        firebaseManager.fetchAds(for: "visit") { result in
            switch result {
            case .success(let ads):
                print("✅ ビジット広告取得成功: \(ads.count)件")
                for ad in ads {
                    print("  - 広告: \(ad.title), ID: \(ad.id ?? "nil"), placement: \(ad.placements)")
                }
                
                // ユーザーのアニメ・キャラクター・ハッシュタグを取得
                let userAnimes = self.getUserAnimes()
                let userCharacters = self.getUserCharacters() 
                let userHashtags = self.getUserHashtags()
                
                print("ユーザーデータ - アニメ: \(userAnimes), キャラ: \(userCharacters), タグ: \(userHashtags)")
                
                // フィルタリング: ターゲット広告は対象のユーザーのみ、一般広告は全ユーザー
                self.visitAds = ads.filter { ad in
                    // 一般広告の場合は全員に表示
                    if ad.targetAnimes.isEmpty && ad.targetCharacters.isEmpty && ad.targetHashtags.isEmpty {
                        return true
                    }
                    
                    // ターゲット広告の場合はマッチング確認
                    let animeMatch = ad.targetAnimes.isEmpty || ad.targetAnimes.contains { userAnimes.contains($0) }
                    let characterMatch = ad.targetCharacters.isEmpty || ad.targetCharacters.contains { userCharacters.contains($0) }
                    let hashtagMatch = ad.targetHashtags.isEmpty || ad.targetHashtags.contains { userHashtags.contains($0) }
                    
                    return animeMatch && characterMatch && hashtagMatch
                }
                
                print("✅ フィルタリング後のビジット広告: \(self.visitAds.count)件")
                for (index, ad) in self.visitAds.enumerated() {
                    print("  広告[\(index)]: \(ad.title)")
                    print("    - 画像URL: \(ad.imageURL.isEmpty ? "空" : ad.imageURL)")
                    print("    - リンクURL: \(ad.linkURL)")
                    print("    - 説明: \(ad.description)")
                }
                
                // 広告が読み込まれた後にタイマーを開始
                DispatchQueue.main.async {
                    self.startAdTimer()
                }
                
            case .failure(let error):
                print("❌ ビジット広告取得エラー: \(error)")
            }
        }
    }
    
    func startAdTimer() {
        guard visitAds.count > 1 else { return }
        adTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentAdIndex = (currentAdIndex + 1) % visitAds.count
            }
        }
    }
    
    func stopAdTimer() {
        adTimer?.invalidate()
        adTimer = nil
    }
    
    func getDisplayPlans() -> [VisitPlanModel] {
        let basePlans: [VisitPlanModel]
        switch selectedTab {
        case .all:
            basePlans = publicPlans
        case .original:
            basePlans = userOriginalPlans
        case .purchased:
            basePlans = purchasedPlans
        }
        
        // 検索フィルタリング
        if activeSearchText.isEmpty {
            return basePlans
        } else {
            return basePlans.filter { plan in
                plan.title.localizedCaseInsensitiveContains(activeSearchText) ||
                plan.animeName.localizedCaseInsensitiveContains(activeSearchText)
            }
        }
    }
    
    func createCombinedItems(_ plans: [VisitPlanModel]) -> [Any] {
        var items: [Any] = []
        
        // オールタブの場合のみ広告を表示
        if selectedTab == .all && !visitAds.isEmpty {
            let adIndex = visitAds.count > 1 ? currentAdIndex % visitAds.count : 0
            items.append(visitAds[adIndex])
        }
        
        // プランを追加
        items.append(contentsOf: plans)
        
        return items
    }
    
    // ユーザーのアニメ・キャラクター・ハッシュタグを取得する関数
    func getUserAnimes() -> [String] {
        // 簡易的な実装：UserDefaultsから直接文字列配列として取得
        // 実際のアプリケーションでは、AnimeManagerなどを通じて取得する方が望ましい
        if let animesData = UserDefaults.standard.data(forKey: "animes"),
           let animes = try? JSONSerialization.jsonObject(with: animesData) as? [[String: Any]] {
            return animes.compactMap { $0["title"] as? String }
        }
        return []
    }
    
    func getUserCharacters() -> [String] {
        // 簡易的な実装：UserDefaultsから直接文字列配列として取得
        if let charactersData = UserDefaults.standard.data(forKey: "characters"),
           let characters = try? JSONSerialization.jsonObject(with: charactersData) as? [[String: Any]] {
            return characters.compactMap { $0["name"] as? String }
        }
        return []
    }
    
    func getUserHashtags() -> [String] {
        var hashtags: [String] = []
        
        // アニメのハッシュタグ
        if let animesData = UserDefaults.standard.data(forKey: "animes"),
           let animes = try? JSONSerialization.jsonObject(with: animesData) as? [[String: Any]] {
            let animeTags = animes.compactMap { $0["hashtag"] as? String }
            hashtags.append(contentsOf: animeTags)
        }
        
        // キャラクターのハッシュタグ
        if let charactersData = UserDefaults.standard.data(forKey: "characters"),
           let characters = try? JSONSerialization.jsonObject(with: charactersData) as? [[String: Any]] {
            let characterTags = characters.compactMap { $0["tag"] as? String }
            hashtags.append(contentsOf: characterTags)
        }
        
        return Array(Set(hashtags)) // 重複を除去
    }
    
    // Firebaseからプランを読み込む
    func loadFirebasePlans() {
        print("DEBUG: loadFirebasePlans開始 - currentUserId: \(currentUserId)")
        print("DEBUG: 現在のpublicPlans数: \(publicPlans.count)")
        
        // まず、すべての管理者プランを確認（デバッグ用）
        print("🔍 [DEBUG] すべての管理者プランを確認...")
        let db = Firestore.firestore()
        db.collection("visitPlans")
            .whereField("userId", isEqualTo: "admin")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ 管理者プラン確認エラー: \(error)")
                } else {
                    print("✅ 管理者プラン総数: \(snapshot?.documents.count ?? 0)件")
                    snapshot?.documents.forEach { doc in
                        let data = doc.data()
                        print("  プラン: \(data["title"] as? String ?? "nil")")
                        print("    - ID: \(doc.documentID)")
                        print("    - isPublic: \(data["isPublic"] as? Bool ?? false)")
                        print("    - createdAt: \(data["createdAt"] ?? "nil")")
                    }
                }
            }
        
        // 公開プランを取得（強制的にFirebaseから新しいデータを取得）
        firebaseManager.fetchPublicPlans { result in
            switch result {
            case .success(let plans):
                print("DEBUG: 公開プラン取得成功: \(plans.count)件")
                
                // 管理者プランのみをフィルタリングして確認
                let adminPlans = plans.filter { $0.userId == "admin" }
                print("DEBUG: 取得した管理者プラン数: \(adminPlans.count)")
                
                // 各プランの詳細をログ出力
                for (index, plan) in plans.enumerated() {
                    print("DEBUG: プラン[\(index)] - タイトル: \(plan.title)")
                    print("  - userId: \(plan.userId)")
                    print("  - isPublic: \(plan.isPublic)")
                    print("  - スポット数: \(plan.spots.count)")
                }
                
                self.publicPlans = plans
                print("DEBUG: publicPlansを更新しました: \(self.publicPlans.count)件")
            case .failure(let error):
                print("公開プラン取得エラー: \(error)")
            }
        }
        
        // ユーザーのプランはローカルから読み込むため、Firebaseからの取得は不要
        // loadSavedPlans()でuserOriginalPlansに設定される
    }
    
    // プランの購入状態をチェックして表示
    func checkAndShowPlan(_ plan: VisitPlanModel) {
        print("DEBUG: checkAndShowPlan開始")
        print("  - plan.userId: \(plan.userId)")
        print("  - currentUserId: \(currentUserId)")
        print("  - plan.price: \(plan.price)")
        print("  - plan.isDraft: \(plan.isDraft)")
        
        // 下書きプランの場合は編集画面を開く
        if plan.isDraft {
            print("  → 下書きプランです。編集画面を開きます。")
            
            // ローディング開始
            isLoadingDraft = true
            
            // 対応するVisitPlanDataを見つける（現在のsavedPlansから直接取得）
            if let draftData = savedPlans.first(where: { $0.id.uuidString == plan.id }) {
                print("  → 下書きデータを見つけました: \(draftData.title)")
                // 少し遅延を入れてスムーズな遷移を演出
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.selectedDraftPlan = draftData
                    self.showingPlanningScreen = true
                    self.isLoadingDraft = false
                }
            } else {
                print("  → 下書きデータが見つかりません。最新データを読み込みます。")
                // データが見つからない場合のみ再読み込み
                loadSavedPlans()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let draftData = self.savedPlans.first(where: { $0.id.uuidString == plan.id }) {
                        print("  → 再読み込み後、下書きデータを見つけました: \(draftData.title)")
                        self.selectedDraftPlan = draftData
                        self.showingPlanningScreen = true
                    } else {
                        print("  → エラー: 下書きデータが見つかりません")
                    }
                    self.isLoadingDraft = false
                }
            }
            return
        }
        
        // オールタブで非表示のプランをクリックした場合、再表示する
        if selectedTab == .all && hiddenPlanIds.contains(plan.id) {
            hiddenPlanIds.remove(plan.id)
            saveHiddenPlanIds()
            // 即座に購入済みプランを更新
            DispatchQueue.main.async {
                self.loadSavedPlans()
            }
            // プラン詳細も表示
            showPlanDetail(plan)
            return
        }
        
        // 自分のプランか、無料プランの場合は直接表示
        if plan.userId == currentUserId || plan.price == 0 {
            print("  → 自分のプランまたは無料プラン。直接表示します。")
            showPlanDetail(plan)
            return
        }
        
        // 既に購入済みのプランかチェック（ローカルストレージ）
        if savedPlans.contains(where: { $0.id.uuidString == plan.id && $0.isPurchased }) {
            print("  → ローカルストレージに購入済みプランがあります。直接表示します。")
            showPlanDetail(plan)
            return
        }
        
        print("  → 有料プランです。購入チェックを開始します。")
        
        // まずローカル購入記録をチェック
        if checkLocalPurchaseRecord(planId: plan.id) {
            print("  → ローカル購入記録があります。直接表示します。")
            showPlanDetail(plan)
            return
        }
        
        // ローカル記録にない場合、Firebaseでチェック
        firebaseManager.checkPlanPurchased(userId: currentUserId, planId: plan.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let isPurchased):
                    print("  → 購入チェック結果: \(isPurchased ? "購入済み" : "未購入")")
                    if isPurchased {
                        print("  → 購入済みなので直接表示します。")
                        // Firebaseで購入確認できた場合、ローカル記録も更新
                        self.saveLocalPurchaseRecord(planId: plan.id)
                        self.showPlanDetail(plan)
                    } else {
                        print("  → 未購入なので購入画面を表示します。")
                        self.showPurchaseDialog(for: plan)
                    }
                case .failure(let error):
                    print("  → 購入チェックエラー: \(error)")
                    // エラーが発生した場合も購入画面を表示
                    print("  → エラーのため購入画面を表示します。")
                    self.showPurchaseDialog(for: plan)
                }
            }
        }
    }
    
    // プラン詳細を表示
    func showPlanDetail(_ plan: VisitPlanModel) {
        print("DEBUG: showPlanDetail - プラン表示開始")
        print("  - id: \(plan.id)")
        print("  - title: \(plan.title)")
        print("  - spots count: \(plan.spots.count)")
        
        self.selectedPlanForNavigation = plan
        print("DEBUG: showPlanDetail - selectedPlanForNavigation設定完了")
    }
    
    // 購入ダイアログを表示
    func showPurchaseDialog(for plan: VisitPlanModel) {
        print("DEBUG: showPurchaseDialog - 購入ダイアログ表示開始")
        print("  - plan.title: \(plan.title)")
        print("  - plan.price: \(plan.price)")
        
        // planToPurchaseを設定するとsheet(item:)が自動的に表示される
        planToPurchase = plan
        print("DEBUG: showPurchaseDialog - planToPurchase設定完了: \(planToPurchase?.title ?? "nil")")
    }
    
    func purchasePlan(_ plan: VisitPlanModel) {
        let userId = UserDefaults.standard.string(forKey: "userId") ?? UUID().uuidString
        
        // 既に購入済みかチェック
        if savedPlans.contains(where: { $0.id.uuidString == plan.id && $0.isPurchased }) {
            print("⚠️ このプランは既に購入済みです: \(plan.title)")
            return
        }
        
        // プランの価格分のポイントを消費
        firebaseManager.usePoints(userId: userId, points: plan.price, reason: "プラン購入: \(plan.title)") { result in
            switch result {
            case .success:
                print("✅ ポイント消費成功: \(plan.title)")
                
                // Firebase に購入記録を保存
                let purchase = PlanPurchase(
                    id: UUID().uuidString,
                    userId: userId,
                    planId: plan.id,
                    planOwnerId: plan.userId,
                    purchasePrice: plan.price,
                    purchasedAt: Date(),
                    stripePaymentIntentId: nil
                )
                
                self.firebaseManager.recordPlanPurchase(purchase) { purchaseResult in
                    // どちらの場合でも一度だけ保存
                    self.savePurchasedPlan(plan)
                    self.saveLocalPurchaseRecord(planId: plan.id)
                    
                    switch purchaseResult {
                    case .success:
                        print("✅ Firebase購入記録保存成功: \(plan.title)")
                    case .failure(let error):
                        print("❌ Firebase購入記録保存失敗: \(error)")
                        print("  → ローカルには保存済み")
                    }
                    
                    DispatchQueue.main.async {
                        self.purchasedPlan = plan
                        self.showingPurchaseCompletion = true
                    }
                }
                
            case .failure(let error):
                print("❌ プラン購入失敗: \(error)")
                DispatchQueue.main.async {
                    // エラーメッセージを表示する処理をここに追加できます
                }
            }
        }
    }
    
    func savePurchasedPlan(_ plan: VisitPlanModel) {
        // VisitPlanModelをVisitPlanDataに変換（購入プランとしてマーク）
        let visitPlanData = VisitPlanData(
            id: UUID(uuidString: plan.id) ?? UUID(),
            animeName: plan.animeName,
            title: plan.title,
            duration: plan.duration,
            spots: plan.spots,
            thumbnailData: nil,
            thumbnailUrl: plan.thumbnailUrl,
            createdDate: plan.createdDate,
            startTime: plan.startTime,
            numberOfDays: plan.numberOfDays,
            isPurchased: true,
            streamingUrls: plan.streamingUrls
        )
        
        // 既存の保存済みプランを読み込み
        var savedPlans = self.savedPlans
        
        // 既に同じプランが保存されていないかチェック（IDとタイトルの両方でチェック）
        if !savedPlans.contains(where: { $0.id.uuidString == plan.id || ($0.title == plan.title && $0.isPurchased) }) {
            savedPlans.append(visitPlanData)
            
            // UserDefaultsに保存
            if let encodedData = try? JSONEncoder().encode(savedPlans) {
                UserDefaults.standard.set(encodedData, forKey: "savedPlans")
                print("✅ 購入プランをローカルに保存: \(plan.title)")
                
                // 保存済みプランのリストを直接更新（重複を防ぐため）
                self.savedPlans = savedPlans
                
                // 保存済みプランを再読み込み
                DispatchQueue.main.async {
                    self.loadSavedPlans()
                }
            }
        } else {
            print("⚠️ プランは既に保存されています: \(plan.title)")
        }
    }
    
    func deleteOriginalPlan(_ plan: VisitPlanModel) {
        // savedPlansから削除
        if let index = savedPlans.firstIndex(where: { $0.id.uuidString == plan.id }) {
            savedPlans.remove(at: index)
            
            // UserDefaultsに保存
            if let encodedData = try? JSONEncoder().encode(savedPlans) {
                UserDefaults.standard.set(encodedData, forKey: "savedPlans")
            }
            
            // userOriginalPlansから削除
            userOriginalPlans.removeAll(where: { $0.id == plan.id })
        }
    }
    
    // 購入済みプランを非表示にする
    func hidePurchasedPlan(_ plan: VisitPlanModel) {
        hiddenPlanIds.insert(plan.id)
        saveHiddenPlanIds()
        // リストを再読み込み
        loadSavedPlans()
    }
    
    // 非表示のプランIDを保存
    func saveHiddenPlanIds() {
        let idsArray = Array(hiddenPlanIds)
        if let data = try? JSONEncoder().encode(idsArray) {
            UserDefaultsHelper.shared.setData(data, forKey: "hiddenPlanIds")
        }
    }
    
    // 非表示のプランIDを読み込み
    func loadHiddenPlanIds() {
        if let data = UserDefaultsHelper.shared.getData(forKey: "hiddenPlanIds"),
           let idsArray = try? JSONDecoder().decode([String].self, from: data) {
            hiddenPlanIds = Set(idsArray)
        } else {
            hiddenPlanIds = []
        }
    }
    
    // ローカル購入記録を保存
    func saveLocalPurchaseRecord(planId: String) {
        var purchasedPlanIds = UserDefaults.standard.stringArray(forKey: "purchasedPlanIds_\(currentUserId)") ?? []
        if !purchasedPlanIds.contains(planId) {
            purchasedPlanIds.append(planId)
            UserDefaults.standard.set(purchasedPlanIds, forKey: "purchasedPlanIds_\(currentUserId)")
            print("✅ ローカル購入記録保存: planId=\(planId), userId=\(currentUserId)")
        }
    }
    
    // ローカル購入記録をチェック
    func checkLocalPurchaseRecord(planId: String) -> Bool {
        let purchasedPlanIds = UserDefaults.standard.stringArray(forKey: "purchasedPlanIds_\(currentUserId)") ?? []
        let isPurchased = purchasedPlanIds.contains(planId)
        print("🔍 ローカル購入記録チェック: planId=\(planId), isPurchased=\(isPurchased)")
        return isPurchased
    }
    
    // Firebaseから購入済みプランを読み込む
    func loadPurchasedPlansFromFirebase() {
        print("DEBUG: loadPurchasedPlansFromFirebase開始 - currentUserId: \(currentUserId)")
        
        // Firestoreから購入記録を取得
        firebaseManager.database.collection("planPurchases")
            .whereField("userId", isEqualTo: currentUserId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ 購入記録取得エラー: \(error)")
                    return
                }
                
                let purchaseRecords = snapshot?.documents ?? []
                print("📋 購入記録数: \(purchaseRecords.count)")
                
                // 購入したプランのIDを取得
                let purchasedPlanIds = purchaseRecords.compactMap { doc in
                    doc.data()["planId"] as? String
                }
                
                print("📋 購入済みプランID: \(purchasedPlanIds)")
                
                // 購入したプランをFirebaseから取得してローカルに保存
                for planId in purchasedPlanIds {
                    self.downloadAndSavePurchasedPlan(planId: planId)
                }
            }
    }
    
    // 購入済みプランをFirebaseからダウンロードしてローカルに保存
    func downloadAndSavePurchasedPlan(planId: String) {
        print("DEBUG: downloadAndSavePurchasedPlan開始 - planId: \(planId)")
        
        firebaseManager.database.collection("visitPlans").document(planId).getDocument { snapshot, error in
            if let error = error {
                print("❌ プランダウンロードエラー: \(error)")
                return
            }
            
            guard let document = snapshot, document.exists,
                  let data = document.data(),
                  let plan = VisitPlanModel(dictionary: data) else {
                print("❌ プランデータの変換に失敗")
                return
            }
            
            print("✅ プランダウンロード成功: \(plan.title)")
            
            // ローカルに既に保存されているかチェック
            let existingPlan = self.savedPlans.first { $0.id.uuidString == planId }
            if existingPlan == nil {
                // ローカルに保存
                self.savePurchasedPlan(plan)
                print("✅ 購入済みプランをローカルに保存: \(plan.title)")
            } else {
                print("ℹ️ プランは既にローカルに存在します: \(plan.title)")
            }
        }
    }
}

// GitHub URL変換関数
func convertGitHubUrl(_ url: String) -> String {
    if url.contains("github.com") && url.contains("/blob/") {
        return url
            .replacingOccurrences(of: "github.com", with: "raw.githubusercontent.com")
            .replacingOccurrences(of: "/blob/", with: "/")
    }
    return url
}




