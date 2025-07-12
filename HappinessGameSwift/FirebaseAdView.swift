import SwiftUI
import UIKit

struct FirebaseAdView: View {
    let placement: String
    let adIndex: Int // 表示する広告のインデックス
    @State private var advertisements: [Advertisement] = []
    @State private var currentIndex = 0
    @State private var timer: Timer?
    @State private var isLoading = true
    @State private var scrollOffset: CGFloat = 0
    @State private var autoScrollTimer: Timer?
    @State private var scrollSpeed: CGFloat = 0.8
    @EnvironmentObject var characterManager: CharacterManager
    @EnvironmentObject var animeManager: AnimeManager
    
    init(placement: String, adIndex: Int = 0) {
        self.placement = placement
        self.adIndex = adIndex
    }
    
    private func convertedAd() -> Advertisement? {
        guard !advertisements.isEmpty else { return nil }
        
        // 複数の広告がある場合は、adIndexに基づいて異なる広告を表示
        let index = advertisements.count > 1 ? (adIndex % advertisements.count) : (currentIndex % advertisements.count)
        
        // 広告が1つしかない場合、2つ目のインスタンスはnilを返す
        if advertisements.count == 1 && adIndex > 0 {
            return nil
        }
        
        guard index < advertisements.count else { return nil }
        
        var ad = advertisements[index]
        print("🎯 [FirebaseAdView] 広告表示: placement=\(placement), adIndex=\(adIndex), 選択された広告=\(ad.title)")
        
        // GitHub URLの場合はraw URLに変換
        if ad.imageURL.contains("github.com") && ad.imageURL.contains("/blob/") {
            ad.imageURL = ad.imageURL
                .replacingOccurrences(of: "github.com", with: "raw.githubusercontent.com")
                .replacingOccurrences(of: "/blob/", with: "/")
            print("🔄 [FirebaseAdView] GitHub URLをraw URLに変換: \(ad.imageURL)")
        }
        return ad
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
            } else if !advertisements.isEmpty {
                if let ad = convertedAd() {
                    if placement == "character" {
                    // キャラクターページ: 左テキスト・右画像
                    Button(action: {
                        handleAdClick(ad)
                    }) {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ad.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(ad.description)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            if let url = URL(string: ad.imageURL), !ad.imageURL.isEmpty {
                                let _ = print("📷 [FirebaseAdView] 画像読み込み: \(ad.imageURL)")
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        let _ = print("✅ [FirebaseAdView] 画像読み込み成功: \(ad.imageURL)")
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    case .failure(let error):
                                        let _ = print("❌ [FirebaseAdView] 画像読み込み失敗: \(error.localizedDescription)")
                                        Color(.systemGray5)
                                            .overlay(
                                                Text("画像エラー")
                                                    .font(.caption)
                                                    .foregroundColor(.red)
                                            )
                                    case .empty:
                                        let _ = print("⏳ [FirebaseAdView] 画像読み込み中...")
                                        ProgressView()
                                    @unknown default:
                                        Color(.systemGray5)
                                    }
                                }
                                .frame(width: 132, height: 86)
                                .cornerRadius(8)
                                .clipped()
                            } else {
                                let _ = print("⚠️ [FirebaseAdView] 画像URLが空または無効: imageURL='\(ad.imageURL)'")
                                Color(.systemGray5)
                                    .frame(width: 132, height: 86)
                                    .cornerRadius(8)
                                    .clipped()
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else if placement == "product" {
                    // プロダクトページ: 左画像・右テキスト（アニメ一覧風）
                    Button(action: {
                        handleAdClick(ad)
                    }) {
                        HStack(spacing: 16) {
                            if let url = URL(string: ad.imageURL), !ad.imageURL.isEmpty {
                                let _ = print("📷 [FirebaseAdView] 画像読み込み: \(ad.imageURL)")
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        let _ = print("✅ [FirebaseAdView] 画像読み込み成功: \(ad.imageURL)")
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    case .failure(let error):
                                        let _ = print("❌ [FirebaseAdView] 画像読み込み失敗: \(error.localizedDescription)")
                                        Color(.systemGray5)
                                            .overlay(
                                                Text("画像エラー")
                                                    .font(.caption)
                                                    .foregroundColor(.red)
                                            )
                                    case .empty:
                                        let _ = print("⏳ [FirebaseAdView] 画像読み込み中...")
                                        ProgressView()
                                    @unknown default:
                                        Color(.systemGray5)
                                    }
                                }
                                .frame(width: 168.48, height: 99)
                                .cornerRadius(10)
                                .clipped()
                            } else {
                                let _ = print("⚠️ [FirebaseAdView] 画像URLが空または無効: imageURL='\(ad.imageURL)'")
                                Color(.systemGray5)
                                    .frame(width: 168.48, height: 99)
                                    .cornerRadius(10)
                                    .clipped()
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text(ad.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                Text(ad.description)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, -4)
                } else if placement == "anime" {
                    // アニメページ: 横スクロールで最大5つ表示
                    VStack(alignment: .leading, spacing: 12) {
                        // セクションタイトル
                        HStack(spacing: 8) {
                            // アイコンと背景
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: "star.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                            }
                            
                            Text("今おすすめアニメ")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                            
                            Spacer()
                            
                            Button(action: {
                                // Navigate to anime ranking page
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let window = windowScene.windows.first,
                                   let rootViewController = window.rootViewController {
                                    let animeRankingView = AnimeRankingScreen()
                                    let hostingController = UIHostingController(rootView: animeRankingView)
                                    hostingController.modalPresentationStyle = .fullScreen
                                    rootViewController.present(hostingController, animated: true)
                                }
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                // 広告を3セット表示して無限ループを実現
                                ForEach(0..<3, id: \.self) { setIndex in
                                    ForEach(advertisements) { ad in
                                        Button(action: {
                                            handleAdClick(ad)
                                        }) {
                                    ZStack(alignment: .bottom) {
                                        // 画像
                                        if let url = URL(string: convertGitHubUrl(ad.imageURL)), !ad.imageURL.isEmpty {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                case .failure(_):
                                                    Color(.systemGray5)
                                                        .overlay(
                                                            Image(systemName: "photo")
                                                                .font(.system(size: 30))
                                                                .foregroundColor(.gray)
                                                        )
                                                case .empty:
                                                    ProgressView()
                                                @unknown default:
                                                    Color(.systemGray5)
                                                }
                                            }
                                            .frame(width: 260, height: 144)
                                            .clipped()
                                        } else {
                                            Color(.systemGray5)
                                                .frame(width: 260, height: 144)
                                        }
                                        
                                        // タイトルオーバーレイ
                                        VStack {
                                            Spacer()
                                            HStack {
                                                Text(ad.title)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 6)
                                                Spacer()
                                            }
                                            .background(
                                                // ブラー効果の背景
                                                VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
                                                    .opacity(0.7)
                                            )
                                        }
                                    }
                                    .frame(width: 260, height: 144)
                                    .cornerRadius(10)
                                    .clipped()
                                }
                                    .buttonStyle(PlainButtonStyle())
                                    .onAppear {
                                        if setIndex == 0 { // 最初のセットでのみインプレッションを記録
                                            recordImpression(for: ad)
                                        }
                                    }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .offset(x: scrollOffset)
                                .onAppear {
                                    startAutoScroll()
                                    // 定期的に自動スクロール状態をチェック
                                    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                                        if autoScrollTimer == nil {
                                            startAutoScroll()
                                        }
                                    }
                                }
                                .onDisappear {
                                    stopAutoScroll()
                                }
                                // ユーザー操作時も自動スクロールを止めない
                        }
                    }
                } else {
                    // ホームページ: 画像のみ
                    // 広告が1つしかない場合や、指定されたインデックスが範囲外の場合は空のビューを返す
                    if advertisements.count <= 1 && adIndex > 0 {
                        EmptyView()
                    } else if adIndex < advertisements.count {
                        Button(action: {
                            handleAdClick(ad)
                        }) {
                            VStack {
                                if let url = URL(string: ad.imageURL), !ad.imageURL.isEmpty {
                                    let _ = print("📷 [FirebaseAdView] 画像読み込み: \(ad.imageURL)")
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            let _ = print("✅ [FirebaseAdView] 画像読み込み成功: \(ad.imageURL)")
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        case .failure(let error):
                                            let _ = print("❌ [FirebaseAdView] 画像読み込み失敗: \(error.localizedDescription)")
                                            Color(.systemGray5)
                                                .overlay(
                                                    Text("画像エラー")
                                                        .font(.caption)
                                                        .foregroundColor(.red)
                                                )
                                        case .empty:
                                            let _ = print("⏳ [FirebaseAdView] 画像読み込み中...")
                                            ProgressView()
                                        @unknown default:
                                            Color(.systemGray5)
                                        }
                                    }
                                } else {
                                    let _ = print("⚠️ [FirebaseAdView] 画像URLが空または無効: imageURL='\(ad.imageURL)'")
                                    Color(.systemGray5)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 16)
                    } else {
                        EmptyView()
                    }
                    }
                }
            }
        }
        .onAppear {
            loadAds()
        }
    }
    
    private func handleAdClick(_ ad: Advertisement) {
        print("🖱️ [FirebaseAdView] 広告クリック: \(ad.title) - \(ad.linkURL)")
        
        // クリックを記録
        if let adId = ad.id {
            FirebaseManager.shared.recordAdClick(advertisementId: adId)
        }
        
        // URLを開く
        if let url = URL(string: ad.linkURL) {
            UIApplication.shared.open(url)
        }
    }
    
    func loadAds() {
        print("🔥 [FirebaseAdView] 広告読み込み開始: placement=\(placement)")
        FirebaseManager.shared.fetchAds(for: placement) { result in
            switch result {
            case .success(let ads):
                print("✅ [FirebaseAdView] 広告取得成功: \(ads.count)件")
                for (index, ad) in ads.enumerated() {
                    print("📄 [FirebaseAdView] 広告[\(index)]: id=\(ad.id ?? "nil"), title=\(ad.title)")
                    print("   - imageURL: \(ad.imageURL)")
                    print("   - placements: \(ad.placements)")
                    print("   - isActive: \(ad.isActive)")
                }
                
                let userAnimes = animeManager.animes.map { $0.title }
                let userCharacters = characterManager.characters.map { $0.name }
                let userHashtags = (animeManager.animes.map { $0.hashtag } + characterManager.characters.map { $0.tag }).filter { !$0.isEmpty }
                
                print("👤 [FirebaseAdView] ユーザー情報:")
                print("   - アニメ: \(userAnimes)")
                print("   - キャラクター: \(userCharacters)")
                print("   - ハッシュタグ: \(userHashtags)")
                
                let targetAds = ads.filter { ad in
                    (ad.targetAnimes.first(where: { userAnimes.contains($0) }) != nil) ||
                    (ad.targetCharacters.first(where: { userCharacters.contains($0) }) != nil) ||
                    (ad.targetHashtags.first(where: { userHashtags.contains($0) }) != nil)
                }
                let generalAds = ads.filter { ad in
                    (ad.targetAnimes.isEmpty && ad.targetCharacters.isEmpty && ad.targetHashtags.isEmpty)
                }
                
                print("🎯 [FirebaseAdView] ターゲット広告: \(targetAds.count)件")
                print("📢 [FirebaseAdView] 一般広告: \(generalAds.count)件")
                
                // --- 確率ベースの広告選択 ---
                var candidateAds: [Advertisement] = []
                
                // ターゲット広告を優先的に選択（表示率を考慮）
                for ad in targetAds {
                    let probability = ad.displayRate / 100.0
                    if Double.random(in: 0.0...1.0) <= probability {
                        candidateAds.append(ad)
                    }
                }
                
                // 一般広告から選択（表示率を考慮）
                for ad in generalAds {
                    let probability = ad.displayRate / 100.0
                    if Double.random(in: 0.0...1.0) <= probability {
                        candidateAds.append(ad)
                    }
                }
                
                // 優先度でソート
                candidateAds.sort { ad1, ad2 in
                    // まずターゲット広告を優先
                    let isTarget1 = (ad1.targetAnimes.first(where: { userAnimes.contains($0) }) != nil) ||
                                   (ad1.targetCharacters.first(where: { userCharacters.contains($0) }) != nil) ||
                                   (ad1.targetHashtags.first(where: { userHashtags.contains($0) }) != nil)
                    let isTarget2 = (ad2.targetAnimes.first(where: { userAnimes.contains($0) }) != nil) ||
                                   (ad2.targetCharacters.first(where: { userCharacters.contains($0) }) != nil) ||
                                   (ad2.targetHashtags.first(where: { userHashtags.contains($0) }) != nil)
                    
                    if isTarget1 != isTarget2 {
                        return isTarget1
                    }
                    
                    // 同じタイプの場合は優先度でソート
                    return ad1.priority > ad2.priority
                }
                
                // 制限なしで全ての広告を表示
                self.advertisements = candidateAds
                
                print("🎬 [FirebaseAdView] 最終的に表示する広告: \(self.advertisements.count)件")
                for (index, ad) in self.advertisements.enumerated() {
                    print("   [\(index)] \(ad.title) - imageURL: \(ad.imageURL)")
                }
                
                self.isLoading = false
            case .failure(let error):
                print("❌ [FirebaseAdView] 広告読み込みエラー: \(error)")
                self.isLoading = false
            }
        }
    }
    
    func startTimer() {
        guard advertisements.count > 1 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            withAnimation {
                currentIndex = (currentIndex + 1) % advertisements.count
            }
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func recordImpression(for ad: Advertisement) {
        if let adId = ad.id {
            FirebaseManager.shared.recordAdImpression(advertisementId: adId)
        }
    }
    
    private func convertGitHubUrl(_ url: String) -> String {
        if url.contains("github.com") && url.contains("/blob/") {
            return url
                .replacingOccurrences(of: "github.com", with: "raw.githubusercontent.com")
                .replacingOccurrences(of: "/blob/", with: "/")
        }
        return url
    }
    
    private func startAutoScroll() {
        guard placement == "anime" && advertisements.count > 1 else { return }
        
        stopAutoScroll()
        
        let itemWidth: CGFloat = 272 // 260 (width) + 12 (spacing)
        let totalWidth = CGFloat(advertisements.count) * itemWidth
        
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            withAnimation(.linear(duration: 0.02)) {
                scrollOffset -= scrollSpeed // 可変速度
                
                // 1セット分スクロールしたらシームレスにリセット（アニメーションなし）
                if scrollOffset <= -totalWidth {
                    // アニメーションを一時停止してリセット
                    withAnimation(.none) {
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

// ブラー効果のためのUIViewRepresentable
struct VisualEffectView: UIViewRepresentable {
    let effect: UIVisualEffect?
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: effect)
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = effect
    }
}