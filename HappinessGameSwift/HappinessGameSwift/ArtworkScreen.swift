import SwiftUI
import PhotosUI
import Foundation
import UIKit

struct ArtworkAlbum: Identifiable, Hashable, Equatable {
    let id = UUID()
    let tag: String
    var videos: [Artwork]
    
    init(tag: String, videos: [Artwork]) {
        self.tag = tag
        self.videos = videos
    }
    
    static func == (lhs: ArtworkAlbum, rhs: ArtworkAlbum) -> Bool {
        lhs.id == rhs.id && lhs.tag == rhs.tag && lhs.videos == rhs.videos
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(tag)
        hasher.combine(videos)
    }
}

struct Artwork: Identifiable, Codable, Hashable {
    let id: UUID
    let characterId: UUID
    var imagePath: String?
    var title: String
    var tags: [String]
    let date: Date
    
    enum CodingKeys: String, CodingKey {
        case id, characterId, imagePath, title, tags, date
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(characterId, forKey: .characterId)
        try container.encodeIfPresent(imagePath, forKey: .imagePath)
        try container.encode(title, forKey: .title)
        try container.encode(tags, forKey: .tags)
        try container.encode(date, forKey: .date)
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        characterId = try container.decode(UUID.self, forKey: .characterId)
        imagePath = try? container.decodeIfPresent(String.self, forKey: .imagePath)
        title = try container.decode(String.self, forKey: .title)
        tags = try container.decode([String].self, forKey: .tags)
        date = try container.decode(Date.self, forKey: .date)
    }
    init(id: UUID, characterId: UUID, imagePath: String?, title: String, tags: [String], date: Date) {
        self.id = id
        self.characterId = characterId
        self.imagePath = imagePath
        self.title = title
        self.tags = tags
        self.date = date
    }
}

struct ArtworkScreen: View {
    let character: Character
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
    @State private var selectedArtworkForPlayer: Artwork? = nil
    @State private var albums: [ArtworkAlbum] = []
    @State private var selectedAlbum: ArtworkAlbum? = nil
    
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
                    // キャラ名
                    HStack {
                        Spacer().frame(width: 0)
                        Text(character.name)
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
                    Spacer(minLength: 70) // 40+30=70pt 右にずらす
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
                    Spacer(minLength: 80) // 右端Uploadボタンとの間隔を広げる
                }
                .frame(height: 40)
                // 画像リスト or Album
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
                                            if let firstArtwork = album.videos.first, let imagePath = firstArtwork.imagePath, let uiImage = UIImage(contentsOfFile: imagePath) {
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
                            AlbumArtworkListScreen(artworks: album.videos, tag: album.tag)
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: 32) {
                                ForEach(artworks, id: \.id) { artwork in
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
                                                if let imageIdentifier = character.imageIdentifier, let image = UIImage(contentsOfFile: imageIdentifier) {
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
                                                            Image(systemName: "person")
                                                                .font(.system(size: 20))
                                                                .foregroundColor(.gray)
                                                        )
                                                }
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(artwork.title)
                                                        .font(.headline)
                                                        .foregroundColor(.black)
                                                    Text(artwork.tags.isEmpty ? "#nakajimaginsei" : "#" + artwork.tags.joined(separator: " #"))
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                                Spacer()
                                            }
                                            .padding(.top, 8)
                                            .padding(.leading, 8)
                                        }
                                        .padding(.vertical, 8)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedArtworkForPlayer = artwork
                                        }
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                        .fullScreenCover(item: $selectedArtworkForPlayer) { artwork in
                            ArtworkPlayerScreen(artwork: artwork, onDelete: {
                                if let idx = artworks.firstIndex(where: { $0.id == artwork.id }) {
                                    artworks.remove(at: idx)
                                    saveArtworksToUserDefaults()
                                }
                            }, onEdit: { newTitle, newTags in
                                if let idx = artworks.firstIndex(where: { $0.id == artwork.id }) {
                                    artworks[idx].title = newTitle
                                    artworks[idx].tags = newTags
                                    saveArtworksToUserDefaults()
                                }
                            })
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
                                let tagArtworks = artworks.filter { $0.tags.contains(where: { $0 == tag }) }
                                if !tagArtworks.isEmpty {
                                    albums.append(ArtworkAlbum(tag: tag, videos: tagArtworks))
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
        guard let image = selectedImage else { return }
        let tags = photoTags.isEmpty ? [] : photoTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        // 画像を保存
        let fileName = "artwork_\(UUID().uuidString).png"
        let path = saveImageToDocuments(image, fileName: fileName)
        let newArtwork = Artwork(id: UUID(), characterId: character.id, imagePath: path, title: photoTitle, tags: tags, date: Date())
        artworks.insert(newArtwork, at: 0)
        saveArtworksToUserDefaults()
        selectedImage = nil
        photoTitle = ""
        photoTags = ""
        showAddSheet = false
    }
    
    private func loadArtworks() {
        let key = "artworks_\(character.id.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key),
           let decodedArtworks = try? JSONDecoder().decode([Artwork].self, from: data) {
            artworks = decodedArtworks
        }
    }
    
    private func saveArtworksToUserDefaults() {
        let key = "artworks_\(character.id.uuidString)"
        if let encodedData = try? JSONEncoder().encode(artworks) {
            UserDefaults.standard.set(encodedData, forKey: key)
        }
    }
    

}

struct AlbumRowView: View {
    let images: [UIImage]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                ForEach(0..<images.count, id: \.self) { i in
                    Image(uiImage: images[i])
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 160, height: 120)
                        .clipped()
                        .cornerRadius(20)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct AlbumGridView: View {
    let artworks: [Artwork]
    let highlightFirstRow: Bool
    let filteredTags: [String]?
    @Binding var selectedArtwork: Artwork?

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            // 1行目: 全画像
            if !artworks.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(artworks, id: \.id) { artwork in
                        Button(action: {
                            if selectedArtwork?.id != artwork.id {
                                selectedArtwork = artwork
                            }
                        }) {
                            HStack(alignment: .center, spacing: 16) {
                                if let imagePath = artwork.imagePath, let uiImage = UIImage(contentsOfFile: imagePath) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 183, height: 99)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .clipped()
                                        .offset(x: 10)
                                } else {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 183, height: 99)
                                        .offset(x: 10)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(artwork.title)
                                        .font(.system(size: 15.5, weight: .semibold))
                                        .foregroundColor(.black)
                                        .frame(height: 20)
                                    Text("#" + (artwork.tags.first ?? ""))
                                        .font(.system(size: 12.8, weight: .regular))
                                        .foregroundColor(.gray)
                                        .frame(height: 20)
                                }
                                .offset(x: 10, y: -15)
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.top, 24)
            }
            // 2行目以降: タグごとのグループ
            if let tags = filteredTags {
                ForEach(tags, id: \.self) { tag in
                    let tagArts = artworks.filter { $0.tags.contains(tag) }
                    if !tagArts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("#" + tag)
                                .font(.headline)
                                .padding(.leading, 16)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 24) {
                                    ForEach(tagArts, id: \.id) { artwork in
                                        if let imagePath = artwork.imagePath, let uiImage = UIImage(contentsOfFile: imagePath) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 160, height: 120)
                                                .clipped()
                                                .cornerRadius(20)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
            }
        }
    }
} 