import SwiftUI
import Foundation

// iPad専用のビジットスクリーン
struct VisitScreen_iPad: View {
    @State private var savedPlans: [VisitPlanData] = []
    @State private var selectedPlan: VisitPlanData?
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
    @State private var loadingMessage = NSLocalizedString("loading_plans", comment: "Loading plans")
    @EnvironmentObject var mainTab: MainTabSelection
    
    // タブ用
    enum VisitTab: String, CaseIterable {
        case all
        case original
        case purchased
        
        var localizedString: String {
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
    
    var body: some View {
        mainView
    }
    
    private var mainView: some View {
        NavigationView {
            sidebarView
            mainContentView
        }
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
    }
    
    private var sidebarView: some View {
        List {
                Section(NSLocalizedString("filter_section", comment: "Filter section")) {
                    ForEach(VisitTab.allCases, id: \.self) { tab in
                        Button(action: {
                            selectedTab = tab
                        }) {
                            HStack {
                                Image(systemName: tab == .all ? "square.grid.2x2" : 
                                                 tab == .original ? "person.fill" : "cart.fill")
                                    .foregroundColor(selectedTab == tab ? .purple : .gray)
                                    .frame(width: 20)
                                Text(tab.localizedString)
                                    .foregroundColor(selectedTab == tab ? .primary : .secondary)
                                Spacer()
                                if selectedTab == tab {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.purple)
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Section(NSLocalizedString("action_section", comment: "Action section")) {
                    Button(action: {
                        showingPlanningScreen = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.purple)
                                .frame(width: 20)
                            Text(NSLocalizedString("create_new_plan", comment: "Create new plan"))
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 250)
            .navigationTitle(NSLocalizedString("visit", comment: "Visit"))
    }
    
    private var mainContentView: some View {
        ZStack {
            VStack(spacing: 0) {
                // 検索バー
                HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField(NSLocalizedString("search_by_title_or_anime", comment: "Search by title or anime"), text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            activeSearchText = searchText
                        }
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            activeSearchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                Button(action: {
                    activeSearchText = searchText
                }) {
                    Text(NSLocalizedString("search_button", comment: "Search"))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.black)
                        .cornerRadius(8)
                }
            }
            .padding()
            
            // グリッドレイアウト
            ScrollView {
                    let displayPlans = getDisplayPlans()
                    
                    if displayPlans.isEmpty {
                        // 空の状態
                        VStack(spacing: 20) {
                            Image(systemName: "map")
                                .font(.system(size: 60))
                                .foregroundColor(.purple.opacity(0.5))
                            
                            Text(selectedTab == .purchased ? NSLocalizedString("no_purchased_plans", comment: "No purchased plans") : 
                                 selectedTab == .original ? NSLocalizedString("create_original_plan", comment: "Create original plan") : 
                                 NSLocalizedString("no_plans_yet", comment: "No plans yet"))
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            if selectedTab == .original {
                                Text(NSLocalizedString("create_anime_pilgrimage_plan", comment: "Create anime pilgrimage plan"))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 400)
                                
                                Button(action: {
                                    showingPlanningScreen = true
                                }) {
                                    Label(NSLocalizedString("add_original_plan", comment: "Add original plan"), systemImage: "plus")
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color(red: 0.6, green: 0.4, blue: 0.9), 
                                                                          Color(red: 0.8, green: 0.5, blue: 0.9)]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(25)
                                }
                                .padding(.top)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 20)
                        ], spacing: 20) {
                            ForEach(displayPlans) { plan in
                                planCard_iPad(for: plan)
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Color(.systemGray6))
            
            // オールタブとオリジナルタブの時に右下に固定ボタンを表示
            if selectedTab == .all || selectedTab == .original {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showingPlanningScreen = true
                        }) {
                            HStack {
                                Image(systemName: "map.fill")
                                Text(NSLocalizedString("plan_pilgrimage", comment: "Plan a pilgrimage"))
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(red: 0.6, green: 0.4, blue: 0.9), 
                                                              Color(red: 0.8, green: 0.5, blue: 0.9)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(30)
                            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .padding(.trailing, 30)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .onAppear {
            loadSavedPlans()
            loadFirebasePlans()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ReloadVisitPlans"))) { _ in
            print("DEBUG: Received reload notification")
            DispatchQueue.main.async {
                loadSavedPlans()
            }
        }
        .fullScreenCover(isPresented: $showingPlanningScreen, onDismiss: {
            // 画面が閉じられたときにプランをリロードし、オリジナルタブに移動
            print("DEBUG: Planning screen dismissed, reloading plans")
            selectedDraftPlan = nil // 選択をクリア
            selectedTab = .original // オリジナルタブに移動
            DispatchQueue.main.async {
                loadSavedPlans()
            }
        }) {
            if let draft = selectedDraftPlan {
                VisitPlanningScreen(editingDraft: draft)
            } else {
                VisitPlanningScreen()
            }
        }
        .alert(NSLocalizedString("delete_plan", comment: "Delete plan"), isPresented: $showingDeleteConfirmation, presenting: planToDelete) { plan in
            Button(NSLocalizedString("cancel", comment: "Cancel"), role: .cancel) {
                planToDelete = nil
            }
            Button(NSLocalizedString("delete", comment: "Delete"), role: .destructive) {
                deletePlan(plan)
                planToDelete = nil
            }
        } message: { plan in
            Text(String(format: NSLocalizedString("delete_plan_confirmation", comment: "Are you sure you want to delete '%@'?"), plan.title))
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
                onClose: {
                    selectedPlanForNavigation = nil
                },
                planId: UUID(uuidString: plan.id),
                isReadOnly: true,
                streamingUrls: plan.streamingUrls,
                thumbnailUrl: plan.thumbnailUrl
            )
        }
    }
    
    @ViewBuilder
    private func planCard_iPad(for plan: VisitPlanModel) -> some View {
        planCardContent(for: plan)
            .onTapGesture {
                handlePlanTap(plan)
            }
    }
    
    private func handlePlanTap(_ plan: VisitPlanModel) {
        if plan.isDraft {
            selectedDraftPlan = savedPlans.first(where: { $0.id.uuidString == plan.id })
            showingPlanningScreen = true
        } else if plan.price > 0 && !purchasedPlans.contains(where: { $0.id == plan.id }) {
            planToPurchase = plan
        } else {
            selectedPlanForNavigation = plan
        }
    }
    
    @ViewBuilder
    private func thumbnailImage(for plan: VisitPlanModel) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if let thumbnailUrl = plan.thumbnailUrl,
               let url = URL(string: thumbnailUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure(_):
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            )
                    case .empty:
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .overlay(
                                ProgressView()
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Rectangle()
                    .fill(Color(.systemGray4))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    )
            }
        }
    }
    
    @ViewBuilder
    private func planCardContent(for plan: VisitPlanModel) -> some View {
            VStack(alignment: .leading, spacing: 0) {
                // サムネイル画像
                thumbnailImage(for: plan)
                .frame(height: 200)
                .clipped()
                .overlay(
                    // バッジ表示
                    Group {
                        if plan.isDraft {
                            Text(NSLocalizedString("draft", comment: "Draft"))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange)
                                .cornerRadius(8)
                        } else if selectedTab == .purchased {
                            Text(NSLocalizedString("purchased", comment: "Purchased"))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .cornerRadius(8)
                        } else if plan.price == 0 {
                            Text(selectedTab == .original ? NSLocalizedString("original", comment: "Original") : NSLocalizedString("free", comment: "Free"))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(selectedTab == .original ? Color.purple : Color.green)
                                .cornerRadius(8)
                        }
                    }
                    .padding(8),
                    alignment: .bottomTrailing
                )
                .overlay(
                    // PRバッジ
                    Group {
                        if plan.userId == "admin" && selectedTab == .all {
                            Text("PR")
                                .font(.caption2)
                                .fontWeight(.bold)
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
                VStack(alignment: .leading, spacing: 8) {
                    Text(plan.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    HStack {
                        Label(plan.animeName, systemImage: "tv")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if selectedTab == .original {
                            Button(action: {
                                planToDelete = plan
                                showingDeleteConfirmation = true
                            }) {
                                Image(systemName: "ellipsis")
                                    .foregroundColor(.gray)
                                    .padding(8)
                                    .background(Color.white.opacity(0.8))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(plan.duration)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                Text(String(format: NSLocalizedString("spots_format", comment: "Spots count"), plan.spots.count))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    
    // 以下、必要な関数をVisitScreenからコピー
    private func getDisplayPlans() -> [VisitPlanModel] {
        let plans: [VisitPlanModel]
        
        switch selectedTab {
        case .all:
            // オールタブでは言語フィルタリングを適用（管理者設定言語 vs アプリ言語）
            let currentAppLanguage = LocalizationManager.shared.currentLanguage.rawValue
            print("DEBUG: getDisplayPlans_iPad - Current app language: \(currentAppLanguage)")
            print("DEBUG: getDisplayPlans_iPad - Total publicPlans: \(publicPlans.count)")
            
            plans = publicPlans.filter { plan in
                // 管理者プランの場合、設定された言語とアプリ言語を比較
                if plan.userId == "admin" {
                    print("DEBUG: getDisplayPlans_iPad - Admin plan: '\(plan.title)' language: \(plan.language ?? "nil")")
                    
                    // 言語が設定されていない場合は表示しない（管理者は言語を明示的に設定する必要がある）
                    guard let planLanguage = plan.language, !planLanguage.isEmpty else {
                        print("DEBUG: getDisplayPlans_iPad - Plan '\(plan.title)' has no language, not showing")
                        return false
                    }
                    
                    // 中国語の場合は zh と zh-Hans 両方をサポート（後方互換性）
                    if currentAppLanguage == "zh-Hans" && planLanguage == "zh" {
                        print("DEBUG: getDisplayPlans_iPad - Plan '\(plan.title)' matches zh->zh-Hans compatibility")
                        return true
                    }
                    
                    // 管理者設定言語 == アプリ言語の場合に表示
                    let shouldShow = planLanguage == currentAppLanguage
                    print("DEBUG: getDisplayPlans_iPad - Plan '\(plan.title)' - planLang: \(planLanguage), appLang: \(currentAppLanguage), showing: \(shouldShow)")
                    return shouldShow
                }
                // 一般ユーザーのプランはすべて表示
                print("DEBUG: getDisplayPlans_iPad - User plan: '\(plan.title)' - showing")
                return true
            }
            print("DEBUG: getDisplayPlans_iPad - Filtered to \(plans.count) plans from \(publicPlans.count)")
        case .original:
            plans = userOriginalPlans
        case .purchased:
            plans = purchasedPlans
        }
        
        // 表示時の最終重複チェック
        let uniquePlans = removeDuplicatePlans(plans)
        print("DEBUG: getDisplayPlans - Tab: \(selectedTab), Original: \(plans.count), After dedup: \(uniquePlans.count)")
        return uniquePlans
    }
    
    
    private func loadSavedPlans() {
        print("DEBUG: loadSavedPlans called")
        guard let data = UserDefaultsHelper.shared.getData(forKey: "savedPlans") else {
            print("DEBUG: No saved plans data found")
            savedPlans = []
            userOriginalPlans = []
            return
        }
        
        do {
            let plans = try JSONDecoder().decode([VisitPlanData].self, from: data)
            savedPlans = plans
            print("DEBUG: Loaded \(plans.count) saved plans")
            
            let originalPlans = plans.filter { !$0.isPurchased }
            print("DEBUG: Found \(originalPlans.count) original plans (non-purchased)")
            userOriginalPlans = originalPlans.sorted(by: { $0.createdDate > $1.createdDate }).map { plan in
                print("DEBUG: Processing plan - Title: \(plan.title), isDraft: \(plan.isDraft)")
                return VisitPlanModel(
                    id: plan.id.uuidString,
                    userId: currentUserId,
                    animeName: plan.animeName,
                    title: plan.title,
                    description: "",
                    duration: plan.duration,
                    spots: plan.spots,
                    thumbnailUrl: plan.thumbnailUrl,
                    price: 0,
                    budget: 0,
                    createdDate: plan.createdDate,
                    startTime: plan.startTime,
                    numberOfDays: plan.numberOfDays,
                    totalCost: plan.totalCost,
                    isPublic: false,
                    purchasedBy: [],
                    createdAt: plan.createdDate,
                    updatedAt: plan.createdDate,
                    isDraft: plan.isDraft,
                    isConfirmed: nil,
                    streamingUrls: plan.streamingUrls
                )
            }
            
            // 重複削除を適用
            userOriginalPlans = removeDuplicatePlans(userOriginalPlans)
            print("DEBUG: userOriginalPlans updated with \(userOriginalPlans.count) plans after deduplication")
            
            // ローカルの購入済みプランの処理
            let localPurchasedPlansData = plans.filter { $0.isPurchased }
            print("DEBUG: Local purchased plans count: \(localPurchasedPlansData.count)")
            
            let localPurchasedPlans = localPurchasedPlansData.sorted(by: { $0.createdDate > $1.createdDate }).map { plan in
                return VisitPlanModel(
                    id: plan.id.uuidString,
                    userId: currentUserId,
                    animeName: plan.animeName,
                    title: plan.title,
                    description: "",
                    duration: plan.duration,
                    spots: plan.spots,
                    thumbnailUrl: plan.thumbnailUrl,
                    price: 0, // 既に購入済みなので価格は0
                    budget: 0,
                    createdDate: plan.createdDate,
                    startTime: plan.startTime,
                    numberOfDays: plan.numberOfDays,
                    totalCost: plan.totalCost,
                    isPublic: false,
                    purchasedBy: [currentUserId],
                    createdAt: plan.createdDate,
                    updatedAt: plan.createdDate,
                    isDraft: plan.isDraft,
                    isConfirmed: nil,
                    streamingUrls: plan.streamingUrls
                )
            }
            
            // ローカルの購入済みプランを既存の購入済みプランとマージ（重複防止）
            for localPlan in localPurchasedPlans {
                if !purchasedPlans.contains(where: { $0.id == localPlan.id }) {
                    purchasedPlans.append(localPlan)
                }
            }
            purchasedPlans = purchasedPlans.sorted(by: { $0.createdAt > $1.createdAt })
            
            // 重複削除を適用
            purchasedPlans = removeDuplicatePlans(purchasedPlans)
            print("DEBUG: Total purchased plans after local merge and deduplication: \(purchasedPlans.count)")
        } catch {
            savedPlans = []
            userOriginalPlans = []
            purchasedPlans = []
        }
    }
    
    private func loadFirebasePlans() {
        FirebaseManager.shared.fetchPublicPlans { result in
            switch result {
            case .success(let plans):
                // ドラフトでないプランのみを取得（言語フィルタリングはgetDisplayPlans()で行う）
                self.publicPlans = plans.filter { !$0.isDraft }
                    .sorted(by: { $0.createdAt > $1.createdAt })
                
                // 購入済みプランの読み込み
                if let purchasedData = UserDefaultsHelper.shared.getData(forKey: "purchasedPlans"),
                   let purchasedIds = try? JSONDecoder().decode([String].self, from: purchasedData) {
                    let firebasePurchasedPlans = plans.filter { purchasedIds.contains($0.id) }
                    print("DEBUG: Firebase purchased plans count: \(firebasePurchasedPlans.count)")
                    
                    // ローカルの購入済みプランとマージ（重複を防ぐ）
                    var allPurchasedPlans = self.purchasedPlans
                    for plan in firebasePurchasedPlans {
                        if !allPurchasedPlans.contains(where: { $0.id == plan.id }) {
                            allPurchasedPlans.append(plan)
                        }
                    }
                    self.purchasedPlans = allPurchasedPlans.sorted(by: { $0.createdAt > $1.createdAt })
                    
                    // 重複削除を適用
                    self.purchasedPlans = self.removeDuplicatePlans(self.purchasedPlans)
                    print("DEBUG: Total purchased plans after merge and deduplication: \(self.purchasedPlans.count)")
                }
            case .failure(_):
                break
            }
        }
    }
    
    
    private func purchasePlan(_ plan: VisitPlanModel) {
        print("DEBUG: Purchasing plan - ID: \(plan.id), Title: \(plan.title)")
        
        // 購入処理の実装
        var purchasedIds = [String]()
        if let data = UserDefaultsHelper.shared.getData(forKey: "purchasedPlans"),
           let existingIds = try? JSONDecoder().decode([String].self, from: data) {
            purchasedIds = existingIds
        }
        
        print("DEBUG: Current purchased IDs: \(purchasedIds)")
        
        if !purchasedIds.contains(plan.id) {
            purchasedIds.append(plan.id)
            if let encoded = try? JSONEncoder().encode(purchasedIds) {
                UserDefaultsHelper.shared.setData(encoded, forKey: "purchasedPlans")
                print("DEBUG: Added plan ID to purchased list")
            }
        } else {
            print("DEBUG: Plan already purchased")
        }
        
        purchasedPlan = plan
        showingPurchaseCompletion = true
        
        // 購入後にFirebaseプランをリロード
        loadFirebasePlans()
    }
    
    private func deletePlan(_ plan: VisitPlanModel) {
        print("DEBUG: Deleting plan - ID: \(plan.id), Title: \(plan.title)")
        
        // ローカルの保存済みプランから削除
        var savedPlans = getSavedPlans()
        if let index = savedPlans.firstIndex(where: { $0.id.uuidString == plan.id }) {
            savedPlans.remove(at: index)
            print("DEBUG: Removed plan from saved plans at index \(index)")
            
            if let encoded = try? JSONEncoder().encode(savedPlans) {
                UserDefaultsHelper.shared.setData(encoded, forKey: "savedPlans")
                print("DEBUG: Successfully saved updated plans to UserDefaults")
                
                // UIをリロード
                DispatchQueue.main.async {
                    loadSavedPlans()
                }
            }
        } else {
            print("DEBUG: Plan not found in saved plans")
        }
    }
    
    private func getSavedPlans() -> [VisitPlanData] {
        guard let data = UserDefaultsHelper.shared.getData(forKey: "savedPlans"),
              let plans = try? JSONDecoder().decode([VisitPlanData].self, from: data) else {
            return []
        }
        return plans
    }
    
    // 重複プランを削除する関数
    private func removeDuplicatePlans(_ plans: [VisitPlanModel]) -> [VisitPlanModel] {
        var uniquePlans: [VisitPlanModel] = []
        var seenPlanIds: Set<String> = []
        var seenPlanKeys: Set<String> = []
        
        for plan in plans {
            // まずIDで重複チェック
            if seenPlanIds.contains(plan.id) {
                print("DEBUG: Removed duplicate plan by ID - Title: \(plan.title), ID: \(plan.id)")
                continue
            }
            
            // タイトル、アニメ名、作成日で重複判定
            let planKey = "\(plan.title)_\(plan.animeName)_\(plan.createdDate.timeIntervalSince1970)"
            if seenPlanKeys.contains(planKey) {
                print("DEBUG: Removed duplicate plan by content - Title: \(plan.title), Key: \(planKey)")
                continue
            }
            
            // 重複でない場合は追加
            seenPlanIds.insert(plan.id)
            seenPlanKeys.insert(planKey)
            uniquePlans.append(plan)
            print("DEBUG: Added unique plan - Title: \(plan.title), ID: \(plan.id)")
        }
        
        print("DEBUG: Removed \(plans.count - uniquePlans.count) duplicate plans")
        return uniquePlans
    }
    
}