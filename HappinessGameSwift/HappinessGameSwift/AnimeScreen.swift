// swiftlint:disable file_length
import SwiftUI
import PhotosUI
import UIKit
import Foundation
import Photos
import AVFoundation
import AVKit

fileprivate func daysInMonth(_ month: Int) -> Int {
    let calendar = Calendar.current
    let dateComponents = DateComponents(year: 2000, month: month)
    let date = calendar.date(from: dateComponents) ?? Date()
    return calendar.range(of: .day, in: .month, for: date)?.count ?? 30
}

// アニメデータ管理用のObservableObject
class AnimeManager: ObservableObject {
    @Published var animes: [Anime] = []
    
    init() {
        loadAnimes()
    }
    
    func loadAnimes() {
        if let data = UserDefaults.standard.data(forKey: "animes"),
           let decoded = try? JSONDecoder().decode([Anime].self, from: data) {
            print("[DEBUG] loadAnimes: 読み込んだアニメ数=\(decoded.count)")
            for a in decoded { print("[DEBUG] アニメID=\(a.id), title=\(a.title), customFields=\(String(describing: a.customFields))") }
            animes = decoded
        } else {
            print("[DEBUG] loadAnimes: データなし or デコード失敗")
        }
    }
    
    func saveAnimes() {
        if let data = try? JSONEncoder().encode(animes) {
            UserDefaults.standard.set(data, forKey: "animes")
            print("[DEBUG] saveAnimes: 保存アニメ数=\(animes.count)")
            for a in animes { print("[DEBUG] 保存アニメID=\(a.id), title=\(a.title), customFields=\(String(describing: a.customFields))") }
        } else {
            print("[DEBUG] saveAnimes: エンコード失敗")
        }
    }
    
    func updateAnime(_ updatedAnime: Anime) {
        print("[DEBUG] updateAnime: 更新アニメID=\(updatedAnime.id), title=\(updatedAnime.title), customFields=\(String(describing: updatedAnime.customFields))")
        if let idx = animes.firstIndex(where: { $0.id == updatedAnime.id }) {
            animes[idx] = updatedAnime
            saveAnimes()
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        } else {
            print("[DEBUG] updateAnime: アニメID見つからず")
        }
    }
    
    func addAnime(_ anime: Anime) {
        let exists = animes.contains { $0.id == anime.id }
        print("[DEBUG] addAnime: 追加アニメID=\(anime.id), title=\(anime.title), customFields=\(String(describing: anime.customFields)), exists=\(exists)")
        if !exists {
            animes.append(anime)
            saveAnimes()
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    // UI更新用のメソッド
    func refreshUI() {
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
}

// カスタムフィールド用構造体
struct AnimeCustomField: Hashable, Codable {
    var name: String
    var value: String
}

struct Anime: Identifiable, Hashable, Equatable, Codable {
    let id: UUID
    var imageIdentifier: String?
    var title: String
    var hashtag: String
    var releaseDate: Date
    var customFields: [AnimeCustomField]?
    // 必要に応じて他の属性も追加可能
    static func == (lhs: Anime, rhs: Anime) -> Bool {
        lhs.id == rhs.id
    }
    enum CodingKeys: String, CodingKey {
        case id, imageIdentifier, title, hashtag, releaseDate, customFields
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(hashtag, forKey: .hashtag)
        try container.encode(releaseDate, forKey: .releaseDate)
        try container.encodeIfPresent(imageIdentifier, forKey: .imageIdentifier)
        try container.encodeIfPresent(customFields, forKey: .customFields)
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        hashtag = try container.decode(String.self, forKey: .hashtag)
        releaseDate = try container.decode(Date.self, forKey: .releaseDate)
        imageIdentifier = try? container.decodeIfPresent(String.self, forKey: .imageIdentifier)
        customFields = try? container.decodeIfPresent([AnimeCustomField].self, forKey: .customFields)
    }
    init(id: UUID, imageIdentifier: String?, title: String, hashtag: String, releaseDate: Date, customFields: [AnimeCustomField]? = nil) {
        self.id = id
        self.imageIdentifier = imageIdentifier
        self.title = title
        self.hashtag = hashtag
        self.releaseDate = releaseDate
        self.customFields = customFields
    }
}

struct AnimeScreen: View {
    @StateObject private var animeManager = AnimeManager()
    @State private var showAddSheet = false
    @State private var selectedTab: AnimeTab = .all
    @State private var selectedAnime: Anime? = nil
    @State private var showMenu = false
    @EnvironmentObject var mainTab: MainTabSelection
    
    enum AnimeTab: String, CaseIterable {
        case all = "ALL"
        case willWatch = "Will watch"
        case watchAgain = "Watch Again"
        case thisTerm = "This term"
    }
    
    var filteredAnimes: [Anime] {
        switch selectedTab {
        case .all:
            return animeManager.animes
        case .willWatch:
            return animeManager.animes.filter { $0.hashtag.contains("will watch") }
        case .watchAgain:
            return animeManager.animes.filter { $0.hashtag.contains("watch again") }
        case .thisTerm:
            // Implementation needed
            return []
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        showMenu.toggle()
                    }) {
                        Image(systemName: "line.horizontal.3")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                    }
                    Spacer()
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                // タブUI
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(AnimeTab.allCases, id: \ .self) { tab in
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
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredAnimes, id: \.id) { anime in
                            Button(action: {
                                selectedAnime = anime
                            }) {
                                AnimeRow(anime: anime, animeManager: animeManager)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.bottom, 75)
                }
            }
        }
        .sheet(isPresented: $showAddSheet, onDismiss: {
            animeManager.loadAnimes()
        }) {
            AddAnimeSheet(animes: $animeManager.animes)
                .environmentObject(animeManager)
        }
        .fullScreenCover(item: $selectedAnime) { anime in
            AnimeDetailView(anime: Binding(
                get: { anime },
                set: { newAnime in
                    if let idx = animeManager.animes.firstIndex(where: { $0.id == anime.id }) {
                        animeManager.animes[idx] = newAnime
                        animeManager.updateAnime(newAnime)
                    }
                    selectedAnime = newAnime
                }
            ), animes: $animeManager.animes, onDismiss: {
                selectedAnime = nil
                animeManager.refreshUI()
            })
            .environmentObject(animeManager)
        }
    }
}

// アニメ一覧の1行
struct AnimeRow: View {
    let anime: Anime
    @ObservedObject var animeManager: AnimeManager
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            if let imageIdentifier = anime.imageIdentifier, let image = UIImage(contentsOfFile: imageIdentifier) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 183, height: 99)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .clipped()
                    .offset(x: -10)
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 183, height: 99)
                    .offset(x: -10)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(anime.title)
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(height: 20)
                Text("#" + anime.hashtag)
                    .font(.system(size: 12.8, weight: .regular))
                    .foregroundColor(.gray)
                    .frame(height: 20)
            }
            .offset(x: -10, y: -15)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}

struct AnimeArtworkScreen: View {
    @Binding var anime: Anime
    @Binding var animes: [Anime]
    @Environment(\.presentationMode) var presentationMode
    @State private var artworks: [Artwork] = []
    @State private var showAddSheet = false
    @State private var selectedImage: UIImage? = nil
    @State private var photoTitle: String = ""
    @State private var photoTags: String = ""
    @State private var showAlbum = false
    @State private var showTagInput = false
    @State private var newTag: String = ""
    @State private var filteredTags: [String] = []
    @State private var showActionSheet = false
    @State private var selectedArtwork: Artwork? = nil
    @State private var showEditTitle = false
    @State private var showEditTags = false
    @State private var editText = ""
    @State private var showDeleteAlert = false
    @State private var deletingArtworkID: UUID? = nil
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 0) {
                    // 戻るボタン
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.black)
                            .font(.system(size: 24, weight: .bold))
                            .padding(.leading, 8)
                            .offset(x: -19)
                    }
                    Spacer()
                    // アニメ名
                    HStack {
                        Spacer().frame(width: 0)
                        Text(anime.title)
                            .font(.system(size: 25, weight: .bold))
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                            .offset(x: -15)
                        Spacer()
                    }
                    // Uploadボタン（右端に揃える）
                    Button(action: { showAddSheet = true }) {
                        Text("Upload")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.black)
                            .cornerRadius(8)
                    }
                    .padding(.trailing, 16)
                }
                .frame(height: 56)
                .padding(.top, 8)
                .padding(.leading, 30)

                // タブバー
                HStack(spacing: 0) {
                    Spacer(minLength: 70)
                    Button(action: { showAlbum = false }) {
                        VStack(spacing: 2) {
                            Text("ArtWork")
                                .font(.headline)
                                .foregroundColor(.black)
                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(showAlbum == false ? .black : .clear)
                        }
                    }
                    Spacer()
                    Button(action: { showAlbum = true }) {
                        VStack(spacing: 2) {
                            Text("Album")
                                .font(.headline)
                                .foregroundColor(.black)
                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(showAlbum == true ? .black : .clear)
                        }
                    }
                    Spacer(minLength: 80)
                }
                .frame(height: 40)
                
                // 画像リスト or Album
                ZStack {
                    if showAlbum {
                        ScrollView {
                            AlbumGridView(artworks: artworks, highlightFirstRow: false, filteredTags: filteredTags.isEmpty ? nil : filteredTags, selectedArtwork: $selectedArtwork)
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: 32) {
                                ForEach(artworks, id: \ .id) { artwork in
                                    if let imagePath = artwork.imagePath, let uiImage = UIImage(contentsOfFile: imagePath) {
                                        VStack(alignment: .leading, spacing: 0) {
                                            GeometryReader { geometry in
                                                ZStack {
                                                    Color.white
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: geometry.size.width, height: 233)
                                                        .clipped()
                                                }
                                                .frame(width: geometry.size.width, height: 233)
                                                .clipped()
                                                .padding(.bottom, 0)
                                            }
                                            .frame(height: 233)
                                            HStack(alignment: .center, spacing: 12) {
                                                if let imageIdentifier = anime.imageIdentifier, let image = UIImage(contentsOfFile: imageIdentifier) {
                                                    Image(uiImage: image)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: 40, height: 40)
                                                        .clipShape(Circle())
                                                } else {
                                                    Circle()
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(width: 40, height: 40)
                                                        .overlay(
                                                            Image(systemName: "film")
                                                                .font(.system(size: 20))
                                                                .foregroundColor(.gray)
                                                        )
                                                }
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(artwork.title)
                                                        .font(.headline)
                                                        .foregroundColor(.black)
                                                    Text("#nakajimaginsei")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                            .padding(.top, 8)
                                            .padding(.leading, 8)
                                        }
                                        .padding(.vertical, 8)
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                }
            }
            // Albumタブ時のみ右下に＋ボタン
            if showAlbum {
                Button(action: { showTagInput = true }) {
                    Image(systemName: "number")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.black)
                        .clipShape(Circle())
                        .shadow(radius: 6)
                        .padding(.bottom, 32)
                        .padding(.trailing, 24)
                }
                .sheet(isPresented: $showTagInput) {
                    VStack(spacing: 24) {
                        Text("表示したいタグを入力")
                            .font(.headline)
                        TextField("#タグ名", text: $newTag)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal, 24)
                        Button("追加") {
                            let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !tag.isEmpty && !filteredTags.contains(tag) {
                                filteredTags.append(tag)
                            }
                            newTag = ""
                            showTagInput = false
                        }
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 10)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        Button("キャンセル") {
                            showTagInput = false
                        }
                        .foregroundColor(.red)
                    }
                    .padding(32)
                }
            }
        }
        .onAppear {
            loadArtworks()
        }
        .sheet(isPresented: $showAddSheet) {
            AddPhotoView(selectedImage: $selectedImage, photoTitle: $photoTitle, photoTags: $photoTags) {
                if !photoTitle.trimmingCharacters(in: .whitespaces).isEmpty && !photoTags.trimmingCharacters(in: .whitespaces).isEmpty {
                    saveArtwork()
                }
            }
        }
        .sheet(item: $selectedArtwork) { artwork in
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 24) {
                    Spacer()
                    if let imagePath = artwork.imagePath, let uiImage = UIImage(contentsOfFile: imagePath) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: 400)
                            .clipped()
                            .cornerRadius(24)
                    } else {
                        Text("画像データがありません")
                            .foregroundColor(.gray)
                    }
                    VStack(spacing: 16) {
                        HStack(spacing: 8) {
                            Text("タイトル: \(artwork.title)")
                                .font(.headline)
                            Button(action: {
                                editText = artwork.title
                                showEditTitle = true
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.blue)
                            }
                        }
                        HStack(spacing: 8) {
                            Text("タグ: \(artwork.tags.joined(separator: ", "))")
                                .font(.subheadline)
                            Button(action: {
                                editText = artwork.tags.joined(separator: ",")
                                showEditTags = true
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.blue)
                            }
                        }
                        Text("ID: \(artwork.id.uuidString.prefix(8))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                // 右下に閉じるボタンとゴミ箱ボタンを横並びで配置
                HStack(spacing: 24) {
                    Spacer()
                    Button(action: {
                        selectedArtwork = nil
                    }) {
                        Text("閉じる")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 10)
                            .background(Color.black)
                            .cornerRadius(10)
                    }
                    .padding(.trailing, 78)
                    Button(action: {
                        deletingArtworkID = selectedArtwork?.id
                        showDeleteAlert = true
                    }) {
                        Image(systemName: "trash")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.black)
                    }
                }
                .padding([.bottom, .trailing], 24)
                // --- カスタムダイアログ ---
                if showEditTitle {
                    Color.black.opacity(0.25)
                        .edgesIgnoringSafeArea(.all)
                    VStack(spacing: 20) {
                        Text("タイトル名を編集")
                            .font(.headline)
                            .padding(.top, 12)
                        TextField("タイトル", text: $editText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 18))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        HStack(spacing: 24) {
                            Button(action: { showEditTitle = false }) {
                                Text("キャンセル")
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            Button(action: {
                                if let idx = artworks.firstIndex(where: { $0.id == artwork.id }) {
                                    artworks[idx] = Artwork(id: artworks[idx].id, characterId: artworks[idx].characterId, imagePath: artworks[idx].imagePath, title: editText, tags: artworks[idx].tags, date: artworks[idx].date)
                                    saveArtworksToUserDefaults()
                                }
                                showEditTitle = false
                            }) {
                                Text("保存")
                                    .foregroundColor(.blue)
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    }
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(radius: 16)
                    .frame(maxWidth: 340)
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                if showDeleteAlert {
                    Color.black.opacity(0.25)
                        .edgesIgnoringSafeArea(.all)
                    VStack(spacing: 20) {
                        Text("本当に削除しますか？")
                            .font(.headline)
                            .padding(.top, 12)
                        HStack(spacing: 24) {
                            Button(action: {
                                showDeleteAlert = false
                                deletingArtworkID = nil
                            }) {
                                Text("キャンセル")
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            Button(action: {
                                if let delID = deletingArtworkID,
                                   let idx = artworks.firstIndex(where: { $0.id == delID }) {
                                    artworks.remove(at: idx)
                                    saveArtworksToUserDefaults()
                                }
                                showDeleteAlert = false
                                deletingArtworkID = nil
                                selectedArtwork = nil
                            }) {
                                Text("削除")
                                    .foregroundColor(.red)
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    }
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(radius: 16)
                    .frame(maxWidth: 340)
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                // --- END カスタムダイアログ ---
            }
        }
    }
    
    private func saveArtwork() {
        guard let image = selectedImage, let _ = image.jpegData(compressionQuality: 0.8) else { return }
        let tags = photoTags.isEmpty ? [] : photoTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        // 画像を保存
        let fileName = "anime_artwork_\(UUID().uuidString).png"
        let path = saveImageToDocuments(image, fileName: fileName)
        let newArtwork = Artwork(id: UUID(), characterId: anime.id, imagePath: path, title: photoTitle, tags: tags, date: Date())
        artworks.insert(newArtwork, at: 0)
        saveArtworksToUserDefaults()
        selectedImage = nil
        photoTitle = ""
        photoTags = ""
        showAddSheet = false
    }
    
    private func loadArtworks() {
        let key = "anime_artworks_\(anime.id.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key),
           let decodedArtworks = try? JSONDecoder().decode([Artwork].self, from: data) {
            artworks = decodedArtworks
        }
    }
    
    private func saveArtworksToUserDefaults() {
        let key = "anime_artworks_\(anime.id.uuidString)"
        if let encodedData = try? JSONEncoder().encode(artworks) {
            UserDefaults.standard.set(encodedData, forKey: key)
        }
    }
}

struct AnimeVideoRowView: View {
    let video: MemoryVideo
    let anime: Anime
    let playingVideoId: UUID?
    let onPlay: () -> Void
    let onClose: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if playingVideoId == video.id {
                VideoInlinePlayer(video: video, onClose: onClose)
                    .frame(width: UIScreen.main.bounds.width * 0.9, height: (UIScreen.main.bounds.width * 0.9) * 9 / 16)
                    .cornerRadius(20)
            } else {
                VideoThumbnailPlayer(video: video, isInModal: false, onTap: onPlay)
                    .frame(width: UIScreen.main.bounds.width * 0.9, height: (UIScreen.main.bounds.width * 0.9) * 9 / 16)
                    .cornerRadius(20)
            }
            HStack(alignment: .center, spacing: 12) {
                if let imageIdentifier = anime.imageIdentifier, let image = UIImage(contentsOfFile: imageIdentifier) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "film")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        )
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(video.title)
                        .font(.headline)
                    if !video.tags.isEmpty {
                        Text("#" + video.tags.joined(separator: " #"))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
    }
}

struct AnimeVideoScreen: View {
    @Binding var anime: Anime
    @Binding var animes: [Anime]
    @Environment(\.presentationMode) var presentationMode
    @State private var videos: [MemoryVideo] = []
    @State private var showAddSheet = false
    @State private var selectedVideoURL: URL? = nil
    @State private var videoTitle: String = ""
    @State private var videoTags: String = ""
    @State private var showAlbum = false
    @State private var showTagInput = false
    @State private var newTag: String = ""
    @State private var filteredTags: [String] = []
    @State private var selectedVideo: MemoryVideo? = nil
    @State private var showEditTitle = false
    @State private var showEditTags = false
    @State private var editText = ""
    @State private var showDeleteAlert = false
    @State private var deletingVideoID: UUID? = nil
    @State private var selectedThumbnailData: Data? = nil
    @State private var expandedVideo: MemoryVideo? = nil
    @State private var playingVideoId: UUID? = nil
    @State private var albums: [Album] = []
    @State private var selectedAlbum: Album? = nil

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 0) {
                    // 戻るボタン
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.black)
                            .font(.system(size: 24, weight: .bold))
                            .padding(.leading, 8)
                            .offset(x: -19)
                    }
                    Spacer()
                    // アニメ名
                    HStack {
                        Spacer().frame(width: 0)
                        Text(anime.title)
                            .font(.system(size: 25, weight: .bold))
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                            .offset(x: -15)
                        Spacer()
                    }
                    // Uploadボタン（右端に揃える）
                    Button(action: { showAddSheet = true }) {
                        Text("Upload")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.black)
                            .cornerRadius(8)
                    }
                    .padding(.trailing, 16)
                }
                .frame(height: 56)
                .padding(.top, 8)
                .padding(.leading, 30)

                // タブバー
                HStack(spacing: 0) {
                    Spacer(minLength: 70)
                    Button(action: { showAlbum = false }) {
                        VStack(spacing: 2) {
                            Text("Video")
                                .font(.headline)
                                .foregroundColor(.black)
                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(showAlbum == false ? .black : .clear)
                        }
                    }
                    Spacer()
                    Button(action: { showAlbum = true }) {
                        VStack(spacing: 2) {
                            Text("Album")
                                .font(.headline)
                                .foregroundColor(.black)
                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(showAlbum == true ? .black : .clear)
                        }
                    }
                    Spacer(minLength: 80)
                }
                .frame(height: 40)
                // 動画リスト or Album
                ZStack {
                    if showAlbum {
                        ScrollView {
                            VStack(spacing: 4) {
                                Spacer().frame(height: 5)
                                // --- アルバムリスト ---
                                ForEach(albums) { album in
                                    Button(action: {
                                        selectedAlbum = album
                                    }) {
                                        VStack(alignment: .leading, spacing: 0) {
                                            if let firstVideo = album.videos.first, let thumbnailData = firstVideo.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                                                GeometryReader { geometry in
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: geometry.size.width, height: 233)
                                                        .clipped()
                                                }
                                                .frame(height: 233)
                                            } else {
                                                GeometryReader { geometry in
                                                    RoundedRectangle(cornerRadius: 0, style: .continuous)
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(width: geometry.size.width, height: 233)
                                                }
                                                .frame(height: 233)
                                            }
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("#" + album.tag)
                                                    .font(.system(size: 15.5, weight: .semibold))
                                                    .foregroundColor(.black)
                                            }
                                            .padding(.top, 8)
                                            .padding(.leading, 8)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .fullScreenCover(item: $selectedAlbum) { album in
                            AlbumVideoListScreen(
                                videos: album.videos, 
                                tag: album.tag,
                                onVideoDeleted: { deletedVideo in
                                    // 動画リストから削除
                                    if let idx = videos.firstIndex(where: { $0.id == deletedVideo.id }) {
                                        videos.remove(at: idx)
                                        print("[DEBUG] AnimeScreen: Albumから動画削除 - ID: \(deletedVideo.id)")
                                        
                                        // Albumタブの動画リストも更新
                                        updateAlbumsAfterVideoDeletion(deletedVideoId: deletedVideo.id)
                                        
                                        saveVideosToUserDefaults()
                                        print("[DEBUG] AnimeScreen: UserDefaultsに保存しました")
                                    }
                                }
                            )
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                Spacer().frame(height: 5)
                                ForEach(Array(videos.enumerated()), id: \ .element.id) { idx, video in
                                    if idx > 0 {
                                        Spacer().frame(height: 35)
                                    }
                                    Button(action: {
                                        selectedVideo = video
                                    }) {
                                        HStack(alignment: .top, spacing: 16) {
                                            if let thumbnailData = video.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 183, height: 109)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                    .clipped()
                                            } else {
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .fill(Color.gray.opacity(0.3))
                                                    .frame(width: 183, height: 109)
                                            }
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(video.title)
                                                    .font(.system(size: 16.5, weight: .semibold))
                                                    .foregroundColor(.black)
                                                    .padding(.vertical, 8)
                                                Text(video.tags.isEmpty ? "#nakajimaginsei" : "#" + video.tags.joined(separator: " #"))
                                                    .font(.system(size: 13.8, weight: .regular))
                                                    .foregroundColor(.gray)
                                                    .padding(.vertical, 2)
                                            }
                                            .frame(height: 50, alignment: .leading)
                                            .padding(.top, 3)
                                            .padding(.leading, 8)
                                            Spacer()
                                            Button(action: {
                                                selectedVideo = video
                                                showEditTitle = true // 必要に応じてActionSheetや編集処理
                                            }) {
                                                Image(systemName: "ellipsis.vertical")
                                                    .font(.system(size: 23))
                                                    .foregroundColor(.black)
                                                    .padding(.trailing, 8)
                                            }
                                        }
                                        .padding(.leading, 8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .fullScreenCover(item: $selectedVideo) { video in
                            VideoPlayerScreen(
                                video: video,
                                character: nil,
                                anime: anime,
                                allVideos: videos,
                                onSave: { newTitle, newTags in
                                    // 編集処理（必要ならここも拡張）
                                },
                                onDelete: {
                                    if let idx = videos.firstIndex(where: { $0.id == video.id }) {
                                        videos.remove(at: idx)
                                        saveVideosToUserDefaults()
                                        print("[DEBUG] AnimeVideoScreen: 動画削除 - ID: \(video.id)")
                                    } else {
                                        print("[DEBUG] AnimeVideoScreen: 削除対象が見つかりませんでした - ID: \(video.id)")
                                    }
                                }
                            )
                        }
                    }
                }
            }
            // Albumタブ時のみ右下に＋ボタン
            if showAlbum {
                Button(action: { showTagInput = true }) {
                    Image(systemName: "number")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.black)
                        .clipShape(Circle())
                        .shadow(radius: 6)
                        .padding(.bottom, 32)
                        .padding(.trailing, 24)
                }
                .sheet(isPresented: $showTagInput) {
                    VStack(spacing: 24) {
                        Text("表示したいタグを入力")
                            .font(.headline)
                        TextField("#タグ名", text: $newTag)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal, 24)
                        Button("保存") {
                            let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !tag.isEmpty {
                                let tagVideos = videos.filter { $0.tags.contains(where: { $0 == tag }) }
                                if !tagVideos.isEmpty {
                                    albums.append(Album(tag: tag, videos: tagVideos))
                                }
                            }
                            newTag = ""
                            showTagInput = false
                        }
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 10)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        Button("キャンセル") {
                            showTagInput = false
                        }
                        .foregroundColor(.red)
                    }
                    .padding(32)
                }
            }
        }
        .onAppear {
            loadVideos()
        }
        .sheet(isPresented: $showAddSheet) {
            AddVideoView(selectedVideoURL: $selectedVideoURL, videoTitle: $videoTitle, videoTags: $videoTags, selectedThumbnailData: $selectedThumbnailData) {
                if selectedVideoURL != nil && !videoTitle.trimmingCharacters(in: .whitespaces).isEmpty && !videoTags.trimmingCharacters(in: .whitespaces).isEmpty {
                    Task {
                        await saveVideo()
                    }
                }
            }
        }
    }
    
    private func saveVideo() async {
        guard let videoURL = selectedVideoURL else { return }
        let tags = videoTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        // 動画ファイルをDocumentsディレクトリに保存
        let fileName = "anime_video_\(UUID().uuidString).mov"
        let documentsPath = saveVideoToDocuments(from: videoURL, fileName: fileName)
        
        // サムネイル生成
        var thumbnailData: Data? = selectedThumbnailData
        if thumbnailData == nil {
            let asset = AVURLAsset(url: videoURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            do {
                let cgImage = try await imageGenerator.image(at: CMTime(seconds: 1.0, preferredTimescale: 1))
                let uiImage = UIImage(cgImage: cgImage.image)
                thumbnailData = uiImage.jpegData(compressionQuality: 0.8)
            } catch {
                print("サムネイル生成に失敗: \(error)")
            }
        }
        
        let newVideo = MemoryVideo(id: UUID(), characterId: anime.id, videoPath: documentsPath, thumbnailData: thumbnailData, title: videoTitle, tags: tags, date: Date())
        videos.insert(newVideo, at: 0)
        saveVideosToUserDefaults()
        selectedVideoURL = nil
        videoTitle = ""
        videoTags = ""
        selectedThumbnailData = nil
        showAddSheet = false
    }
    
    private func saveVideoToDocuments(from url: URL, fileName: String) -> String {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentsURL = urls.first else { return "" }
        let fileURL = documentsURL.appendingPathComponent(fileName)
        
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            try fileManager.copyItem(at: url, to: fileURL)
            return fileURL.path
        } catch {
            print("動画保存エラー: \(error)")
            return ""
        }
    }
    
    private func loadVideos() {
        let key = "anime_videos_\(anime.id.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key),
           let decodedVideos = try? JSONDecoder().decode([MemoryVideo].self, from: data) {
            videos = decodedVideos
        }
    }
    
    private func saveVideosToUserDefaults() {
        let key = "anime_videos_\(anime.id.uuidString)"
        if let encodedData = try? JSONEncoder().encode(videos) {
            UserDefaults.standard.set(encodedData, forKey: key)
            print("AnimeVideoScreen: UserDefaults保存完了 - 動画数: \(videos.count)")
        }
    }
    
    private func updateAlbumsAfterVideoDeletion(deletedVideoId: UUID) {
        // 各Albumから削除された動画を除去
        albums = albums.compactMap { album in
            let updatedVideos = album.videos.filter { $0.id != deletedVideoId }
            // 動画が1つも残っていない場合はAlbumを削除
            if updatedVideos.isEmpty {
                return nil
            }
            // 動画が残っている場合は更新されたAlbumを返す
            return Album(tag: album.tag, videos: updatedVideos)
        }
        print("[DEBUG] AnimeVideoScreen: Album更新完了 - 残りAlbum数: \(albums.count)")
    }
}

struct AnimeAboutView: View {
    @Binding var anime: Anime
    @Binding var animes: [Anime]
    let onClose: () -> Void
    @State private var showEditNameModal = false
    @State private var showEditReleaseDateModal = false
    @State private var showEditIconModal = false
    @State private var editName: String = ""
    @State private var editHashtag: String = ""
    @State private var editReleaseDate: Date = Date()
    @State private var iconPickerItem: PhotosPickerItem? = nil
    @State private var iconImage: UIImage? = nil
    @State private var tempIconImage: UIImage? = nil
    @State private var showAddFieldPopup = false
    @State private var newFieldName = ""
    @State private var newFieldValue = ""
    @State private var showEditFieldPopup = false
    @State private var editFieldIndex: Int? = nil
    @State private var editFieldName = ""
    @State private var editFieldValue = ""
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var animeManager: AnimeManager
    
    var body: some View {
        GeometryReader { geometry in
            let currentAnime = animeManager.animes.first(where: { $0.id == anime.id }) ?? anime
            let nameText = currentAnime.title
            let releaseDateText = DateFormatter.monthDayEnglish.string(from: currentAnime.releaseDate)
            
            ZStack(alignment: .topLeading) {
                Color(.systemBackground).ignoresSafeArea()
                Button(action: {
                    onClose()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.black)
                            .font(.system(size: 18, weight: .medium))
                        Text("Back")
                            .foregroundColor(.black)
                            .font(.system(size: 17, weight: .medium))
                    }
                }
                .padding(.top, 24)
                .padding(.leading, 16)
                
                // メインコンテンツ
                VStack {
                    Spacer().frame(height: 180 + 50)
                    ZStack {
                        if let imageIdentifier = currentAnime.imageIdentifier, let image = UIImage(contentsOfFile: imageIdentifier) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .shadow(radius: 8)
                        } else {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 120, height: 120)
                                .shadow(radius: 8)
                                .overlay(
                                    Image(systemName: "person")
                                        .font(.system(size: 50))
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { showEditIconModal = true }
                    
                    // タイトル
                    Text(nameText)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.top, 20)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .onTapGesture {
                            editName = currentAnime.title
                            editHashtag = currentAnime.hashtag
                            showEditNameModal = true
                        }
                    
                    // 公開日
                    Text(releaseDateText.uppercased())
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .onTapGesture {
                            editReleaseDate = currentAnime.releaseDate
                            showEditReleaseDateModal = true
                        }
                    
                    // カスタムフィールド
                    VStack(spacing: 20) {
                        HStack {
                            Spacer()
                            Button(action: { showAddFieldPopup = true }) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.top, 40)
                        
                        ForEach(Array((currentAnime.customFields ?? []).enumerated()), id: \.element.name) { index, field in
                            HStack {
                                Text(field.name)
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                                Text(field.value.isEmpty ? "入力" : field.value)
                                    .foregroundColor(field.value.isEmpty ? .gray : .primary)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: 200, alignment: .trailing)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 24)
                            .onTapGesture {
                                editFieldIndex = index
                                editFieldName = field.name
                                editFieldValue = field.value
                                showEditFieldPopup = true
                            }
                        }
                    }
                }
                .frame(width: geometry.size.width)
            }
        }
        .navigationBarHidden(true)
        // 名前編集モーダル
        .sheet(isPresented: $showEditNameModal) {
            VStack(spacing: 20) {
                Text("タイトルとハッシュタグを編集")
                    .font(.headline)
                VStack(spacing: 12) {
                    TextField("タイトル", text: $editName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("ハッシュタグ", text: $editHashtag)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                HStack {
                    Button("キャンセル") {
                        showEditNameModal = false
                    }
                    Spacer()
                    Button("保存") {
                        guard let idx = animes.firstIndex(where: { $0.id == anime.id }) else { return }
                        var updatedAnime = animes[idx]
                        updatedAnime.title = editName
                        updatedAnime.hashtag = editHashtag
                        animes[idx] = updatedAnime
                        animeManager.updateAnime(updatedAnime)
                        showEditNameModal = false
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .padding(40)
        }
        // 公開日編集モーダル
        .sheet(isPresented: $showEditReleaseDateModal) {
            VStack(spacing: 20) {
                Text("公開日を編集")
                    .font(.headline)
                HStack(spacing: 16) {
                    Picker("月", selection: Binding(
                        get: { Calendar.current.component(.month, from: editReleaseDate) },
                        set: { newMonth in
                            let day = Calendar.current.component(.day, from: editReleaseDate)
                            let year = 2000 // 年は固定
                            let newDate = Calendar.current.date(from: DateComponents(year: year, month: newMonth, day: day)) ?? editReleaseDate
                            editReleaseDate = newDate
                        })) {
                        ForEach(1...12, id: \.self) { month in
                            Text("\(month)月").tag(month)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    Picker("日", selection: Binding(
                        get: { Calendar.current.component(.day, from: editReleaseDate) },
                        set: { newDay in
                            let month = Calendar.current.component(.month, from: editReleaseDate)
                            let year = 2000 // 年は固定
                            let newDate = Calendar.current.date(from: DateComponents(year: year, month: month, day: newDay)) ?? editReleaseDate
                            editReleaseDate = newDate
                        })) {
                        ForEach(1...31, id: \.self) { day in
                            Text("\(day)日").tag(day)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                }
                HStack {
                    Button("キャンセル") {
                        showEditReleaseDateModal = false
                    }
                    Spacer()
                    Button("保存") {
                        guard let idx = animes.firstIndex(where: { $0.id == anime.id }) else { return }
                        var updatedAnime = animes[idx]
                        updatedAnime.releaseDate = editReleaseDate
                        animes[idx] = updatedAnime
                        animeManager.updateAnime(updatedAnime)
                        showEditReleaseDateModal = false
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .padding(40)
        }
        // アイコン画像編集モーダル
        .sheet(isPresented: $showEditIconModal) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 24) {
                    Text("アイコンを編集")
                        .font(.headline)
                    if let tempIconImage = tempIconImage {
                        Image(uiImage: tempIconImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    } else if let imageIdentifier = anime.imageIdentifier, let image = UIImage(contentsOfFile: imageIdentifier) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 120)
                            .shadow(radius: 8)
                            .overlay(
                                Image(systemName: "film")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                            )
                    }
                    PhotosPicker(selection: $iconPickerItem, matching: .images) {
                        Text("画像を選択")
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: iconPickerItem) { oldValue, newValue in
                    if let newItem = newValue {
                        Task {
                            if let data = try? await newItem.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                                tempIconImage = uiImage
                                
                                let fileName = "anime_icon_\(UUID().uuidString).png"
                                if let imagePath = saveImageToDocuments(uiImage, fileName: fileName) {
                                    guard let idx = animes.firstIndex(where: { $0.id == anime.id }) else { return }
                                    var updatedAnime = animes[idx]
                                    updatedAnime.imageIdentifier = imagePath
                                    animes[idx] = updatedAnime
                                    animeManager.updateAnime(updatedAnime)
                                    animeManager.refreshUI()
                                }
                            }
                        }
                    }
                }
                Button(action: { 
                    showEditIconModal = false
                    tempIconImage = nil
                }) {
                    Text("閉じる")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.blue)
                        .padding(.trailing, 16)
                        .padding(.top, 16)
                }
            }
            .ignoresSafeArea(.container, edges: .top)
        }
        // カスタムフィールド追加モーダル
        .sheet(isPresented: $showAddFieldPopup) {
            VStack(spacing: 20) {
                Text("新しい項目を追加")
                    .font(.headline)
                TextField("項目名", text: $newFieldName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("詳細", text: $newFieldValue)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                HStack {
                    Button("キャンセル") {
                        showAddFieldPopup = false
                        newFieldName = ""
                        newFieldValue = ""
                    }
                    Spacer()
                    Button("追加") {
                        guard let idx = animes.firstIndex(where: { $0.id == anime.id }) else { return }
                        var updatedAnime = animes[idx]
                        if updatedAnime.customFields == nil { updatedAnime.customFields = [] }
                        updatedAnime.customFields?.append(AnimeCustomField(name: newFieldName, value: newFieldValue))
                        animes[idx] = updatedAnime
                        animeManager.updateAnime(updatedAnime)
                        showAddFieldPopup = false
                        newFieldName = ""
                        newFieldValue = ""
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .padding(40)
        }
        // カスタムフィールド編集モーダル
        .sheet(isPresented: $showEditFieldPopup) {
            VStack(spacing: 20) {
                Text("項目を編集")
                    .font(.headline)
                TextField("項目名", text: $editFieldName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("詳細", text: $editFieldValue)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                HStack {
                    Button("キャンセル") {
                        showEditFieldPopup = false
                    }
                    Spacer()
                    Button("保存") {
                        guard let idx = animes.firstIndex(where: { $0.id == anime.id }) else { return }
                        var updatedAnime = animes[idx]
                        if let index = editFieldIndex, let fields = updatedAnime.customFields, index < fields.count {
                            var newFields = fields
                            newFields[index] = AnimeCustomField(name: editFieldName, value: editFieldValue)
                            updatedAnime.customFields = newFields
                        }
                        animes[idx] = updatedAnime
                        animeManager.updateAnime(updatedAnime)
                        showEditFieldPopup = false
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .padding(40)
        }
    }
}

struct AddAnimeSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var animes: [Anime]
    @EnvironmentObject private var animeManager: AnimeManager
    @State private var title = ""
    @State private var hashtag = ""
    @State private var releaseDate = Date()
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var image: UIImage? = nil
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedDay: Int = Calendar.current.component(.day, from: Date())
    var body: some View {
        NavigationView {
            Form {
                Section {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        HStack {
                            if let image = image {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "film")
                                            .font(.system(size: 28))
                                            .foregroundColor(.gray)
                                    )
                            }
                            Text("画像を選択")
                                .foregroundColor(.blue)
                        }
                    }
                    .onChange(of: selectedItem) { oldValue, newValue in
                        if let newItem = newValue {
                            Task {
                                if let data = try? await newItem.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                                    image = uiImage
                                    let fileName = "anime_icon_\(UUID().uuidString).png"
                                    if saveImageToDocuments(uiImage, fileName: fileName) != nil {
                                        // AnimeのimageIdentifierにパスを保存
                                    }
                                }
                            }
                        }
                    }
                    TextField("タイトル", text: $title)
                    TextField("ハッシュタグ", text: $hashtag)
                }
                Section {
                    HStack {
                        Text("公開日")
                        Spacer()
                        Picker(selection: $selectedMonth, label: Text("月")) {
                            ForEach(1...12, id: \.self) { month in
                                Text("\(month)月").tag(month)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        Picker(selection: $selectedDay, label: Text("日")) {
                            ForEach(1...daysInMonth(selectedMonth), id: \.self) { day in
                                Text("\(day)日").tag(day)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                Button("追加") {
                    let calendar = Calendar.current
                    let year = calendar.component(.year, from: Date())
                    let date = calendar.date(from: DateComponents(year: year, month: selectedMonth, day: selectedDay)) ?? Date()
                    let newAnime = Anime(id: UUID(), imageIdentifier: nil, title: title, hashtag: hashtag, releaseDate: date)
                    animes.append(newAnime)
                    animeManager.addAnime(newAnime)
                    dismiss()
                }
            }
        }
    }
}

// AnimeDetailViewの定義を追加
struct AnimeDetailView: View {
    @Binding var anime: Anime
    @Binding var animes: [Anime]
    var onDismiss: (() -> Void)? = nil
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var animeManager: AnimeManager
    
    @State private var showArtwork = false
    @State private var showVideo = false
    @State private var showAbout = false
    // 編集用の状態変数
    @State private var showEditTitleModal = false
    @State private var showEditReleaseDateModal = false
    @State private var showEditIconModal = false
    @State private var editTitle: String = ""
    @State private var editHashtag: String = ""
    @State private var editReleaseDate: Date = Date()
    @State private var iconPickerItem: PhotosPickerItem? = nil
    @State private var iconImage: UIImage? = nil
    @State private var tempIconImage: UIImage? = nil

    var body: some View {
        GeometryReader { geometry in
            let currentAnime = animeManager.animes.first(where: { $0.id == anime.id }) ?? anime
            let titleText = currentAnime.title
            let dateText = DateFormatter.monthDayEnglish.string(from: currentAnime.releaseDate)
            ZStack(alignment: .topLeading) {
                Color(.systemBackground).ignoresSafeArea()
                Button(action: {
                    if let onDismiss = onDismiss {
                        onDismiss()
                    } else {
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.black)
                            .font(.system(size: 18, weight: .medium))
                        Text("Back")
                            .foregroundColor(.black)
                            .font(.system(size: 17, weight: .medium))
                    }
                }
                .padding(.top, 24)
                .padding(.leading, 16)
                VStack {
                    Spacer().frame(height: 180 + 50)
                    ZStack {
                        if let imageIdentifier = currentAnime.imageIdentifier, let image = UIImage(contentsOfFile: imageIdentifier) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .shadow(radius: 8)
                        } else {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 120, height: 120)
                                .shadow(radius: 8)
                                .overlay(
                                    Image(systemName: "person")
                                        .font(.system(size: 50))
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { showEditIconModal = true }
                    // タイトル
                    Text(titleText)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.top, 20)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .onTapGesture {
                            editTitle = currentAnime.title
                            editHashtag = currentAnime.hashtag
                            showEditTitleModal = true
                        }
                    
                    // 日付
                    Text(dateText.uppercased())
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .onTapGesture {
                            editReleaseDate = currentAnime.releaseDate
                            showEditReleaseDateModal = true
                        }
                    
                    // ナビゲーションバー（下部メニュー）
                    HStack {
                        Spacer()
                        Button(action: { showArtwork = true }) {
                            VStack {
                                Image(systemName: "photo.on.rectangle")
                                Text("ArtWork").font(.caption2)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        Spacer()
                        Button(action: { showVideo = true }) {
                            VStack {
                                Image(systemName: "video")
                                Text("Video").font(.caption2)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        Spacer()
                        Button(action: { showAbout = true }) {
                            VStack {
                                Image(systemName: "info.circle")
                                Text("About").font(.caption2)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        Spacer()
                        VStack {
                            Image(systemName: "link")
                            Text("Visit").font(.caption2)
                        }
                        Spacer()
                    }
                    .padding(.top, 60)
                    .fullScreenCover(isPresented: $showArtwork) {
                        AnimeArtworkScreen(anime: $anime, animes: $animes)
                    }
                    .fullScreenCover(isPresented: $showVideo) {
                        AnimeVideoScreen(anime: $anime, animes: $animes)
                    }
                    .fullScreenCover(isPresented: $showAbout) {
                        AnimeAboutView(anime: $anime, animes: $animes, onClose: { showAbout = false })
                            .environmentObject(animeManager)
                    }
                }
                .frame(width: geometry.size.width)
            }
        }
        .navigationBarHidden(true)
        // タイトル編集モーダル
        .sheet(isPresented: $showEditTitleModal) {
            VStack(spacing: 20) {
                Text("タイトルとハッシュタグを編集")
                    .font(.headline)
                VStack(spacing: 12) {
                    TextField("タイトル", text: $editTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("ハッシュタグ", text: $editHashtag)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                HStack {
                    Button("キャンセル") {
                        showEditTitleModal = false
                    }
                    Spacer()
                    Button("保存") {
                        guard let idx = animes.firstIndex(where: { $0.id == anime.id }) else { return }
                        var updatedAnime = animes[idx]
                        updatedAnime.title = editTitle
                        updatedAnime.hashtag = editHashtag
                        animes[idx] = updatedAnime
                        animeManager.updateAnime(updatedAnime)
                        showEditTitleModal = false
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .padding(40)
        }
        // 公開日編集モーダル
        .sheet(isPresented: $showEditReleaseDateModal) {
            VStack(spacing: 20) {
                Text("公開日を編集")
                    .font(.headline)
                HStack(spacing: 16) {
                    Picker("月", selection: Binding(
                        get: { Calendar.current.component(.month, from: editReleaseDate) },
                        set: { newMonth in
                            let day = Calendar.current.component(.day, from: editReleaseDate)
                            let year = 2000 // 年は固定
                            let newDate = Calendar.current.date(from: DateComponents(year: year, month: newMonth, day: day)) ?? editReleaseDate
                            editReleaseDate = newDate
                        })) {
                        ForEach(1...12, id: \.self) { month in
                            Text("\(month)月").tag(month)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    Picker("日", selection: Binding(
                        get: { Calendar.current.component(.day, from: editReleaseDate) },
                        set: { newDay in
                            let month = Calendar.current.component(.month, from: editReleaseDate)
                            let year = 2000 // 年は固定
                            let newDate = Calendar.current.date(from: DateComponents(year: year, month: month, day: newDay)) ?? editReleaseDate
                            editReleaseDate = newDate
                        })) {
                        ForEach(1...31, id: \.self) { day in
                            Text("\(day)日").tag(day)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                }
                HStack {
                    Button("キャンセル") {
                        showEditReleaseDateModal = false
                    }
                    Spacer()
                    Button("保存") {
                        guard let idx = animes.firstIndex(where: { $0.id == anime.id }) else { return }
                        var updatedAnime = animes[idx]
                        updatedAnime.releaseDate = editReleaseDate
                        animes[idx] = updatedAnime
                        animeManager.updateAnime(updatedAnime)
                        showEditReleaseDateModal = false
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .padding(40)
        }
        // アイコン編集モーダル（省略）
    }
    
}
