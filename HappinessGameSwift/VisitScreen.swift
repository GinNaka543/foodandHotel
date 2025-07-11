import SwiftUI
import Foundation
import UIKit

// VisitTypes.swiftの型を使用するための明示的なimport

public struct VisitScreen: View {
    @State private var savedPlans: [VisitPlanData] = []
    @State private var showingSelectedPlan = false
    @State private var selectedPlan: VisitPlanData?
    @State private var visitAds: [Advertisement] = []
    @StateObject private var firebaseManager = FirebaseManager.shared
    @State private var publicPlans: [VisitPlanModel] = []
    @State private var userOriginalPlans: [VisitPlanModel] = []
    @State private var currentUserId: String = UserDefaults.standard.string(forKey: "userId") ?? ""
    @State private var showingPurchaseDialog = false
    @State private var planToPurchase: VisitPlanModel?
    @State private var showNavigationMenu = false
    @EnvironmentObject var mainTab: MainTabSelection
    
    // タブ用
    enum VisitTab: String, CaseIterable {
        case all = "オール"
        case original = "オリジナル"
    }
    @State private var selectedTab: VisitTab = .all
    @State private var showSearchBar = false
    @State private var searchText = ""
    @State private var showingPlanningScreen = false
    
    public var body: some View {
        mainContent
            .fullScreenCover(isPresented: $showingPlanningScreen) {
                VisitPlanningScreen()
                    .onDisappear {
                        loadSavedPlans()
                        loadFirebasePlans()
                    }
            }
            .sheet(isPresented: $showingPurchaseDialog) {
                if let plan = planToPurchase {
                    PlanPurchaseView(plan: plan, isPresented: $showingPurchaseDialog)
                }
            }
            .fullScreenCover(isPresented: $showingSelectedPlan) {
                if let plan = selectedPlan {
                    VisitGameScreen(
                        animeName: plan.animeName,
                        duration: plan.duration,
                        planTitle: plan.title,
                        spots: plan.spots,
                        numberOfDays: plan.numberOfDays
                    )
                }
            }
            .onAppear {
                loadSavedPlans()
                loadVisitAds()
                loadFirebasePlans()
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
                        .frame(height: 233)
                    
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
                                    .frame(height: 233)
                                    .clipped()
                            case .failure(_):
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.orange)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    }
                }
                .frame(height: 233)
                .clipped()
                
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
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(plan.duration)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                        Text("\(plan.spots.count)スポット")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 8)
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
                                    .frame(height: 233)
                                    .clipped()
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
                .frame(height: 233)
                .clipped()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ad.title)
                            .font(.headline)
                            .foregroundColor(.black)
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
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 8)
        .onAppear {
            firebaseManager.recordAdImpression(advertisementId: ad.id ?? "")
        }
    }
    
    @ViewBuilder
    private var planListView: some View {
        let displayPlans = selectedTab == .all ? publicPlans : userOriginalPlans
        let combinedItems = createCombinedItems(displayPlans)
        
        if displayPlans.isEmpty && (selectedTab == .original || visitAds.isEmpty) {
            VStack(spacing: 16) {
                Image(systemName: "map")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
                Text("まだプランがありません")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                Text("右下のCreateボタンから作成してください")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 100)
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
                    // 虫眼鏡
                    if showSearchBar {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 22, weight: .regular))
                                .foregroundColor(.gray)
                            TextField("Search", text: $searchText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.black)
                            Button(action: { withAnimation { showSearchBar = false; searchText = "" } }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22, weight: .regular))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .frame(height: 38)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        Button(action: { withAnimation { showSearchBar.toggle() } }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 24, weight: .regular))
                                .foregroundColor(.black)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 28) // さらに10px上げる
                .offset(y: -10) // さらに10px上にずらす
                // タブUI
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(VisitTab.allCases, id: \.self) { tab in
                            Button(action: { selectedTab = tab }) {
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
                    VStack(spacing: 24) {
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
                            .fill(Color.purple)
                    )
            }
            .padding(.bottom, 24)
            .padding(.trailing, 20)
        }
        .navigationBarHidden(true)
        .overlay(
            Group {
                if showNavigationMenu {
                    NavigationMenuView(isPresented: $showNavigationMenu)
                        .transition(.opacity)
                        .zIndex(2)
                }
            }
        )
        }
    }
    
    func loadSavedPlans() {
        print("DEBUG: loadSavedPlans開始")
        guard let data = UserDefaults.standard.data(forKey: "visitPlans") else {
            print("DEBUG: UserDefaultsにデータがありません")
            return
        }
        
        do {
            let plans = try JSONDecoder().decode([VisitPlanData].self, from: data)
            savedPlans = plans
            print("DEBUG: \(plans.count)個のプランを読み込みました")
            for plan in plans {
                print("DEBUG: プラン: \(plan.title), スポット数: \(plan.spots.count)")
            }
        } catch {
            print("DEBUG: デコードエラー: \(error)")
        }
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
                
            case .failure(let error):
                print("❌ ビジット広告取得エラー: \(error)")
            }
        }
    }
    
    func createCombinedItems(_ plans: [VisitPlanModel]) -> [Any] {
        var items: [Any] = []
        
        // オールタブの場合のみ広告を表示
        if selectedTab == .all && !visitAds.isEmpty {
            items.append(visitAds[0])
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
        // 公開プランを取得
        firebaseManager.fetchPublicPlans { result in
            switch result {
            case .success(let plans):
                self.publicPlans = plans
            case .failure(let error):
                print("公開プラン取得エラー: \(error)")
            }
        }
        
        // ユーザーのプランを取得
        if !currentUserId.isEmpty {
            firebaseManager.fetchUserPlans(userId: currentUserId) { result in
                switch result {
                case .success(let plans):
                    self.userOriginalPlans = plans
                case .failure(let error):
                    print("ユーザープラン取得エラー: \(error)")
                }
            }
        }
    }
    
    // プランの購入状態をチェックして表示
    func checkAndShowPlan(_ plan: VisitPlanModel) {
        // 自分のプランか、無料プランの場合は直接表示
        if plan.userId == currentUserId || plan.price == 0 {
            showPlanDetail(plan)
            return
        }
        
        // 購入済みかチェック
        firebaseManager.checkPlanPurchased(userId: currentUserId, planId: plan.id) { result in
            switch result {
            case .success(let isPurchased):
                if isPurchased {
                    self.showPlanDetail(plan)
                } else {
                    // 購入画面を表示
                    self.showPurchaseDialog(for: plan)
                }
            case .failure(let error):
                print("購入チェックエラー: \(error)")
            }
        }
    }
    
    // プラン詳細を表示
    func showPlanDetail(_ plan: VisitPlanModel) {
        // VisitPlanModelをVisitPlanDataに変換
        let visitPlanData = VisitPlanData(
            id: UUID(uuidString: plan.id) ?? UUID(),
            animeName: plan.animeName,
            title: plan.title,
            duration: plan.duration,
            spots: plan.spots,
            thumbnailData: nil,
            createdDate: plan.createdDate,
            startTime: plan.startTime,
            numberOfDays: plan.numberOfDays
        )
        self.selectedPlan = visitPlanData
        self.showingSelectedPlan = true
    }
    
    // 購入ダイアログを表示
    func showPurchaseDialog(for plan: VisitPlanModel) {
        planToPurchase = plan
        showingPurchaseDialog = true
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




