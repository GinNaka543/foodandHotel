import SwiftUI
import UIKit

struct CharacterRankingScrollView: View {
    @StateObject private var firebaseManager = FirebaseManager.shared
    @StateObject private var customRankingManager = CustomRankingManager()
    @State private var rankings: [CharacterRanking] = []
    @State private var characterAds: [Advertisement] = []
    @State private var isLoading = true
    @State private var rankingTitle: String = "Popular Character Ranking"
    @State private var scrollSpeed: CGFloat = 0.8
    @State private var showRankingSelection = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // セクションタイトル
            HStack {
                HStack(spacing: 8) {
                    Text(rankingTitle)
                        .font(.system(size: 19, weight: .bold))
                    Button(action: {
                        showRankingSelection = true
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 3)
            
            // ランキングスクロールビュー
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) { // spacingを8→4に変更
                    // 1セット分のみ表示
                    ForEach(allDisplayItems) { item in
                        switch item {
                        case .ranking(let ranking):
                            CharacterRankingCard(ranking: ranking)
                        case .advertisement(let ad):
                            CharacterRankingAdCard(ad: ad)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .onAppear {
                    loadCharacterAds()
                    customRankingManager.loadActiveRankings()
                    // データ読み込み後に自動スクロールを開始
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        loadRankings()
                    }
                }
                .onReceive(customRankingManager.$selectedRanking) { selectedRanking in
                    if selectedRanking != nil {
                        loadRankings()
                        // データが読み込まれたら自動スクロール開始
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            loadRankings()
                        }
                    }
                }
                .onReceive(customRankingManager.$activeRankings) { activeRankings in
                    // activeRankingsが更新された後、少し待ってからloadRankingsを実行
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        loadRankings()
                    }
                }
            }
        }
        .sheet(isPresented: $showRankingSelection) {
            RankingSelectionView(
                customRankingManager: customRankingManager,
                currentRankingTitle: rankingTitle
            )
        }
    }
    
    private var allDisplayItems: [DisplayItem] {
        var items: [DisplayItem] = []
        
        // 1-7位のランキングを順番に追加（広告なし）
        for rank in 1...7 {
            if let ranking = rankings.first(where: { $0.rank == rank }) {
                items.append(.ranking(ranking))
            }
        }
        
        return items
    }
    
    private func loadRankings() {
        
        // カスタムランキングがある場合はそれを使用
        if let currentRanking = customRankingManager.selectedRanking {
            
            // アイテムが空の場合は通常のランキングを使用
            guard let items = currentRanking.items, !items.isEmpty else {
                loadDefaultRankings()
                return
            }
            
            // カスタムランキングのタイトルを設定
            self.rankingTitle = currentRanking.title
            
            // CustomRankingItemをCharacterRankingに変換
            self.rankings = items.map { item in
                
                return CharacterRanking(
                    characterId: UUID(),
                    rank: item.rank,
                    characterName: item.characterName,
                    characterImagePath: item.customImageURL ?? item.characterImageURL,
                    externalLink: item.externalLink
                )
            }
            self.isLoading = false
        } else {
            // 少し待ってから再度チェック
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if self.customRankingManager.selectedRanking != nil {
                    self.loadRankings()
                } else {
                    self.loadDefaultRankings()
                }
            }
        }
    }
    
    private func loadDefaultRankings() {
        firebaseManager.fetchCharacterRankings { result in
            switch result {
            case .success(let fetchedRankings):
                self.rankings = fetchedRankings
                self.rankingTitle = "Popular Character Ranking"
                self.isLoading = false
            case .failure(_):
                self.isLoading = false
            }
        }
    }
    
    private func loadCharacterAds() {
        firebaseManager.fetchAds(for: "character") { result in
            switch result {
            case .success(let ads):
                self.characterAds = ads
            case .failure(_):
                break
            }
        }
    }
    
    private func getAdForPosition(_ position: Int) -> Advertisement? {
        let availableAds = characterAds.filter { ad in
            ad.placements.contains("character")
        }
        
        if position == 3 && availableAds.count > 0 {
            return availableAds[0]
        } else if position == 6 && availableAds.count > 1 {
            return availableAds[1]
        }
        return nil
    }
}

// ランキング選択ビュー
struct RankingSelectionView: View {
    @ObservedObject var customRankingManager: CustomRankingManager
    let currentRankingTitle: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            ZStack {
                Text(NSLocalizedString("ranking_selection", comment: "Ranking Selection"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.black)
                    }
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
            
            ScrollView {
                VStack(spacing: 16) {
                    // カスタムランキング
                    ForEach(customRankingManager.activeRankings) { ranking in
                        Button(action: {
                            customRankingManager.selectedRanking = ranking
                            dismiss()
                        }) {
                            ZStack(alignment: .bottom) {
                                // ランキング画像
                                if let imageURL = ranking.imageURL, !imageURL.isEmpty {
                                    let convertedURL = convertGitHubUrl(imageURL)
                                    // let _ = print("🖼️ [RankingSelection] ランキング: \(ranking.title)")
                                    // let _ = print("🖼️ [RankingSelection] 元URL: \(imageURL)")
                                    // let _ = print("🖼️ [RankingSelection] 変換後URL: \(convertedURL)")
                                    AsyncImage(url: URL(string: convertedURL)) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(height: 144)
                                                .clipped()
                                        case .failure(_):
                                            Color(.systemGray5)
                                                .frame(height: 144)
                                                .overlay(
                                                    Image(systemName: "photo")
                                                        .font(.system(size: 30))
                                                        .foregroundColor(.gray)
                                                )
                                        case .empty:
                                            let _ = print("⏳ [RankingSelection] 画像読み込み中...")
                                            Color(.systemGray5)
                                                .frame(height: 144)
                                                .overlay(
                                                    Image(systemName: "photo")
                                                        .font(.system(size: 30))
                                                        .foregroundColor(.gray)
                                                )
                                        @unknown default:
                                            Color(.systemGray5)
                                                .frame(height: 144)
                                        }
                                    }
                                } else {
                                    Color(.systemGray5)
                                        .frame(height: 144)
                                        .overlay(
                                            Image(systemName: "list.star")
                                                .font(.system(size: 30))
                                                .foregroundColor(.gray)
                                        )
                                }
                                
                                // タイトルオーバーレイ
                                VStack {
                                    Spacer()
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(ranking.title)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                            Text("\(ranking.items?.count ?? 0)キャラクター")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.8))
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        if currentRankingTitle == ranking.title {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                }
                                .background(
                                    VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
                                        .opacity(0.7)
                                )
                            }
                            .frame(maxWidth: .infinity)
                            .cornerRadius(10)
                            .clipped()
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .background(Color.white)
    }
    
    private func convertGitHubUrl(_ url: String) -> String {
        if url.contains("github.com") && url.contains("/blob/") {
            return url
                .replacingOccurrences(of: "github.com", with: "raw.githubusercontent.com")
                .replacingOccurrences(of: "/blob/", with: "/")
        }
        return url
    }
}

// 表示アイテムの種類
enum DisplayItem: Identifiable {
    case ranking(CharacterRanking)
    case advertisement(Advertisement)
    
    var id: String {
        switch self {
        case .ranking(let ranking):
            return "ranking_\(ranking.rank)"
        case .advertisement(let ad):
            return "ad_\(ad.id ?? UUID().uuidString)"
        }
    }
}

// キャラクターランキングカード
struct CharacterRankingCard: View {
    let ranking: CharacterRanking
    
    private func convertGitHubUrl(_ url: String) -> String {
        if url.contains("github.com") && url.contains("/blob/") {
            return url
                .replacingOccurrences(of: "github.com", with: "raw.githubusercontent.com")
                .replacingOccurrences(of: "/blob/", with: "/")
        }
        return url
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // 丸いアイコン
            ZStack {
                if let imagePath = ranking.characterImagePath, !imagePath.isEmpty {
                    // GitHub URLかローカルパスかを判定
                    if imagePath.starts(with: "http://") || imagePath.starts(with: "https://") {
                        // URLの場合はAsyncImageを使用
                        AsyncImage(url: URL(string: convertGitHubUrl(imagePath))) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 67, height: 67)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(rankGradient, lineWidth: 2.5)
                                    )
                            case .failure(_), .empty:
                                // プレースホルダー
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 67, height: 67)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(.gray)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(rankGradient, lineWidth: 2.5)
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else if let image = UIImage(contentsOfFile: imagePath) {
                        // ローカルファイルの場合
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 67, height: 67)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(rankGradient, lineWidth: 2.5)
                            )
                    } else {
                        // プレースホルダー
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 67, height: 67)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.gray)
                            )
                            .overlay(
                                Circle()
                                    .stroke(rankGradient, lineWidth: 2.5)
                            )
                    }
                } else {
                    // プレースホルダー
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 67, height: 67)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.gray)
                        )
                        .overlay(
                            Circle()
                                .stroke(rankGradient, lineWidth: 2.5)
                        )
                }
                
                // 順位バッジ
                ZStack {
                    Circle()
                        .fill(rankGradient)
                        .frame(width: 26, height: 26)
                    
                    Text("\(ranking.rank)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: 25, y: -25)
            }
            
            // キャラクター名
            Text(ranking.characterName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 67)
        }
        .frame(width: 84)
        .onTapGesture {
            // ランキングに設定されたリンクがある場合は開く
            if let link = ranking.externalLink,
               !link.isEmpty,
               let url = URL(string: link) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private var rankGradient: LinearGradient {
        switch ranking.rank {
        case 1:
            // 金色グラデーション
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 1.0, green: 0.9, blue: 0.3),
                    Color(red: 1.0, green: 0.84, blue: 0),
                    Color(red: 0.9, green: 0.7, blue: 0)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 2:
            // 銀色グラデーション
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.9, green: 0.9, blue: 0.9),
                    Color(red: 0.75, green: 0.75, blue: 0.75),
                    Color(red: 0.6, green: 0.6, blue: 0.6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 3:
            // 銅色グラデーション
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.9, green: 0.6, blue: 0.3),
                    Color(red: 0.8, green: 0.5, blue: 0.2),
                    Color(red: 0.7, green: 0.4, blue: 0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            // 青色グラデーション
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.2, green: 0.5, blue: 1.0),
                    Color(red: 0.1, green: 0.4, blue: 0.9),
                    Color(red: 0, green: 0.3, blue: 0.8)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// キャラクターランキング用広告カード
struct CharacterRankingAdCard: View {
    let ad: Advertisement
    @StateObject private var firebaseManager = FirebaseManager.shared
    
    var body: some View {
        Button(action: {
            handleAdClick()
        }) {
            VStack(spacing: 8) {
                // 丸い広告画像
                ZStack {
                    if let url = URL(string: convertGitHubUrl(ad.imageURL)), !ad.imageURL.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 67, height: 67)
                                    .clipShape(RoundedRectangle(cornerRadius: 16)) // 丸から角丸四角形へ
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.blue, lineWidth: 2.5)
                                    )
                            case .failure(_):
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 67, height: 67)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .font(.system(size: 28))
                                            .foregroundColor(.gray)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.blue, lineWidth: 2.5)
                                    )
                            case .empty:
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 67, height: 67)
                                    .overlay(
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.blue, lineWidth: 2.5)
                                    )
                            @unknown default:
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 67, height: 67)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.blue, lineWidth: 2.5)
                                    )
                            }
                        }
                    } else {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 67, height: 67)
                            .overlay(
                                Image(systemName: "megaphone.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.gray)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.blue, lineWidth: 2.5)
                            )
                    }
                    
                }
                
                // 広告タイトル
                Text(ad.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 67)
            }
            .frame(width: 84)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            recordImpression()
        }
    }
    
    private func handleAdClick() {
        if let url = URL(string: ad.linkURL) {
            firebaseManager.recordAdClick(advertisementId: ad.id ?? "")
            UIApplication.shared.open(url)
        }
    }
    
    private func recordImpression() {
        firebaseManager.recordAdImpression(advertisementId: ad.id ?? "")
    }
    
    private func convertGitHubUrl(_ url: String) -> String {
        if url.contains("github.com") && url.contains("/blob/") {
            return url
                .replacingOccurrences(of: "github.com", with: "raw.githubusercontent.com")
                .replacingOccurrences(of: "/blob/", with: "/")
        }
        return url
    }
}

// VisualEffectViewは既存のファイルで定義済みのため削除

#Preview {
    CharacterRankingScrollView()
}