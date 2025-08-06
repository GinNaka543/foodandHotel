import SwiftUI
import Foundation
import UIKit
import FirebaseFirestore

// VisitTypes.swiftの型を使用するための明示的なimport

public struct VisitScreen: View {
    @State private var savedPlans: [VisitPlanData] = []
    @State private var selectedPlan: VisitPlanData?
    // 広告関連の状態変数を削除
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
    @State private var isLoadingPlan = false
    @State private var loadingMessage = ""
    @EnvironmentObject var mainTab: MainTabSelection
    
    // タブ用
    enum VisitTab: String, CaseIterable {
        case all = "all"
        case original = "original"
        case purchased = "purchased"
        
        var displayName: String {
            switch self {
            case .all:
                return NSLocalizedString("visit_tab_all", comment: "All tab")
            case .original:
                return NSLocalizedString("visit_tab_original", comment: "Original tab")
            case .purchased:
                return NSLocalizedString("visit_tab_purchased", comment: "Purchased tab")
            }
        }
    }
    @State private var selectedTab: VisitTab = .all
    @State private var showSearchBar = true
    @State private var searchText = ""
    @State private var activeSearchText = ""
    @State private var showingPlanningScreen = false
    @State private var showingCurrencySelection = false
    @State private var selectedPlanCurrency = CurrencyManager.shared.selectedCurrency
    
    public var body: some View {
        mainContent
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToVisitOriginalTab"))) { _ in
                selectedTab = .original
            }
            .fullScreenCover(isPresented: $showingPlanningScreen, onDismiss: {
                selectedDraftPlan = nil // クリア
                selectedTab = .original // オリジナルタブに移動
                loadSavedPlans()
                loadFirebasePlans()
                
                // タブごとのプラン数を確認
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                }
            }) {
                if let draft = selectedDraftPlan {
                    VisitPlanningScreen(editingDraft: draft)
                } else {
                    VisitPlanningScreen()
                }
            }
            .sheet(item: $planToPurchase) { plan in
                
                PlanPurchaseConfirmationView(
                    plan: plan,
                    onConfirm: {
                        planToPurchase = nil
                        purchasePlan(plan)
                    },
                    onCancel: {
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
                
                VisitGameScreen(
                    animeName: plan.animeName,
                    duration: plan.duration,
                    planTitle: plan.title,
                    spots: plan.spots,
                    numberOfDays: plan.numberOfDays,
                    startTime: plan.startTime,
                    onClose: nil,
                    planId: UUID(uuidString: plan.id),
                    isReadOnly: false,
                    streamingUrls: plan.streamingUrls,
                    thumbnailUrl: plan.thumbnailUrl
                )
            }
            .alert(NSLocalizedString("delete_plan_confirm_title", comment: "Delete plan?"), isPresented: $showingDeleteConfirmation, presenting: planToDelete) { plan in
                Button(NSLocalizedString("delete", comment: "Delete"), role: .destructive) {
                    deleteOriginalPlan(plan)
                }
                Button(NSLocalizedString("cancel", comment: "Cancel"), role: .cancel) { }
            } message: { plan in
                Text(String(format: NSLocalizedString("delete_plan_confirm_message", comment: "Delete \"%@\". This action cannot be undone."), plan.title))
            }
            .sheet(isPresented: $showingCurrencySelection) {
                InitialCurrencySelectionView(
                    isPresented: $showingCurrencySelection,
                    selectedCurrency: $selectedPlanCurrency,
                    onCurrencySelected: {
                        // 通貨が選択されたら、CurrencyManagerに設定してプラン作成画面を開く
                        CurrencyManager.shared.selectedCurrency = selectedPlanCurrency
                        showingPlanningScreen = true
                    }
                )
            }
            .onAppear {
                loadingMessage = NSLocalizedString("loading_plans", comment: "Loading plans...")
                // userIdが設定されていない場合は新しいUUIDを生成
                if currentUserId.isEmpty || UserDefaults.standard.string(forKey: "userId") == nil {
                    let newUserId = UUID().uuidString
                    UserDefaults.standard.set(newUserId, forKey: "userId")
                    currentUserId = newUserId
                }
                
                // データを読み込む
                loadHiddenPlanIds()
                loadSavedPlans()
                // 広告読み込みを削除
                loadFirebasePlans()
                loadPurchasedPlansFromFirebase()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // アプリがフォアグラウンドに戻ったときにデータを再読み込み
                loadSavedPlans()
                loadFirebasePlans()
                loadPurchasedPlansFromFirebase()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ReloadVisitPlans"))) { _ in
                // print("📱 [VisitScreen] Received ReloadVisitPlans notification - reloading all plans")
                loadSavedPlans()
                loadFirebasePlans()
                loadPurchasedPlansFromFirebase()
            }
    }
    
    @ViewBuilder
    private func planCard(for plan: VisitPlanModel) -> some View {
        Button(action: {
            checkAndShowPlan(plan)
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // サムネイル画像
                ZStack {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(maxWidth: .infinity, maxHeight: 233)
                    
                    
                    if let thumbnailUrl = plan.thumbnailUrl, !thumbnailUrl.isEmpty {
                        AsyncImage(url: URL(string: thumbnailUrl)) { phase in
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
                    } else if let savedPlan = savedPlans.first(where: { $0.id.uuidString == plan.id }), 
                              let thumbnailData = savedPlan.thumbnailData,
                              let uiImage = UIImage(data: thumbnailData) {
                        // ローカルプランのサムネイル画像を表示
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
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
                            Text(NSLocalizedString("draft", comment: "Draft"))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange)
                                .cornerRadius(8)
                        } else if selectedTab == .purchased {
                            // 購入済みタブでは「購入済み」バッジを表示
                            Text(NSLocalizedString("purchased", comment: "Purchased"))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .cornerRadius(8)
                        } else if selectedTab == .original && plan.price == 0 {
                            // オリジナルタブで無料プランの場合は「オリジナル」バッジを表示
                            Text(NSLocalizedString("original", comment: "Original"))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple)
                                .cornerRadius(8)
                        } else if plan.price == 0 {
                            // その他のタブで無料プランの場合は「無料」バッジを表示
                            Text(NSLocalizedString("free", comment: "Free"))
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
                            Text(formatPlanDuration(plan.duration))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.blue)
                            Text(String(format: NSLocalizedString("spots_count", comment: "%d spots"), plan.spots.count))
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
    
    // 広告カード機能を削除
    
    @ViewBuilder
    private var planListView: some View {
        let displayPlans = getDisplayPlans()
        let combinedItems = createCombinedItems(displayPlans)
        
        
        if displayPlans.isEmpty {
            GeometryReader { geometry in
                VStack(spacing: 16) {
                Image(systemName: "map")
                    .font(.system(size: 50))
                    .foregroundColor(.purple)
                Text(selectedTab == .purchased ? NSLocalizedString("no_purchased_plans", comment: "No purchased plans") : selectedTab == .original ? NSLocalizedString("create_original_plan", comment: "Create your original travel plan") : NSLocalizedString("no_plans_yet", comment: "No plans yet"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                if selectedTab == .original {
                    Text(NSLocalizedString("create_anime_pilgrimage_plan", comment: "Create your own travel plan to visit anime sacred places"))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    Button(action: { showingCurrencySelection = true }) {
                        HStack {
                            Image(systemName: "plus")
                            Text(NSLocalizedString("add_original_plan", comment: "Add original plan"))
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
                    Text(NSLocalizedString("purchase_favorite_plan_message", comment: "Purchase your favorite plan and\nexperience the anime world"))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    Button(action: { selectedTab = .all }) {
                        HStack {
                            Image(systemName: "cart")
                            Text(NSLocalizedString("purchase_plan", comment: "Purchase plan"))
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.black)
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
                }
                // 広告表示を削除
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
                            TextField(NSLocalizedString("search_by_title_or_anime", comment: "Search by title or anime"), text: $searchText)
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
                                .background(Color.black)
                        }
                    }
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black, lineWidth: 1)
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
                                Text(tab.displayName)
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
            Button(action: { showingCurrencySelection = true }) {
                Text("Create")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black)
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
                if isLoadingDraft || isLoadingPlan {
                    ZStack {
                        Color.black.opacity(0.5)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text(isLoadingDraft ? NSLocalizedString("loading_draft_plans", comment: "Loading draft plans...") : loadingMessage)
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
                    .animation(.easeInOut(duration: 0.3), value: isLoadingDraft || isLoadingPlan)
                    .zIndex(3)
                }
            }
        )
    }
    
    func loadSavedPlans() {
        print("DEBUG: loadSavedPlans called")
        
        // 古いUserDefaultsデータをクリーンアップ（一度だけ実行）
        cleanupOldUserDefaultsData()
        
        // 緊急修正: Test3の重複を強制的に削除
        emergencyCleanupTest3Duplicates()
        
        // 重複データをクリーンアップ
        VisitPlanDataStorage.shared.cleanupDuplicatePlans()
        
        // 新しいストレージシステムからプランを読み込む
        let allSavedPlans = VisitPlanDataStorage.shared.loadAllSavedPlans()
        let allDraftPlans = VisitPlanDataStorage.shared.loadAllDraftPlans()
        
        let plans = allSavedPlans + allDraftPlans
        savedPlans = plans
        print("DEBUG: Loaded \(plans.count) saved plans (including \(allDraftPlans.count) drafts)")
        
        // オリジナル作成プランのみ（購入プランを除外）
        let originalPlans = plans.filter { !$0.isPurchased }
        print("DEBUG: Found \(originalPlans.count) original plans (non-purchased)")
        
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
        
        // 重複削除を適用
        userOriginalPlans = removeDuplicatePlans(userOriginalPlans)
        print("DEBUG: userOriginalPlans updated with \(userOriginalPlans.count) plans after deduplication")
        
        // 購入済みプランのみ（非表示を除外し、最新順にソート）
        let tempPurchasedPlans = plans.filter { $0.isPurchased && !hiddenPlanIds.contains($0.id.uuidString) }.sorted(by: { $0.createdDate > $1.createdDate }).map { plan in
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
        
        // 購入済みプランにも重複削除を適用
        purchasedPlans = removeDuplicatePlans(tempPurchasedPlans)
        print("DEBUG: purchasedPlans updated with \(purchasedPlans.count) plans after deduplication")
    }
    
    // 広告関連の機能を削除
    
    func getDisplayPlans() -> [VisitPlanModel] {
        let basePlans: [VisitPlanModel]
        switch selectedTab {
        case .all:
            // オールタブでは言語フィルタリングを適用（管理者設定言語 vs アプリ言語）
            let currentAppLanguage = LocalizationManager.shared.currentLanguage.rawValue
            print("DEBUG: getDisplayPlans - Current app language: \(currentAppLanguage)")
            print("DEBUG: getDisplayPlans - Total publicPlans: \(publicPlans.count)")
            
            basePlans = publicPlans.filter { plan in
                // 管理者プランの場合、設定された言語とアプリ言語を比較
                if plan.userId == "admin" {
                    print("DEBUG: getDisplayPlans - Admin plan: '\(plan.title)' language: \(plan.language ?? "nil")")
                    
                    // 言語が設定されていない場合は表示しない（管理者は言語を明示的に設定する必要がある）
                    guard let planLanguage = plan.language, !planLanguage.isEmpty else {
                        print("DEBUG: getDisplayPlans - Plan '\(plan.title)' has no language, not showing")
                        return false
                    }
                    
                    // 中国語の場合は zh と zh-Hans 両方をサポート（後方互換性）
                    if currentAppLanguage == "zh-Hans" && planLanguage == "zh" {
                        print("DEBUG: getDisplayPlans - Plan '\(plan.title)' matches zh->zh-Hans compatibility")
                        return true
                    }
                    
                    // 管理者設定言語 == アプリ言語の場合に表示
                    let shouldShow = planLanguage == currentAppLanguage
                    print("DEBUG: getDisplayPlans - Plan '\(plan.title)' - planLang: \(planLanguage), appLang: \(currentAppLanguage), showing: \(shouldShow)")
                    return shouldShow
                }
                // 一般ユーザーのプランはすべて表示
                print("DEBUG: getDisplayPlans - User plan: '\(plan.title)' - showing")
                return true
            }
            print("DEBUG: getDisplayPlans - Filtered to \(basePlans.count) plans from \(publicPlans.count)")
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
        
        // 広告表示を削除 - プランのみを表示
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
        
        // まず、すべての管理者プランを確認（デバッグ用）
        let db = Firestore.firestore()
        db.collection("visitPlans")
            .whereField("userId", isEqualTo: "admin")
            .getDocuments { snapshot, error in
                if error != nil {
                } else {
                    snapshot?.documents.forEach { doc in
                        let _ = doc.data()
                    }
                }
            }
        
        // 公開プランを取得（強制的にFirebaseから新しいデータを取得）
        firebaseManager.fetchPublicPlans { result in
            switch result {
            case .success(let plans):
                
                // 管理者プランのみをフィルタリングして確認
                let _ = plans.filter { $0.userId == "admin" }
                
                // 各プランの詳細をログ出力
                for (_, _) in plans.enumerated() {
                }
                
                // ドラフトでないプランのみを取得（言語フィルタリングはgetDisplayPlans()で行う）
                self.publicPlans = plans.filter { !$0.isDraft }
            case .failure(_):
                break
            }
        }
        
        // ユーザーのプランはローカルから読み込むため、Firebaseからの取得は不要
        // loadSavedPlans()でuserOriginalPlansに設定される
    }
    
    // プランの購入状態をチェックして表示
    func checkAndShowPlan(_ plan: VisitPlanModel) {
        
        // 下書きプランの場合は編集画面を開く
        if plan.isDraft {
            
            // ローディング開始
            isLoadingDraft = true
            
            // 対応するVisitPlanDataを見つける（現在のsavedPlansから直接取得）
            if let draftData = savedPlans.first(where: { $0.id.uuidString == plan.id }) {
                // 少し遅延を入れてスムーズな遷移を演出
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.selectedDraftPlan = draftData
                    self.showingPlanningScreen = true
                    self.isLoadingDraft = false
                }
            } else {
                // データが見つからない場合のみ再読み込み
                loadSavedPlans()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let draftData = self.savedPlans.first(where: { $0.id.uuidString == plan.id }) {
                        self.selectedDraftPlan = draftData
                        self.showingPlanningScreen = true
                    } else {
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
            showPlanDetail(plan)
            return
        }
        
        // 既に購入済みのプランかチェック（ローカルストレージ）
        if savedPlans.contains(where: { $0.id.uuidString == plan.id && $0.isPurchased }) {
            showPlanDetail(plan)
            return
        }
        
        
        // まずローカル購入記録をチェック
        if checkLocalPurchaseRecord(planId: plan.id) {
            showPlanDetail(plan)
            return
        }
        
        // ローカル記録にない場合、Firebaseでチェック
        loadingMessage = NSLocalizedString("checking_purchase_status", comment: "Checking purchase status...")
        isLoadingPlan = true
        
        firebaseManager.checkPlanPurchased(userId: currentUserId, planId: plan.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let isPurchased):
                    self.isLoadingPlan = false
                    if isPurchased {
                        // Firebaseで購入確認できた場合、ローカル記録も更新
                        self.saveLocalPurchaseRecord(planId: plan.id)
                        self.showPlanDetail(plan)
                    } else {
                        self.showPurchaseDialog(for: plan)
                    }
                case .failure(_):
                    self.isLoadingPlan = false
                    // エラーが発生した場合も購入画面を表示
                    self.showPurchaseDialog(for: plan)
                }
            }
        }
    }
    
    // プラン詳細を表示
    func showPlanDetail(_ plan: VisitPlanModel) {
        
        // ローディング開始
        loadingMessage = NSLocalizedString("loading_plans", comment: "Loading plans...")
        isLoadingPlan = true
        
        // 少し遅延を入れてスムーズな遷移を演出
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.selectedPlanForNavigation = plan
            self.isLoadingPlan = false
        }
    }
    
    // 購入ダイアログを表示
    func showPurchaseDialog(for plan: VisitPlanModel) {
        
        // planToPurchaseを設定するとsheet(item:)が自動的に表示される
        planToPurchase = plan
    }
    
    func purchasePlan(_ plan: VisitPlanModel) {
        let userId = UserDefaults.standard.string(forKey: "userId") ?? UUID().uuidString
        
        // 既に購入済みかチェック
        if savedPlans.contains(where: { $0.id.uuidString == plan.id && $0.isPurchased }) {
            return
        }
        
        // プランの価格分のポイントを消費
        firebaseManager.usePoints(userId: userId, points: plan.price, reason: "プラン購入: \(plan.title)") { result in
            switch result {
            case .success:
                // 購入明細書を保存
                let receipt = PurchaseReceipt(
                    transactionType: .planPurchase,
                    amount: plan.price,
                    points: 0,
                    paymentMethod: .points,
                    description: "旅行プラン: \(plan.title)"
                )
                PurchaseReceiptManager.shared.addReceipt(receipt)
                
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
                        break
                    case .failure(_):
                        break
                    }
                    
                    DispatchQueue.main.async {
                        self.purchasedPlan = plan
                        self.showingPurchaseCompletion = true
                    }
                }
                
            case .failure(_):
                DispatchQueue.main.async {
                    // エラーメッセージを表示する処理をここに追加できます
                }
            }
        }
    }
    
    func savePurchasedPlan(_ plan: VisitPlanModel) {
        // Check if this is a draft being converted to purchased
        if savedPlans.contains(where: { $0.id.uuidString == plan.id && $0.isDraft }) {
            // This is a draft being purchased, use the conversion method
            VisitPlanDataStorage.shared.convertDraftToPurchased(planId: plan.id)
            // print("✅ Converted draft to purchased plan - ID: \(plan.id)")
        } else {
            // This is a new purchase, create new plan data
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
                isDraft: false,  // 明示的にドラフトではないことを設定
                streamingUrls: plan.streamingUrls
            )
            
            // 新しいVisitPlanDataStorageシステムを使用して保存
            VisitPlanDataStorage.shared.savePlanData(visitPlanData)
            // print("✅ Purchased plan saved using VisitPlanDataStorage - ID: \(plan.id)")
        }
        
        // 保存済みプランを再読み込み
        DispatchQueue.main.async {
            self.loadSavedPlans()
        }
    }
    
    func deleteOriginalPlan(_ plan: VisitPlanModel) {
        print("DEBUG: Deleting plan - ID: \(plan.id), Title: \(plan.title)")
        
        // VisitPlanDataStorageを使用して削除
        VisitPlanDataStorage.shared.deletePlanData(planId: plan.id)
        print("DEBUG: Deleted plan from VisitPlanDataStorage")
        
        // userOriginalPlansから削除
        userOriginalPlans.removeAll(where: { $0.id == plan.id })
        print("DEBUG: Removed plan from userOriginalPlans")
        
        // プランリストをリロードしてUIを更新
        DispatchQueue.main.async {
            self.loadSavedPlans()
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
            
            // Firebaseにも同期
            firebaseManager.savePurchasedPlanIds(userId: currentUserId, planIds: purchasedPlanIds) { result in
                switch result {
                case .success:
                    break // print("✅ Purchased plan IDs synced to Firebase")
                case .failure(_):
                    break // print("❌ Failed to sync purchased plan IDs: \(error)")
                }
            }
        }
    }
    
    // ローカル購入記録をチェック
    func checkLocalPurchaseRecord(planId: String) -> Bool {
        let purchasedPlanIds = UserDefaults.standard.stringArray(forKey: "purchasedPlanIds_\(currentUserId)") ?? []
        let isPurchased = purchasedPlanIds.contains(planId)
        return isPurchased
    }
    
    // Firebaseから購入済みプランを読み込む
    func loadPurchasedPlansFromFirebase() {
        // print("📱 Loading purchased plans from Firebase...")
        
        // 購入済みプランの同期を実行
        firebaseManager.syncPurchasedPlans(userId: currentUserId) { result in
            switch result {
            case .success:
                // print("✅ Successfully synced purchased plans")
                
                // 同期後、ローカルの購入済みプランIDを取得
                let purchasedPlanIds = UserDefaults.standard.stringArray(forKey: "purchasedPlanIds_\(self.currentUserId)") ?? []
                
                // 購入したプランをFirebaseから取得してローカルに保存
                for planId in purchasedPlanIds {
                    self.downloadAndSavePurchasedPlan(planId: planId)
                }
                
            case .failure(_):
                break // print("❌ Failed to sync purchased plans: \(error)")
            }
        }
    }
    
    // 購入済みプランをFirebaseからダウンロードしてローカルに保存
    func downloadAndSavePurchasedPlan(planId: String) {
        
        firebaseManager.database.collection("visitPlans").document(planId).getDocument { snapshot, error in
            if error != nil {
                return
            }
            
            guard let document = snapshot, document.exists,
                  let data = document.data(),
                  let plan = VisitPlanModel(dictionary: data) else {
                return
            }
            
            
            // ローカルに既に保存されているかチェック
            let existingPlan = self.savedPlans.first { $0.id.uuidString == planId }
            if existingPlan == nil {
                // ローカルに保存
                print("📥 Downloading and saving new purchased plan: \(plan.title) with ID: \(planId)")
                self.savePurchasedPlan(plan)
            } else {
                print("✅ Plan already exists locally: \(existingPlan!.title) with ID: \(planId)")
            }
        }
    }
    
    // Helper function to format plan duration for localization
    func formatPlanDuration(_ duration: String) -> String {
        // Parse Japanese duration format (e.g., "4時間", "2時間30分", "30分")
        let pattern = #"(?:(\d+)時間)?(?:(\d+)分)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: duration, options: [], range: NSRange(location: 0, length: duration.count)) else {
            return duration // Return original if parsing fails
        }
        
        var hours = 0
        var minutes = 0
        
        // Extract hours
        if match.range(at: 1).location != NSNotFound {
            let hoursRange = Range(match.range(at: 1), in: duration)!
            hours = Int(duration[hoursRange]) ?? 0
        }
        
        // Extract minutes
        if match.range(at: 2).location != NSNotFound {
            let minutesRange = Range(match.range(at: 2), in: duration)!
            minutes = Int(duration[minutesRange]) ?? 0
        }
        
        // Format using localized strings
        if hours > 0 && minutes > 0 {
            return String(format: NSLocalizedString("total_duration_hours_minutes", comment: "Total %d hours %d minutes"), hours, minutes)
        } else if hours > 0 {
            return String(format: NSLocalizedString("total_duration_hours", comment: "Total %d hours"), hours)
        } else if minutes > 0 {
            return String(format: NSLocalizedString("total_duration_minutes", comment: "Total %d minutes"), minutes)
        } else {
            // If the duration contains "計" at the beginning, try to parse it
            if duration.hasPrefix("計") {
                let cleanDuration = String(duration.dropFirst())
                return formatPlanDuration(cleanDuration)
            }
            return duration
        }
    }
    
    // 重複プランを削除する関数
    private func removeDuplicatePlans(_ plans: [VisitPlanModel]) -> [VisitPlanModel] {
        // パフォーマンス最適化: 重複チェックをDictionary使用で高速化
        var uniquePlansDict: [String: VisitPlanModel] = [:]
        var duplicateCount = 0
        
        for plan in plans {
            // IDをキーとして使用（最も信頼できる一意識別子）
            if uniquePlansDict[plan.id] == nil {
                uniquePlansDict[plan.id] = plan
            } else {
                duplicateCount += 1
            }
        }
        
        if duplicateCount > 0 {
            print("DEBUG: Removed \(duplicateCount) duplicate plans")
        }
        
        // 作成日時の降順でソート
        return Array(uniquePlansDict.values).sorted { $0.createdDate > $1.createdDate }
    }
    
    // 古いUserDefaultsデータをクリーンアップ
    private func cleanupOldUserDefaultsData() {
        // 古い "savedPlans" キーが存在する場合は削除
        if UserDefaults.standard.object(forKey: "savedPlans") != nil {
            UserDefaults.standard.removeObject(forKey: "savedPlans")
            // print("🧹 Cleaned up old UserDefaults savedPlans data")
        }
    }
    
    // 緊急修正: Test3の重複を強制的に削除
    private func emergencyCleanupTest3Duplicates() {
        // print("🚨 EMERGENCY CLEANUP: Removing duplicate purchased plans...")
        
        // UserDefaultsHelperを使用してユーザー固有のメタデータを取得
        guard let data = UserDefaultsHelper.shared.getData(forKey: "savedPlansMetadata"),
              let metadata = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
            // print("❌ No metadata found")
            return
        }
        
        print("📊 Found \(metadata.count) total plans in metadata")
        
        var cleanedMetadata: [String: [String: Any]] = [:]
        var titleTracker: [String: String] = [:] // title -> planId のマッピング
        var removedCount = 0
        
        // 各プランをチェックして、同じタイトルの重複を削除
        for (planId, planData) in metadata {
            if let title = planData["title"] as? String,
               let isPurchased = planData["isPurchased"] as? Bool,
               isPurchased {
                // 購入済みプランの場合
                if titleTracker[title] != nil {
                    // 同じタイトルのプランが既に存在する場合
                    print("🗑️ Removing duplicate purchased plan - Title: \(title), ID: \(planId)")
                    deleteplanDirectory(planId: planId)
                    removedCount += 1
                } else {
                    // 最初のプランを保持
                    titleTracker[title] = planId
                    cleanedMetadata[planId] = planData
                    print("✅ Keeping purchased plan - Title: \(title), ID: \(planId)")
                }
            } else {
                // 購入済みでないプランは全て保持
                cleanedMetadata[planId] = planData
            }
        }
        
        print("📊 Removed \(removedCount) duplicate purchased plans")
        print("📊 Final plan count: \(cleanedMetadata.count)")
        
        // クリーンなメタデータを保存
        if let cleanData = try? JSONSerialization.data(withJSONObject: cleanedMetadata) {
            UserDefaultsHelper.shared.setData(cleanData, forKey: "savedPlansMetadata")
        }
        
        // print("✅ EMERGENCY CLEANUP COMPLETE")
    }
    
    // プランディレクトリを削除
    private func deleteplanDirectory(planId: String) {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let visitPlansDirectory = documentsDirectory.appendingPathComponent("VisitPlanData")
        let planDirectory = visitPlansDirectory.appendingPathComponent(planId)
        
        do {
            if FileManager.default.fileExists(atPath: planDirectory.path) {
                try FileManager.default.removeItem(at: planDirectory)
                // print("🗑️ Deleted plan directory: \(planId)")
            }
        } catch {
            // print("❌ Failed to delete plan directory: \(error)")
        }
    }
    
}

