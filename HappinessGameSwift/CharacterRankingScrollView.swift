import SwiftUI
import UIKit

struct CharacterRankingScrollView: View {
    @StateObject private var firebaseManager = FirebaseManager.shared
    @StateObject private var customRankingManager = CustomRankingManager()
    @State private var rankings: [CharacterRanking] = []
    @State private var characterAds: [Advertisement] = []
    @State private var isLoading = true
    @State private var rankingTitle: String = "Popular Character Ranking"
    @State private var scrollOffset: CGFloat = 0
    @State private var autoScrollTimer: Timer?
    @State private var isDragging = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // セクションタイトル
            HStack {
                Text(rankingTitle)
                    .font(.system(size: 19, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 3)
            
            // ランキングスクロールビュー
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) { // spacingを8→4に変更
                    // ランキングを2セット表示して無限ループを実現
                    ForEach(0..<2, id: \.self) { setIndex in
                        ForEach(allDisplayItems) { item in
                            switch item {
                            case .ranking(let ranking):
                                CharacterRankingCard(ranking: ranking)
                            case .advertisement(let ad):
                                CharacterRankingAdCard(ad: ad)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .offset(x: scrollOffset)
                .onAppear {
                    startAutoScroll()
                }
                .onDisappear {
                    stopAutoScroll()
                }
                .gesture(
                    DragGesture()
                        .onChanged { _ in
                            isDragging = true
                            stopAutoScroll()
                        }
                        .onEnded { _ in
                            isDragging = false
                            // 3秒後に自動スクロールを再開
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                if !isDragging {
                                    startAutoScroll()
                                }
                            }
                        }
                )
            }
        }
        .onAppear {
            loadCharacterAds()
            customRankingManager.loadActiveRankings()
        }
        .onReceive(customRankingManager.$selectedRanking) { selectedRanking in
            print("🔍 selectedRankingが変更されました: \(selectedRanking?.title ?? "なし")")
            if selectedRanking != nil {
                loadRankings()
            }
        }
        .onReceive(customRankingManager.$activeRankings) { activeRankings in
            print("🔍 activeRankingsが変更されました: \(activeRankings.count)件")
            // activeRankingsが更新された後、少し待ってからloadRankingsを実行
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                loadRankings()
            }
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
        print("🔍 [CharacterRankingScrollView] loadRankings開始")
        print("🔍 カスタムランキング数: \(customRankingManager.activeRankings.count)")
        print("🔍 選択されたランキング: \(customRankingManager.selectedRanking?.title ?? "なし")")
        
        // カスタムランキングがある場合はそれを使用
        if let currentRanking = customRankingManager.selectedRanking {
            print("🔍 カスタムランキング使用: \(currentRanking.title)")
            print("🔍 アイテム数: \(currentRanking.items?.count ?? 0)")
            
            // アイテムが空の場合は通常のランキングを使用
            guard let items = currentRanking.items, !items.isEmpty else {
                print("🔍 カスタムランキングのアイテムが空、通常のランキングを取得")
                loadDefaultRankings()
                return
            }
            
            // カスタムランキングのタイトルを設定
            self.rankingTitle = currentRanking.title
            
            // CustomRankingItemをCharacterRankingに変換
            self.rankings = items.map { item in
                print("🔍   - Rank \(item.rank): \(item.characterName)")
                print("🔍     画像URL: \(item.customImageURL ?? item.characterImageURL ?? "なし")")
                
                return CharacterRanking(
                    characterId: UUID(),
                    rank: item.rank,
                    characterName: item.characterName,
                    characterImagePath: item.customImageURL ?? item.characterImageURL
                )
            }
            print("🔍 変換後のランキング数: \(self.rankings.count)")
            self.isLoading = false
        } else {
            print("🔍 カスタムランキングなし、通常のランキングを取得")
            // 少し待ってから再度チェック
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let currentRanking = self.customRankingManager.selectedRanking {
                    print("🔍 遅延チェックでカスタムランキング発見: \(currentRanking.title)")
                    self.loadRankings()
                } else {
                    print("🔍 遅延チェックでもカスタムランキングなし、通常のランキングを取得")
                    self.loadDefaultRankings()
                }
            }
        }
    }
    
    private func loadDefaultRankings() {
        firebaseManager.fetchCharacterRankings { result in
            switch result {
            case .success(let fetchedRankings):
                print("🔍 通常ランキング取得成功: \(fetchedRankings.count)件")
                self.rankings = fetchedRankings
                self.rankingTitle = "Popular Character Ranking"
                self.isLoading = false
            case .failure(let error):
                print("❌ ランキング取得エラー: \(error)")
                self.isLoading = false
            }
        }
    }
    
    private func loadCharacterAds() {
        firebaseManager.fetchAds(for: "character") { result in
            switch result {
            case .success(let ads):
                self.characterAds = ads
            case .failure(let error):
                print("キャラクター広告取得エラー: \(error)")
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
    
    private func startAutoScroll() {
        stopAutoScroll()
        
        let itemWidth: CGFloat = 71 // 67 (width) + 4 (spacing)
        let totalWidth = CGFloat(allDisplayItems.count) * itemWidth
        
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            if !isDragging {
                withAnimation(.linear(duration: 0.02)) {
                    scrollOffset -= 0.5 // ゆっくりとした速度
                    
                    // 1セット分スクロールしたらリセット
                    if scrollOffset <= -totalWidth {
                        scrollOffset = 0
                    }
                }
            }
        }
    }
    
    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
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
                                GeometryReader { geometry in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 67, height: 67)
                                        .clipShape(RoundedRectangle(cornerRadius: 16)) // 丸から角丸四角形へ
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(rankColor, lineWidth: 2.5)
                                        )
                                }
                                .frame(width: 67, height: 67)
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
                                            .stroke(rankColor, lineWidth: 2.5)
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else if let image = UIImage(contentsOfFile: imagePath) {
                        // ローカルファイルの場合
                        GeometryReader { geometry in
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 67, height: 67)
                                .clipShape(RoundedRectangle(cornerRadius: 16)) // 丸から角丸四角形へ
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(rankColor, lineWidth: 2.5)
                                )
                        }
                        .frame(width: 67, height: 67)
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
                                    .stroke(rankColor, lineWidth: 2.5)
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
                                .stroke(rankColor, lineWidth: 2.5)
                        )
                }
                
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
    }
    
    private var rankColor: Color {
        switch ranking.rank {
        case 1:
            return Color(red: 1.0, green: 0.84, blue: 0) // 金色
        case 2:
            return Color(red: 0.75, green: 0.75, blue: 0.75) // 銀色
        case 3:
            return Color(red: 0.8, green: 0.5, blue: 0.2) // 銅色
        default:
            return Color.blue // 青色
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