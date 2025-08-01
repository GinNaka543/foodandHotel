import SwiftUI
import Foundation

struct ArtworkPlayerScreen: View {
    @State private var artwork: Artwork
    let character: Character?
    let anime: Anime?
    var allArtworks: [Artwork] = []
    var onDelete: (() -> Void)? = nil
    var onEdit: ((String, [String]) -> Void)? = nil
    var onArtworkChange: ((Artwork) -> Void)? = nil
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    @State private var filteredArtworks: [Artwork] = []
    @State private var showSearchBar = false
    @State private var characterVideos: [Any] = []
    
    init(artwork: Artwork, character: Character? = nil, anime: Anime? = nil, allArtworks: [Artwork] = [], onDelete: (() -> Void)? = nil, onEdit: ((String, [String]) -> Void)? = nil, onArtworkChange: ((Artwork) -> Void)? = nil) {
        self._artwork = State(initialValue: artwork)
        self.character = character
        self.anime = anime
        self.allArtworks = allArtworks
        self.onDelete = onDelete
        self.onEdit = onEdit
        self.onArtworkChange = onArtworkChange
    }
    @State private var showMenuSheet = false
    @State private var editTitle: String = ""
    @State private var editTags: String = ""
    @State private var refreshID = UUID()
    @State private var showDeleteAlert = false
    @State private var showFullscreen = false
    @State private var selectedArtwork: Artwork?
    @State private var showPixivRedirect = false
    
    // Load videos for the character
    private func loadCharacterVideos() {
        guard let character = character else { return }
        let key = "videos_\(character.id.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key) {
            // Store raw data instead of decoding to avoid type conflicts
            characterVideos = [data]
        }
    }
    
    // Calculate total video view count
    private var totalVideoViewCount: Int {
        guard let character = character else { return 0 }
        let key = "videos_\(character.id.uuidString)"
        
        if let data = UserDefaults.standard.data(forKey: key),
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
           let videosArray = jsonObject as? [[String: Any]] {
            
            return videosArray.reduce(0) { sum, videoDict in
                let viewCount = videoDict["viewCount"] as? Int ?? 0
                return sum + viewCount
            }
        }
        return 0
    }
    
    // Increment view count for current artwork
    private func incrementArtworkViewCount() {
        artwork.viewCount = (artwork.viewCount ?? 0) + 1
        
        // Save the updated artwork
        saveArtworkToUserDefaults()
        
        // Notify parent view about the change
        onArtworkChange?(artwork)
    }
    
    // Save artwork to UserDefaults
    private func saveArtworkToUserDefaults() {
        // Determine the key based on whether it's a character or anime artwork
        let key: String
        if let character = character {
            key = "artworks_\(character.id.uuidString)"
        } else if let anime = anime {
            key = "anime_artworks_\(anime.id.uuidString)"
        } else {
            return
        }
        
        // Load existing artworks
        if let data = UserDefaults.standard.data(forKey: key),
           var artworks = try? JSONDecoder().decode([Artwork].self, from: data) {
            
            // Update the artwork in the array
            if let index = artworks.firstIndex(where: { $0.id == artwork.id }) {
                artworks[index] = artwork
                
                // Save back to UserDefaults
                if let encodedData = try? JSONEncoder().encode(artworks) {
                    UserDefaults.standard.set(encodedData, forKey: key)
                }
            }
        }
    }
    
    // Increment view count for an artwork
    private func incrementViewCount(for artwork: Artwork) {
        if allArtworks.contains(where: { $0.id == artwork.id }) {
            // This is a local copy, in production you'd sync with parent
        }
    }
    
    // View count formatter
    private func formatViewCount(_ count: Int) -> String {
        if count >= 10000 {
            let formatted = Double(count) / 10000.0
            return String(format: "%.1f万", formatted)
        } else {
            return "\(count)"
        }
    }
    
    // Time ago formatter
    private func timeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date, to: now)
        
        if let years = components.year, years > 0 {
            return String(format: NSLocalizedString("years_ago", comment: ""), years)
        } else if let months = components.month, months > 0 {
            return String(format: NSLocalizedString("months_ago", comment: ""), months)
        } else if let days = components.day, days > 0 {
            return String(format: NSLocalizedString("days_ago", comment: ""), days)
        } else if let hours = components.hour, hours > 0 {
            return String(format: NSLocalizedString("hours_ago", comment: ""), hours)
        } else if let minutes = components.minute, minutes > 0 {
            return String(format: NSLocalizedString("minutes_ago", comment: ""), minutes)
        } else {
            return NSLocalizedString("just_now", comment: "")
        }
    }
    
    private func formatTitle(_ title: String, isVideoThumbnail: Bool = false) -> String {
        if isVideoThumbnail {
            // For video/image titles: break at 17 chars, truncate after 33
            if title.count <= 17 {
                return title
            } else if title.count <= 33 {
                let firstLine = String(title.prefix(17))
                let secondLine = String(title.dropFirst(17))
                return firstLine + "\n" + secondLine
            } else {
                let firstLine = String(title.prefix(17))
                let secondLine = String(title.dropFirst(17).prefix(16)) + "..."
                return firstLine + "\n" + secondLine
            }
        } else {
            // For other titles: break at 9 chars, truncate after 17
            if title.count <= 9 {
                return title
            } else if title.count <= 17 {
                let firstLine = String(title.prefix(9))
                let secondLine = String(title.dropFirst(9))
                return firstLine + "\n" + secondLine
            } else {
                let firstLine = String(title.prefix(9))
                let secondLine = String(title.dropFirst(9).prefix(8)) + "..."
                return firstLine + "\n" + secondLine
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    // ヘッダー
                    HStack(spacing: 12) {
                        // White logo（左端に配置）
                        if let logoImage = UIImage(named: "whitelogo") {
                            Image(uiImage: logoImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 38)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.black)
                    
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                // 画像表示部分
                            ZStack(alignment: .topLeading) {
                        if let imagePath = artwork.imagePath, let uiImage = loadImageFromPath(imagePath) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geometry.size.width, height: geometry.size.width * 9.0 / 16.0)
                                .background(Color.black)
                                .padding(.top, -10)
                        } else if let pixivURL = artwork.pixivURL {
                            ZStack {
                                if let customThumbnailData = artwork.customThumbnailData,
                                   let uiImage = UIImage(data: customThumbnailData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: geometry.size.width, height: geometry.size.width * 9.0 / 16.0)
                                        .clipped()
                                } else {
                                    PixivThumbnailView(pixivURL: pixivURL)
                                        .frame(width: geometry.size.width, height: geometry.size.width * 9.0 / 16.0)
                                }
                                
                                // Pixivリンクを表示する小さなオーバーレイ
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        // Pixiv link button using onTapGesture for iPad compatibility
                                        HStack(spacing: 4) {
                                            Image(systemName: "link")
                                                .font(.caption)
                                            Text("Pixiv")
                                                .font(.caption)
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.black.opacity(0.7))
                                        .cornerRadius(8)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            showPixivRedirect = true
                                        }
                                        .padding(.trailing, 12)
                                        .padding(.bottom, 8)
                                    }
                                }
                            }
                            .frame(width: geometry.size.width, height: geometry.size.width * 9.0 / 16.0)
                            .onTapGesture {
                                showPixivRedirect = true
                            }
                        } else {
                            Color.gray.opacity(0.2)
                                .frame(width: geometry.size.width, height: geometry.size.width * 9.0 / 16.0)
                        }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.width * 9.0 / 16.0)
                        .background(Color.black)
                        .id("player")
                        
                        // 画像情報・関連画像セクション
                        VStack(alignment: .leading, spacing: 0) {
                            ArtworkInfoView(
                                artwork: $artwork,
                                character: character,
                                anime: anime,
                                showMenuSheet: { showMenuSheet = true },
                                showFullscreen: { showFullscreen = true },
                                totalVideoViewCount: totalVideoViewCount
                            )
                            .id(refreshID)
                            .padding(.bottom, 16)
                        
                        // 関連画像リスト
                        if allArtworks.count > 1 {
                            VStack(alignment: .leading, spacing: 16) {
                                Text(NSLocalizedString("related_images", comment: "Related Images"))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 16)
                                
                                LazyVStack(spacing: 0) {
                                    Spacer().frame(height: 5)
                                        ForEach(Array(getRelatedArtworks().enumerated()), id: \.element.id) { idx, relatedArtwork in
                                            if idx > 0 {
                                                Spacer().frame(height: 15.9)
                                            }
                                            // Using onTapGesture for iPad compatibility
                                            VStack(alignment: .leading, spacing: 8) {
                                                VStack(alignment: .leading, spacing: 8) {
                                                    // サムネイル
                                                    ZStack {
                                                        if let imagePath = relatedArtwork.imagePath, let uiImage = loadImageFromPath(imagePath) {
                                                            Image(uiImage: uiImage)
                                                                .resizable()
                                                                .scaledToFill()
                                                                .frame(width: UIScreen.main.bounds.width, height: UIDevice.current.userInterfaceIdiom == .pad ? 400 : 200)
                                                                .clipped()
                                                        } else if let pixivURL = relatedArtwork.pixivURL {
                                                            if let customThumbnailData = relatedArtwork.customThumbnailData,
                                                               let uiImage = UIImage(data: customThumbnailData) {
                                                                Image(uiImage: uiImage)
                                                                    .resizable()
                                                                    .scaledToFill()
                                                                    .frame(width: UIScreen.main.bounds.width, height: UIDevice.current.userInterfaceIdiom == .pad ? 400 : 200)
                                                                    .clipped()
                                                            } else {
                                                                PixivThumbnailView(pixivURL: pixivURL)
                                                                    .frame(width: UIScreen.main.bounds.width, height: UIDevice.current.userInterfaceIdiom == .pad ? 400 : 200)
                                                                    .clipped()
                                                            }
                                                        } else {
                                                            Rectangle()
                                                                .fill(Color.gray.opacity(0.3))
                                                                .frame(width: UIScreen.main.bounds.width, height: UIDevice.current.userInterfaceIdiom == .pad ? 400 : 200)
                                                        }
                                                    }
                                                    
                                                    // アイコンとタイトル・タグ
                                                    HStack(alignment: .center, spacing: 12) {
                                                        // Character or Anime icon
                                                        if let character = character, let imageIdentifier = character.imageIdentifier,
                                                           let uiImage = loadImageFromDocuments(imageIdentifier) {
                                                            Image(uiImage: uiImage)
                                                                .resizable()
                                                                .scaledToFill()
                                                                .frame(width: 43, height: 43)
                                                                .clipShape(Circle())
                                                        } else if let anime = anime, let imageIdentifier = anime.imageIdentifier,
                                                                  let uiImage = loadImageFromDocuments(imageIdentifier) {
                                                            Image(uiImage: uiImage)
                                                                .resizable()
                                                                .scaledToFill()
                                                                .frame(width: 43, height: 43)
                                                                .clipShape(Circle())
                                                        } else {
                                                            Circle()
                                                                .fill(Color.gray.opacity(0.3))
                                                                .frame(width: 43, height: 43)
                                                        }
                                                        
                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text(formatTitle(relatedArtwork.title, isVideoThumbnail: true))
                                                                .font(.system(size: 16.5, weight: .semibold))
                                                                .foregroundColor(.black)
                                                                .lineLimit(2)
                                                                .multilineTextAlignment(.leading)
                                                            
                                                            Text(character?.name ?? anime?.title ?? "アニメコレクター")
                                                                .font(.system(size: 12))
                                                                .foregroundColor(.gray)
                                                                .lineLimit(1)
                                                                .minimumScaleFactor(0.8)
                                                                .frame(alignment: .leading)
                                                            
                                                            Text(String(format: NSLocalizedString("views_times", comment: "%@ views"), formatViewCount(relatedArtwork.viewCount ?? 0)) + " · \(timeAgo(from: relatedArtwork.createdAt))")
                                                                .font(.system(size: 12))
                                                                .foregroundColor(.gray)
                                                        }
                                                        
                                                        Spacer(minLength: 0)
                                                    }
                                                    .padding(.horizontal, 16)
                                                }
                                            }
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                selectedArtwork = relatedArtwork
                                            }
                                        }
                                }
                                .padding(.bottom, 100) // 戻るボタンのためのスペースを確保
                            }
                        }
                        }
                    }
                }
                        .onChange(of: selectedArtwork) { _, newArtwork in
                            if let newArtwork = newArtwork {
                                // 新しい画像を表示
                                artwork = newArtwork
                                editTitle = newArtwork.title
                                editTags = newArtwork.tags.joined(separator: ",")
                                selectedArtwork = nil
                                // プレイヤーまで自動スクロール
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    scrollProxy.scrollTo("player", anchor: .top)
                                }
                            }
                        }
                    }
                    }
                
                // 戻るボタン
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        // Back button using onTapGesture for iPad compatibility
                        Text(NSLocalizedString("back", comment: "Back"))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(20)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                presentationMode.wrappedValue.dismiss()
                            }
                        .padding(.trailing, 24)
                        .padding(.bottom, 24)
                    }
                }
                .fullScreenCover(isPresented: $showFullscreen) {
                    FullScreenArtworkView(
                        imagePath: artwork.imagePath,
                        pixivURL: artwork.pixivURL,
                        customThumbnailData: artwork.customThumbnailData,
                        onDismiss: { showFullscreen = false }
                    )
                }
            }
        .navigationBarHidden(true)
        .onAppear {
            filteredArtworks = allArtworks
            loadCharacterVideos()
            // Increment view count
            incrementArtworkViewCount()
        }
        .sheet(isPresented: $showPixivRedirect) {
            if let pixivURL = artwork.pixivURL {
                PixivRedirectView(
                    pixivURL: pixivURL,
                    artwork: artwork,
                    onEdit: { newTitle, newTags in
                        // ローカルのartworkも更新
                        artwork.title = newTitle
                        artwork.tags = newTags
                        
                        // ビューを強制的に再描画
                        refreshID = UUID()
                        
                        onEdit?(newTitle, newTags)
                        onArtworkChange?(artwork)
                    },
                    onDelete: {
                        onDelete?()
                        presentationMode.wrappedValue.dismiss()
                    },
                    onThumbnailUpdate: { newThumbnailData in
                        // サムネイル更新の処理
                        var updatedArtwork = artwork
                        updatedArtwork.customThumbnailData = newThumbnailData
                        artwork = updatedArtwork
                        
                        // 親ビューにも変更を通知
                        onEdit?(artwork.title, artwork.tags)
                        onArtworkChange?(artwork)
                    }
                )
            }
        }
        .onAppear {
            editTitle = artwork.title
            editTags = artwork.tags.joined(separator: ",")
        }
        // Removed onChange modifiers that were interfering with user input
        .sheet(isPresented: $showMenuSheet) {
            VStack(spacing: 24) {
                Text(NSLocalizedString("edit_image", comment: "Edit image"))
                    .font(.headline)
                    .onAppear {
                        // シートが表示されるときに最新の値を設定
                        editTitle = artwork.title
                        editTags = artwork.tags.joined(separator: ",")
                    }
                // タイトル（編集不可）
                HStack {
                    Text("\(NSLocalizedString("title", comment: "Title")):")
                        .foregroundColor(.gray)
                    Text(editTitle)
                        .font(.system(size: 16, weight: .medium))
                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                // タグ（編集不可）
                HStack {
                    Text("\(NSLocalizedString("tags", comment: "Tags")):")
                        .foregroundColor(.gray)
                    Text(editTags)
                        .font(.system(size: 16, weight: .medium))
                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                // 保存ボタンを削除（コメントアウト）
                /*Button("タイトル・タグを保存") {
                    
                    let tagsArray = editTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    
                    
                    // withAnimationを使って確実に更新
                    withAnimation {
                        
                        // 新しいArtworkインスタンスを作成
                        let updatedArtwork = Artwork(
                            id: artwork.id,
                            characterId: artwork.characterId,
                            imagePath: artwork.imagePath,
                            title: editTitle,
                            tags: tagsArray,
                            createdAt: artwork.createdAt,
                            pixivURL: artwork.pixivURL,
                            twitterURL: artwork.twitterURL,
                            customThumbnailData: artwork.customThumbnailData,
                            viewCount: artwork.viewCount
                        )
                        
                        
                        artwork = updatedArtwork
                        
                        
                        // ビューを強制的に再描画
                        refreshID = UUID()
                    }
                    
                    // コールバック呼び出し
                    onEdit?(editTitle, tagsArray)
                    onArtworkChange?(artwork)
                    
                    // シートを閉じる
                    showMenuSheet = false
                }
                .font(.headline)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)*/
                Button(NSLocalizedString("delete_image", comment: "Delete image")) {
                    showDeleteAlert = true
                }
                .foregroundColor(.red)
                Button(NSLocalizedString("cancel", comment: "Cancel")) {
                    showMenuSheet = false
                }
            }
            .padding(32)
            .alert(isPresented: $showDeleteAlert) {
                Alert(
                    title: Text(NSLocalizedString("delete_image_confirm_title", comment: "Delete this image?")),
                    message: Text(NSLocalizedString("delete_image_confirm_message", comment: "This image will be permanently deleted.")),
                    primaryButton: .destructive(Text(NSLocalizedString("delete", comment: "Delete"))) {
                        onDelete?()
                        showMenuSheet = false
                        presentationMode.wrappedValue.dismiss()
                    },
                    secondaryButton: .cancel(Text(NSLocalizedString("cancel", comment: "Cancel")))
                )
            }
        }
        }
    }
}

struct FullScreenArtworkView: View {
    let imagePath: String?
    let pixivURL: String?
    let customThumbnailData: Data?
    var onDismiss: () -> Void
    
    init(imagePath: String? = nil, pixivURL: String? = nil, customThumbnailData: Data? = nil, onDismiss: @escaping () -> Void) {
        self.imagePath = imagePath
        self.pixivURL = pixivURL
        self.customThumbnailData = customThumbnailData
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // 画像を中央に配置
            if let imagePath = imagePath, let uiImage = loadImageFromPath(imagePath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
            } else if let pixivURL = pixivURL {
                // カスタムサムネイルがある場合はそれを表示
                if let customThumbnailData = customThumbnailData,
                   let uiImage = UIImage(data: customThumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    // Pixivから画像を読み込む
                    PixivFullscreenView(pixivURL: pixivURL)
                        .edgesIgnoringSafeArea(.all)
                }
            } else {
                Color.gray
            }
            
            // 戻るボタンを右上に配置
            VStack {
                HStack {
                    Spacer()
                    // Back button in fullscreen using onTapGesture for iPad compatibility
                    Text(NSLocalizedString("back", comment: "Back"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(20)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onDismiss()
                        }
                    .padding(.trailing, 24)
                    .padding(.top, 24)
                }
                Spacer()
            }
        }
    }
}

// MARK: - ArtworkInfoView
private struct ArtworkInfoView: View {
    @Binding var artwork: Artwork
    let character: Character?
    let anime: Anime?
    let showMenuSheet: () -> Void
    let showFullscreen: () -> Void
    let totalVideoViewCount: Int
    @State private var isLiked = false
    @State private var likeCount = 0
    
    private func formatTitle(_ title: String, isVideoThumbnail: Bool = false) -> String {
        if isVideoThumbnail {
            // For video/image titles: break at 17 chars, truncate after 33
            if title.count <= 17 {
                return title
            } else if title.count <= 33 {
                let firstLine = String(title.prefix(17))
                let secondLine = String(title.dropFirst(17))
                return firstLine + "\n" + secondLine
            } else {
                let firstLine = String(title.prefix(17))
                let secondLine = String(title.dropFirst(17).prefix(16)) + "..."
                return firstLine + "\n" + secondLine
            }
        } else {
            // For other titles: break at 9 chars, truncate after 17
            if title.count <= 9 {
                return title
            } else if title.count <= 17 {
                let firstLine = String(title.prefix(9))
                let secondLine = String(title.dropFirst(9))
                return firstLine + "\n" + secondLine
            } else {
                let firstLine = String(title.prefix(9))
                let secondLine = String(title.dropFirst(9).prefix(8)) + "..."
                return firstLine + "\n" + secondLine
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title and view info
            VStack(alignment: .leading, spacing: 8) {
                Text(formatTitle(artwork.title, isVideoThumbnail: true))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 4) {
                    Text("\(timeAgo(from: artwork.createdAt))")
                    Text(NSLocalizedString("see_more_dots", comment: "...Show more"))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .font(.system(size: 14))
                .foregroundColor(.gray)
            }
            
            // Channel/Character info (using character ID to fetch character info)
            HStack(alignment: .center, spacing: 12) {
                // Character or Anime icon
                if let character = character, let imageIdentifier = character.imageIdentifier,
                   let uiImage = loadImageFromDocuments(imageIdentifier) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else if let anime = anime, let imageIdentifier = anime.imageIdentifier,
                          let uiImage = loadImageFromDocuments(imageIdentifier) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(character?.name ?? anime?.title ?? "アニメコレクター")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(alignment: .leading)
                        .onAppear {
                        }
                }
                
                Spacer(minLength: 0)
                
                // Edit button using onTapGesture for iPad compatibility
                Text(NSLocalizedString("edit", comment: "Edit"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(20)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showMenuSheet()
                    }
                
                // Fullscreen button using onTapGesture for iPad compatibility
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 18))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(20)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showFullscreen()
                    }
            }
            
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .onAppear {
            likeCount = Int.random(in: 50...500)
        }
    }
    
    // Helper function for loading images
    private func loadImageFromDocuments(_ imagePath: String) -> UIImage? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imageURL = documentsPath.appendingPathComponent(imagePath)
        return UIImage(contentsOfFile: imageURL.path)
    }
    
    // Helper functions
    func loadImageFromPath(_ imagePath: String) -> UIImage? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imageURL = documentsPath.appendingPathComponent(imagePath)
        return UIImage(contentsOfFile: imageURL.path)
    }
    
    func formatViewCount(_ count: Int) -> String {
        if count >= 10000 {
            let formatted = Double(count) / 10000.0
            return String(format: "%.1f万", formatted)
        } else {
            return "\(count)"
        }
    }
    
    func timeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date, to: now)
        
        if let years = components.year, years > 0 {
            return String(format: NSLocalizedString("years_ago", comment: ""), years)
        } else if let months = components.month, months > 0 {
            return String(format: NSLocalizedString("months_ago", comment: ""), months)
        } else if let days = components.day, days > 0 {
            return String(format: NSLocalizedString("days_ago", comment: ""), days)
        } else if let hours = components.hour, hours > 0 {
            return String(format: NSLocalizedString("hours_ago", comment: ""), hours)
        } else if let minutes = components.minute, minutes > 0 {
            return String(format: NSLocalizedString("minutes_ago", comment: ""), minutes)
        } else {
            return NSLocalizedString("just_now", comment: "")
        }
    }
}

// Helper function for loading images from documents
func loadImageFromDocuments(_ imagePath: String) -> UIImage? {
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let imageURL = documentsPath.appendingPathComponent(imagePath)
    return UIImage(contentsOfFile: imageURL.path)
}

// MARK: - Helper Functions
extension ArtworkPlayerScreen {
    private func filterArtworks() {
        if searchText.isEmpty {
            filteredArtworks = allArtworks
        } else {
            filteredArtworks = allArtworks.filter { artwork in
                artwork.title.localizedCaseInsensitiveContains(searchText) ||
                artwork.tags.contains { tag in
                    tag.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
    }
    
    private func getRelatedArtworks() -> [Artwork] {
        let artworks = searchText.isEmpty ? allArtworks : filteredArtworks
        return artworks.filter { $0.id != artwork.id }
    }
} 