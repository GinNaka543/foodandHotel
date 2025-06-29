import SwiftUI
import PhotosUI

struct Artwork: Identifiable, Codable {
    let id: UUID
    let characterId: UUID
    let imageData: Data
    let title: String
    let tags: [String]
    let date: Date
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
                            AlbumGridView(artworks: artworks, highlightFirstRow: false, filteredTags: filteredTags.isEmpty ? nil : filteredTags, onPhotoTap: { artwork in
                                print("タップされたartwork: \(artwork.id), タイトル: \(artwork.title)")
                                selectedArtwork = artwork
                            })
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: 32) {
                                ForEach(artworks) { artwork in
                                    VStack(alignment: .leading, spacing: 8) {
                                        if let uiImage = UIImage(data: artwork.imageData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(maxWidth: .infinity, minHeight: 300, maxHeight: 400)
                                                .clipped()
                                                .cornerRadius(24)
                                                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color(.systemGray5), lineWidth: 4))
                                                .padding(.horizontal, 16)
                                        }
                                        HStack(alignment: .center, spacing: 12) {
                                            if let icon = character.image {
                                                Image(uiImage: icon)
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
                                                if !artwork.tags.isEmpty {
                                                    Text("#" + artwork.tags.joined(separator: " #"))
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 24)
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
                    if let uiImage = UIImage(data: artwork.imageData) {
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
                    .padding(.trailing, 79)
                    Button(action: {
                        deletingArtworkID = selectedArtwork?.id
                        showDeleteAlert = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                .padding([.bottom, .trailing], 24)
            }
        }
        // タイトル編集Alert
        .alert("タイトル名を編集", isPresented: $showEditTitle, actions: {
            TextField("タイトル", text: $editText)
            Button("保存") {
                if let idx = artworks.firstIndex(where: { $0.id == selectedArtwork?.id }) {
                    artworks[idx] = Artwork(id: artworks[idx].id, characterId: artworks[idx].characterId, imageData: artworks[idx].imageData, title: editText, tags: artworks[idx].tags, date: artworks[idx].date)
                    saveArtworksToUserDefaults()
                }
                showEditTitle = false
            }
            Button("キャンセル", role: .cancel) { showEditTitle = false }
        }, message: { Text("") })
        // タグ編集Alert
        .alert("タグを編集（カンマ区切り）", isPresented: $showEditTags, actions: {
            TextField("タグ", text: $editText)
            Button("保存") {
                let tags = editText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                if let idx = artworks.firstIndex(where: { $0.id == selectedArtwork?.id }) {
                    artworks[idx] = Artwork(id: artworks[idx].id, characterId: artworks[idx].characterId, imageData: artworks[idx].imageData, title: artworks[idx].title, tags: tags, date: artworks[idx].date)
                    saveArtworksToUserDefaults()
                }
                showEditTags = false
            }
            Button("キャンセル", role: .cancel) { showEditTags = false }
        }, message: { Text("") })
        // 削除確認Alert
        .alert("本当に削除しますか？", isPresented: $showDeleteAlert, actions: {
            Button("削除", role: .destructive) {
                print("削除ボタンが押されました")
                print("deletingArtworkID: \(deletingArtworkID?.uuidString ?? "nil")")
                print("現在のartworks数: \(artworks.count)")
                print("artworks内のID一覧:")
                for (i, art) in artworks.enumerated() {
                    print("[\(i)] \(art.id.uuidString)")
                }
                if let delID = deletingArtworkID,
                   let idx = artworks.firstIndex(where: { $0.id == delID }) {
                    print("削除対象のインデックス: \(idx)")
                    artworks.remove(at: idx)
                    print("削除後のartworks数: \(artworks.count)")
                    saveArtworksToUserDefaults()
                    print("UserDefaultsに保存完了")
                } else {
                    print("削除対象が見つかりませんでした")
                }
                selectedArtwork = nil
                deletingArtworkID = nil
                showDeleteAlert = false
                print("モーダルを閉じました")
            }
            Button("キャンセル", role: .cancel) {
                showDeleteAlert = false
                deletingArtworkID = nil
                print("削除をキャンセルしました")
            }
        }, message: { Text("この写真を削除しますか？") })
    }
    
    private func saveArtwork() {
        guard let image = selectedImage, let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        let tags = photoTags.isEmpty ? [] : photoTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let newArtwork = Artwork(id: UUID(), characterId: character.id, imageData: imageData, title: photoTitle, tags: tags, date: Date())
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
    var onPhotoTap: ((Artwork) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            // 1行目: 全画像
            if !artworks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 24) {
                            ForEach(artworks) { artwork in
                                if let uiImage = UIImage(data: artwork.imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 208, height: 156)
                                        .clipped()
                                        .cornerRadius(20)
                                        .onTapGesture {
                                            onPhotoTap?(artwork)
                                        }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
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
                                    ForEach(tagArts) { artwork in
                                        if let uiImage = UIImage(data: artwork.imageData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 160, height: 120)
                                                .clipped()
                                                .cornerRadius(20)
                                                .onTapGesture {
                                                    onPhotoTap?(artwork)
                                                }
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