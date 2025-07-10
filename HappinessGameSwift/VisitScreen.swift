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
    
    // タブ用
    enum VisitTab: String, CaseIterable {
        case all = "ALL"
        case original = "Original"
        case date = "Date"
        case animePilgrimage = "Anime pilgrimage"
        case city = "City"
        case onsen = "Onsen"
    }
    @State private var selectedTab: VisitTab = .all
    @State private var showSearchBar = false
    @State private var searchText = ""
    @State private var showingPlanningScreen = false
    
    public var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Button(action: { /* メニュー表示など */ }) {
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
                        // 広告とプランを交互に表示
                        let combinedItems = createCombinedItems()
                        
                        if savedPlans.isEmpty && visitAds.isEmpty {
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
                                if let plan = item as? VisitPlanData {
                                NavigationLink(destination: 
                                    VisitGameScreen(
                                        animeName: plan.animeName,
                                        duration: plan.duration,
                                        planTitle: plan.title,
                                        spots: plan.spots,
                                        numberOfDays: plan.numberOfDays
                                    )
                                    .navigationBarHidden(true)
                                ) {
                                    VStack(alignment: .leading, spacing: 0) {
                                        GeometryReader { geometry in
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 0)
                                                    .fill(Color.white)
                                                    .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                                                
                                                if let thumbnailData = plan.thumbnailData,
                                                   let uiImage = UIImage(data: thumbnailData) {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: geometry.size.width, height: 233)
                                                        .clipped()
                                                } else {
                                                    Rectangle()
                                                        .fill(Color(.systemGray5))
                                                        .overlay(
                                                            Image(systemName: "photo")
                                                                .font(.system(size: 40))
                                                                .foregroundColor(.gray)
                                                        )
                                                }
                                            }
                                            .frame(width: geometry.size.width, height: 233)
                                            .clipped()
                                            .padding(.bottom, 0)
                                        }
                                        .frame(height: 233)
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
                                } else if let ad = item as? Advertisement {
                                    // 広告カード
                                    Button(action: {
                                        if let url = URL(string: ad.linkURL) {
                                            firebaseManager.recordAdClick(advertisementId: ad.id ?? "")
                                            UIApplication.shared.open(url)
                                        }
                                    }) {
                                        VStack(alignment: .leading, spacing: 0) {
                                            GeometryReader { geometry in
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 0)
                                                        .fill(Color.white)
                                                        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                                                    
                                                    AsyncImage(url: URL(string: convertGitHubUrl(ad.imageURL))) { image in
                                                        image
                                                            .resizable()
                                                            .scaledToFill()
                                                            .frame(width: geometry.size.width, height: 233)
                                                            .clipped()
                                                    } placeholder: {
                                                        Rectangle()
                                                            .fill(Color(.systemGray5))
                                                            .overlay(
                                                                Image(systemName: "photo")
                                                                    .font(.system(size: 40))
                                                                    .foregroundColor(.gray)
                                                            )
                                                    }
                                                    
                                                    // 広告インジケーター
                                                    VStack {
                                                        HStack {
                                                            Spacer()
                                                            Text("AD")
                                                                .font(.system(size: 10, weight: .semibold))
                                                                .foregroundColor(.white)
                                                                .padding(.horizontal, 6)
                                                                .padding(.vertical, 2)
                                                                .background(Color.black.opacity(0.6))
                                                                .cornerRadius(4)
                                                                .padding(8)
                                                        }
                                                        Spacer()
                                                    }
                                                }
                                                .frame(width: geometry.size.width, height: 233)
                                                .clipped()
                                                .padding(.bottom, 0)
                                            }
                                            .frame(height: 233)
                                            HStack(alignment: .center, spacing: 12) {
                                                Circle()
                                                    .fill(Color.orange.opacity(0.2))
                                                    .frame(width: 40, height: 40)
                                                    .overlay(
                                                        Image(systemName: "megaphone.fill")
                                                            .font(.system(size: 20))
                                                            .foregroundColor(.orange)
                                                    )
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(ad.title)
                                                        .font(.headline)
                                                        .foregroundColor(.black)
                                                        .lineLimit(1)
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
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(.vertical, 8)
                                    .onAppear {
                                        firebaseManager.recordAdImpression(advertisementId: ad.id ?? "")
                                    }
                                }
                            }
                        }
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
        .fullScreenCover(isPresented: $showingPlanningScreen) {
            VisitPlanningScreen()
                .onDisappear {
                    loadSavedPlans()
                }
        }
        .navigationBarHidden(true)
        }
        .onAppear {
            loadSavedPlans()
            loadVisitAds()
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
                if !self.visitAds.isEmpty {
                    print("  表示する広告: \(self.visitAds[0].title)")
                }
                
            case .failure(let error):
                print("❌ ビジット広告取得エラー: \(error)")
            }
        }
    }
    
    func createCombinedItems() -> [Any] {
        var items: [Any] = []
        
        // 広告を最初に追加（存在する場合）
        if !visitAds.isEmpty {
            items.append(visitAds[0])
        }
        
        // その後にプランを追加
        items.append(contentsOf: savedPlans)
        
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




