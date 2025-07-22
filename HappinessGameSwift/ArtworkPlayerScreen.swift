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
            return "\(years)年前"
        } else if let months = components.month, months > 0 {
            return "\(months)ヶ月前"
        } else if let days = components.day, days > 0 {
            return "\(days)日前"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)時間前"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)分前"
        } else {
            return "たった今"
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    // ヘッダー
                    HStack(spacing: 12) {
                        // ログインロゴ（左端に配置）
                        if let logoImage = UIImage(named: "ログインロゴ") {
                            Image(uiImage: logoImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 50)
                        }
                        
                        Spacer()
                        
                        // 検索バー（表示時）
                        if showSearchBar {
                            TextField("検索", text: $searchText, onCommit: {
                                filterArtworks()
                            })
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                            .frame(maxWidth: 200)
                        }
                        
                        // 虫眼鏡アイコン
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showSearchBar.toggle()
                                if !showSearchBar {
                                    searchText = ""
                                    filterArtworks()
                                }
                            }
                        }) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white)
                                .font(.system(size: 20))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black)
                    
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
                                        .aspectRatio(contentMode: .fill)
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
                                        Button(action: {
                                            showPixivRedirect = true
                                        }) {
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
                                        }
                                        .padding(.trailing, 12)
                                        .padding(.bottom, 8)
                                    }
                                }
                            }
                            .frame(width: geometry.size.width, height: geometry.size.width * 9.0 / 16.0)
                            .onTapGesture {
                                print("[DEBUG] ArtworkPlayerScreen: Pixiv画像タップ")
                                print("[DEBUG] artwork: \(artwork.title)")
                                print("[DEBUG] pixivURL: \(artwork.pixivURL ?? "nil")")
                                showPixivRedirect = true
                            }
                        } else {
                            Color.gray.opacity(0.2)
                                .frame(width: geometry.size.width, height: geometry.size.width * 9.0 / 16.0)
                        }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.width * 9.0 / 16.0)
                        .background(Color.black)
                        
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
                                Text("関連画像")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 16)
                                
                                LazyVStack(spacing: 0) {
                                    Spacer().frame(height: 5)
                                        ForEach(Array(getRelatedArtworks().enumerated()), id: \.element.id) { idx, relatedArtwork in
                                            if idx > 0 {
                                                Spacer().frame(height: 15.9)
                                            }
                                            Button(action: {
                                                selectedArtwork = relatedArtwork
                                            }) {
                                                VStack(alignment: .leading, spacing: 8) {
                                                    // サムネイル
                                                    if let imagePath = relatedArtwork.imagePath, let uiImage = loadImageFromPath(imagePath) {
                                                        Image(uiImage: uiImage)
                                                            .resizable()
                                                            .scaledToFill()
                                                            .frame(width: UIScreen.main.bounds.width, height: 200)
                                                            .clipped()
                                                    } else if let pixivURL = relatedArtwork.pixivURL {
                                                        if let customThumbnailData = relatedArtwork.customThumbnailData,
                                                           let uiImage = UIImage(data: customThumbnailData) {
                                                            Image(uiImage: uiImage)
                                                                .resizable()
                                                                .scaledToFill()
                                                                .frame(width: UIScreen.main.bounds.width, height: 200)
                                                                .clipped()
                                                        } else {
                                                            PixivThumbnailView(pixivURL: pixivURL)
                                                                .frame(width: UIScreen.main.bounds.width, height: 200)
                                                                .clipped()
                                                        }
                                                    } else {
                                                        Rectangle()
                                                            .fill(Color.gray.opacity(0.3))
                                                            .frame(width: UIScreen.main.bounds.width, height: 200)
                                                    }
                                                    
                                                    // アイコンとタイトル・タグ
                                                    HStack(alignment: .top, spacing: 12) {
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
                                                            Text(relatedArtwork.title)
                                                                .font(.system(size: 16.5, weight: .semibold))
                                                                .foregroundColor(.black)
                                                                .lineLimit(2)
                                                            
                                                            Text(character?.name ?? anime?.title ?? "アニメコレクター")
                                                                .font(.system(size: 12))
                                                                .foregroundColor(.gray)
                                                            
                                                            Text("\(formatViewCount(relatedArtwork.viewCount ?? 0))回・\(timeAgo(from: relatedArtwork.createdAt))")
                                                                .font(.system(size: 12))
                                                                .foregroundColor(.gray)
                                                        }
                                                        
                                                        Spacer()
                                                    }
                                                    .padding(.horizontal, 16)
                                                }
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                }
                                .padding(.bottom, 100) // 戻るボタンのためのスペースを確保
                            }
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
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("戻る")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.black.opacity(0.8))
                                .cornerRadius(20)
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
            print("[DEBUG] ArtworkPlayerScreen onAppear")
            print("[DEBUG] artwork.title = \(artwork.title)")
            print("[DEBUG] artwork.tags = \(artwork.tags)")
            editTitle = artwork.title
            editTags = artwork.tags.joined(separator: ",")
            print("[DEBUG] editTitle設定後 = \(editTitle)")
            print("[DEBUG] editTags設定後 = \(editTags)")
        }
        .onChange(of: selectedArtwork) { newArtwork in
            if let newArtwork = newArtwork {
                // 新しい画像を表示
                artwork = newArtwork
                editTitle = newArtwork.title
                editTags = newArtwork.tags.joined(separator: ",")
                selectedArtwork = nil
            }
        }
        // Removed onChange modifiers that were interfering with user input
        .sheet(isPresented: $showMenuSheet) {
            VStack(spacing: 24) {
                Text("画像の編集")
                    .font(.headline)
                    .onAppear {
                        // シートが表示されるときに最新の値を設定
                        print("[DEBUG] ArtworkPlayerScreen sheet onAppear")
                        print("[DEBUG] 現在の artwork.title = \(artwork.title)")
                        print("[DEBUG] 現在の artwork.tags = \(artwork.tags)")
                        editTitle = artwork.title
                        editTags = artwork.tags.joined(separator: ",")
                        print("[DEBUG] 設定後の editTitle = \(editTitle)")
                        print("[DEBUG] 設定後の editTags = \(editTags)")
                    }
                // タイトル（編集不可）
                HStack {
                    Text("タイトル:")
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
                    Text("タグ:")
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
                    print("[DEBUG] ArtworkPlayerScreen: 保存ボタンが押されました")
                    print("[DEBUG] ArtworkPlayerScreen: editTitle = \(editTitle)")
                    print("[DEBUG] ArtworkPlayerScreen: editTags = \(editTags)")
                    
                    let tagsArray = editTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    
                    print("[DEBUG] ArtworkPlayerScreen: 更新前 artwork.title = \(artwork.title)")
                    print("[DEBUG] ArtworkPlayerScreen: 更新前 artwork.tags = \(artwork.tags)")
                    
                    // withAnimationを使って確実に更新
                    withAnimation {
                        print("[DEBUG] withAnimation内: editTitle = \(editTitle)")
                        print("[DEBUG] withAnimation内: tagsArray = \(tagsArray)")
                        
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
                        
                        print("[DEBUG] 新しいArtwork作成後: updatedArtwork.title = \(updatedArtwork.title)")
                        print("[DEBUG] 新しいArtwork作成後: updatedArtwork.tags = \(updatedArtwork.tags)")
                        
                        artwork = updatedArtwork
                        
                        print("[DEBUG] ArtworkPlayerScreen: 更新後 artwork.title = \(artwork.title)")
                        print("[DEBUG] ArtworkPlayerScreen: 更新後 artwork.tags = \(artwork.tags)")
                        
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
                Button("画像を削除") {
                    showDeleteAlert = true
                }
                .foregroundColor(.red)
                Button("キャンセル") {
                    showMenuSheet = false
                }
            }
            .padding(32)
            .alert(isPresented: $showDeleteAlert) {
                Alert(
                    title: Text("本当に削除しますか？"),
                    message: Text("この画像は完全に削除されます。"),
                    primaryButton: .destructive(Text("削除")) {
                        onDelete?()
                        showMenuSheet = false
                        presentationMode.wrappedValue.dismiss()
                    },
                    secondaryButton: .cancel(Text("キャンセル"))
                )
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
                    Button(action: { onDismiss() }) {
                        Text("戻る")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(20)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title and view info
            VStack(alignment: .leading, spacing: 8) {
                Text(artwork.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                
                HStack(spacing: 4) {
                    Text("\(timeAgo(from: artwork.createdAt))")
                    Text("...もっと見る")
                        .foregroundColor(.gray)
                    Spacer()
                }
                .font(.system(size: 14))
                .foregroundColor(.gray)
            }
            
            // Channel/Character info (using character ID to fetch character info)
            HStack(spacing: 12) {
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
                        .onAppear {
                            print("[DEBUG] ArtworkInfoView - character: \(character?.name ?? "nil")")
                            print("[DEBUG] ArtworkInfoView - anime: \(anime?.title ?? "nil")")
                            print("[DEBUG] ArtworkInfoView - character.imageIdentifier: \(character?.imageIdentifier ?? "nil")")
                        }
                }
                
                Spacer()
                
                Button(action: {
                    print("[DEBUG] 編集ボタンがタップされました")
                    showMenuSheet()
                }) {
                    Text("編集")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(20)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Fullscreen button
                Button(action: {
                    print("[DEBUG] 拡大ボタンがタップされました")
                    showFullscreen()
                }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 18))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(20)
                }
                .buttonStyle(PlainButtonStyle())
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
            return "\(years)年前"
        } else if let months = components.month, months > 0 {
            return "\(months)ヶ月前"
        } else if let days = components.day, days > 0 {
            return "\(days)日前"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)時間前"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)分前"
        } else {
            return "たった今"
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