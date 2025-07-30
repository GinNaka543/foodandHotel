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
            
            // オールタブの時に右下に固定ボタンを表示
            if selectedTab == .all {
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
        .fullScreenCover(isPresented: $showingPlanningScreen) {
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
        Button(action: {
            handlePlanTap(plan)
        }) {
            planCardContent(for: plan)
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
                            }
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
        switch selectedTab {
        case .all:
            // オールタブでは言語フィルタリングを適用
            return publicPlans.filter { plan in
                LanguageDetector.shared.isTitleMatchingCurrentLanguage(plan.title)
            }
        case .original:
            return userOriginalPlans
        case .purchased:
            return purchasedPlans
        }
    }
    
    
    private func loadSavedPlans() {
        guard let data = UserDefaultsHelper.shared.getData(forKey: "savedPlans") else {
            savedPlans = []
            userOriginalPlans = []
            return
        }
        
        do {
            let plans = try JSONDecoder().decode([VisitPlanData].self, from: data)
            savedPlans = plans
            
            let originalPlans = plans.filter { !$0.isPurchased }
            userOriginalPlans = originalPlans.sorted(by: { $0.createdDate > $1.createdDate }).map { plan in
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
            
            // 購入済みプランの処理を追加
            let purchasedPlansData = plans.filter { $0.isPurchased }
            purchasedPlans = purchasedPlansData.sorted(by: { $0.createdDate > $1.createdDate }).map { plan in
                VisitPlanModel(
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
                self.publicPlans = plans.filter { !$0.isDraft }
                    .sorted(by: { $0.createdAt > $1.createdAt })
                
                // 購入済みプランの読み込み
                if let purchasedData = UserDefaultsHelper.shared.getData(forKey: "purchasedPlans"),
                   let purchasedIds = try? JSONDecoder().decode([String].self, from: purchasedData) {
                    self.purchasedPlans = plans.filter { purchasedIds.contains($0.id) }
                }
            case .failure(_):
                break
            }
        }
    }
    
    
    private func purchasePlan(_ plan: VisitPlanModel) {
        // 購入処理の実装
        var purchasedIds = [String]()
        if let data = UserDefaultsHelper.shared.getData(forKey: "purchasedPlans"),
           let existingIds = try? JSONDecoder().decode([String].self, from: data) {
            purchasedIds = existingIds
        }
        
        if !purchasedIds.contains(plan.id) {
            purchasedIds.append(plan.id)
            if let encoded = try? JSONEncoder().encode(purchasedIds) {
                UserDefaultsHelper.shared.setData(encoded, forKey: "purchasedPlans")
            }
        }
        
        purchasedPlan = plan
        showingPurchaseCompletion = true
        loadFirebasePlans()
    }
}