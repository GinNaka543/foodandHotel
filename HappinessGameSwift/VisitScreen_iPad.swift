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
    @State private var showLoadingOverlay = false
    @State private var loadingDraftTitle = ""
    @State private var showingCurrencySelection = false
    @State private var selectedPlanCurrency = CurrencyManager.shared.selectedCurrency
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
        mainViewWithOverlay
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
                        showingCurrencySelection = true
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
                                    showingCurrencySelection = true
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
                            showingCurrencySelection = true
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
                isReadOnly: false,
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
            print("DEBUG: handlePlanTap - Draft plan tapped: \(plan.id)")
            
            // ローディング開始
            showLoadingOverlay = true
            loadingDraftTitle = plan.title
            
            // 少し遅延を入れてローディング画面を表示
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // VisitPlanDataStorageから最新データを読み込む
                if let freshDraft = VisitPlanDataStorage.shared.loadPlanData(planId: plan.id, isDraft: true) {
                    print("DEBUG: handlePlanTap - Loaded fresh draft: \(freshDraft.title), spots: \(freshDraft.spots.count)")
                    self.selectedDraftPlan = freshDraft
                    
                    // さらに少し遅延を入れて確実にデータを設定
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.showLoadingOverlay = false
                        self.showingPlanningScreen = true
                    }
                } else {
                    // フォールバック: savedPlansから検索
                    if let draftData = self.savedPlans.first(where: { $0.id.uuidString == plan.id }) {
                        print("DEBUG: handlePlanTap - Found draft in savedPlans: \(draftData.title), spots: \(draftData.spots.count)")
                        self.selectedDraftPlan = draftData
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.showLoadingOverlay = false
                            self.showingPlanningScreen = true
                        }
                    } else {
                        print("DEBUG: handlePlanTap - Draft not found, reloading all plans...")
                        // データが見つからない場合は再読み込み
                        self.loadSavedPlans()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if let draftData = self.savedPlans.first(where: { $0.id.uuidString == plan.id }) {
                                print("DEBUG: handlePlanTap - Found draft after reload: \(draftData.title), spots: \(draftData.spots.count)")
                                self.selectedDraftPlan = draftData
                                self.showLoadingOverlay = false
                                self.showingPlanningScreen = true
                            } else {
                                print("DEBUG: handlePlanTap - Draft still not found after reload!")
                                self.showLoadingOverlay = false
                            }
                        }
                    }
                }
            }
        } else if plan.price > 0 && !purchasedPlans.contains(where: { $0.id == plan.id }) {
            planToPurchase = plan
        } else {
            selectedPlanForNavigation = plan
        }
    }
    
    @ViewBuilder
    private func thumbnailImage(for plan: VisitPlanModel) -> some View {
        ZStack(alignment: .bottomTrailing) {
            // まずローカルのサムネイルデータをチェック
            if let savedPlan = savedPlans.first(where: { $0.id.uuidString == plan.id }) {
                // VisitPlanDataStorageから最新のデータを読み込む
                if let planData = VisitPlanDataStorage.shared.loadPlanData(planId: plan.id, isDraft: plan.isDraft),
                   let thumbnailData = planData.thumbnailData,
                   let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else if let thumbnailData = VisitPlanStorage.shared.loadPlanThumbnail(planId: plan.id),
                          let uiImage = UIImage(data: thumbnailData) {
                    // VisitPlanStorageからの読み込み（フォールバック）
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else if let thumbnailUrl = plan.thumbnailUrl,
                          let url = URL(string: thumbnailUrl) {
                    // URLからの読み込み（最後の手段）
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
            } else if let thumbnailUrl = plan.thumbnailUrl,
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
        
        // 新しいVisitPlanDataStorageシステムから読み込み
        let allSavedPlans = VisitPlanDataStorage.shared.loadAllSavedPlans()
        let allDraftPlans = VisitPlanDataStorage.shared.loadAllDraftPlans()
        
        // デバッグ: ドラフトプランの詳細を出力
        for draft in allDraftPlans {
            print("DEBUG: Draft plan - ID: \(draft.id), Title: \(draft.title), Spots count: \(draft.spots.count)")
            if draft.spots.isEmpty {
                print("DEBUG: WARNING - Draft has no spots!")
            }
        }
        
        // ドラフトと保存済みプランを結合
        let combinedPlans = allSavedPlans + allDraftPlans
        savedPlans = combinedPlans
        print("DEBUG: Loaded \(allSavedPlans.count) saved plans and \(allDraftPlans.count) draft plans")
        
        // 購入されていないプラン（ユーザーのオリジナルプラン）を抽出
        let originalPlans = combinedPlans.filter { !$0.isPurchased }
        print("DEBUG: Found \(originalPlans.count) original plans (non-purchased)")
        
        userOriginalPlans = originalPlans.sorted(by: { $0.createdDate > $1.createdDate }).map { plan in
            print("DEBUG: Processing plan - Title: \(plan.title), isDraft: \(plan.isDraft), hasThumbnailData: \(plan.thumbnailData != nil), thumbnailUrl: \(plan.thumbnailUrl ?? "nil")")
            
            // ローカルプランの場合、サムネイルが存在することを示すダミーURLを設定
            let thumbnailUrlToUse = plan.thumbnailUrl ?? (plan.thumbnailData != nil ? "local://\(plan.id.uuidString)" : nil)
            
            return VisitPlanModel(
                id: plan.id.uuidString,
                userId: currentUserId,
                animeName: plan.animeName,
                title: plan.title,
                description: "",
                duration: plan.duration,
                spots: plan.spots,
                thumbnailUrl: thumbnailUrlToUse,
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
        let localPurchasedPlansData = combinedPlans.filter { $0.isPurchased }
        print("DEBUG: Local purchased plans count: \(localPurchasedPlansData.count)")
        
        let localPurchasedPlans = localPurchasedPlansData.sorted(by: { $0.createdDate > $1.createdDate }).map { plan in
            // ローカルプランの場合、サムネイルが存在することを示すダミーURLを設定
            let thumbnailUrlToUse = plan.thumbnailUrl ?? (plan.thumbnailData != nil ? "local://\(plan.id.uuidString)" : nil)
            
            return VisitPlanModel(
                id: plan.id.uuidString,
                userId: currentUserId,
                animeName: plan.animeName,
                title: plan.title,
                description: "",
                duration: plan.duration,
                spots: plan.spots,
                thumbnailUrl: thumbnailUrlToUse,
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
                    
                    DispatchQueue.main.async {
                        self.purchasedPlan = plan
                        self.showingPurchaseCompletion = true
                        // 購入後にFirebaseプランをリロード
                        self.loadFirebasePlans()
                    }
                }
                
            case .failure(_):
                DispatchQueue.main.async {
                    // エラーメッセージを表示する処理をここに追加できます
                }
            }
        }
    }
    
    private func deletePlan(_ plan: VisitPlanModel) {
        print("DEBUG: Deleting plan - ID: \(plan.id), Title: \(plan.title)")
        
        // 新しいVisitPlanDataStorageシステムを使用して削除
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
    
    private func getSavedPlans() -> [VisitPlanData] {
        // 新しいVisitPlanDataStorageシステムから読み込み
        let allSavedPlans = VisitPlanDataStorage.shared.loadAllSavedPlans()
        let allDraftPlans = VisitPlanDataStorage.shared.loadAllDraftPlans()
        return allSavedPlans + allDraftPlans
    }
    
    func savePurchasedPlan(_ plan: VisitPlanModel) {
        // Check if this is a draft being converted to purchased
        if let existingPlan = savedPlans.first(where: { $0.id.uuidString == plan.id && $0.isDraft }) {
            // This is a draft being purchased, use the conversion method
            VisitPlanDataStorage.shared.convertDraftToPurchased(planId: plan.id)
            print("✅ Converted draft to purchased plan - ID: \(plan.id)")
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
            print("✅ Purchased plan saved using VisitPlanDataStorage - ID: \(plan.id)")
        }
        
        // 保存済みプランを再読み込み
        DispatchQueue.main.async {
            self.loadSavedPlans()
        }
    }
    
    func saveLocalPurchaseRecord(planId: String) {
        var purchasedIds = [String]()
        if let data = UserDefaultsHelper.shared.getData(forKey: "purchasedPlans"),
           let existingIds = try? JSONDecoder().decode([String].self, from: data) {
            purchasedIds = existingIds
        }
        
        if !purchasedIds.contains(planId) {
            purchasedIds.append(planId)
            if let encoded = try? JSONEncoder().encode(purchasedIds) {
                UserDefaultsHelper.shared.setData(encoded, forKey: "purchasedPlans")
            }
        }
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
    
    // ローディングオーバーレイを表示するための修正
    private var mainViewWithOverlay: some View {
        mainView
            .overlay(
                // ローディングオーバーレイ
                Group {
                    if showLoadingOverlay {
                        ZStack {
                            Color.black.opacity(0.5)
                                .edgesIgnoringSafeArea(.all)
                            
                            VStack(spacing: 20) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                                
                                Text(NSLocalizedString("loading_draft", comment: "Loading draft..."))
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                
                                if !loadingDraftTitle.isEmpty {
                                    Text(loadingDraftTitle)
                                        .font(.system(size: 16))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .padding(40)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemGray6))
                                    .shadow(radius: 10)
                            )
                        }
                    }
                }
            )
    }
}