import SwiftUI
import PhotosUI
import Foundation
import UIKit

// 必要な型定義をコピー
struct ArtworkAlbum: Identifiable, Hashable, Equatable {
    let id = UUID()
    let tag: String
    var videos: [Artwork]
    let characterImageName: String

    var count: Int { videos.count }
    var firstImagePath: String? { videos.first?.imagePath }

    static func == (lhs: ArtworkAlbum, rhs: ArtworkAlbum) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Artwork: Identifiable, Codable, Hashable {
    let id: UUID
    let characterId: UUID
    var imagePath: String?
    var title: String
    var tags: [String]
    var createdAt: Date
    var pixivURL: String?
    var twitterURL: String?

    init(id: UUID = UUID(), characterId: UUID, imagePath: String? = nil, title: String, tags: [String] = [], createdAt: Date = Date(), pixivURL: String? = nil, twitterURL: String? = nil) {
        self.id = id
        self.characterId = characterId
        self.imagePath = imagePath
        self.title = title
        self.tags = tags
        self.createdAt = createdAt
        self.pixivURL = pixivURL
        self.twitterURL = twitterURL
    }

    static func == (lhs: Artwork, rhs: Artwork) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}


// CharacterArtworkScreen - AnimeArtworkScreenと同じ構造
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
    @State private var albums: [ArtworkAlbum] = []
    @State private var selectedAlbum: ArtworkAlbum? = nil
    
    // Enum to manage sheet presentations
    enum SheetType: Identifiable {
        case addPhoto
        case tagInput
        case artworkDetail(Artwork)
        
        var id: String {
            switch self {
            case .addPhoto: return "addPhoto"
            case .tagInput: return "tagInput"
            case .artworkDetail(let artwork): return "artworkDetail_\(artwork.id)"
            }
        }
    }
    @State private var activeSheet: SheetType? = nil
    
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
                    // キャラクター名
                    HStack {
                        Spacer().frame(width: 0)
                        Text(character.name)
                            .font(.system(size: 25, weight: .bold))
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                            .offset(x: -15)
                        Spacer()
                    }
                    // Uploadボタン（右端に揃える）
                    Button(action: { activeSheet = .addPhoto }) {
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
                    .padding(.trailing, 50)
                    
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
                    Spacer(minLength: 70)
                }
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                // コンテンツ
                if showAlbum {
                    // アルバムビュー
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(albums, id: \.self) { album in
                                Button(action: {
                                    selectedAlbum = album
                                }) {
                                    VStack(spacing: 8) {
                                        if let firstImagePath = album.firstImagePath,
                                           let image = UIImage(contentsOfFile: firstImagePath) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 160, height: 160)
                                                .clipped()
                                                .cornerRadius(12)
                                        } else {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(width: 160, height: 160)
                                                .overlay(
                                                    Image(systemName: "photo")
                                                        .font(.system(size: 40))
                                                        .foregroundColor(.gray)
                                                )
                                        }
                                        
                                        Text(album.tag)
                                            .font(.caption)
                                            .foregroundColor(.black)
                                        
                                        Text("\(album.count)枚")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                } else {
                    // アートワークビュー
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(artworks) { artwork in
                                Button(action: {
                                    selectedArtwork = artwork
                                    activeSheet = .artworkDetail(artwork)
                                }) {
                                    if let imagePath = artwork.imagePath,
                                       let image = UIImage(contentsOfFile: imagePath) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 120)
                                            .clipped()
                                    } else {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 120)
                                            .overlay(
                                                Image(systemName: "photo")
                                                    .foregroundColor(.gray)
                                            )
                                    }
                                }
                            }
                        }
                        .padding(8)
                    }
                }
            }
            
            // 新規写真追加ボタン
            if !showAlbum {
                Button(action: { activeSheet = .addPhoto }) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            loadArtworks()
            updateAlbums()
        }
        .sheet(item: $activeSheet) { sheetType in
            switch sheetType {
            case .addPhoto:
                AddPhotoSheet(
                    selectedImage: $selectedImage,
                    photoTitle: $photoTitle,
                    photoTags: $photoTags,
                    showTagInput: $showTagInput,
                    filteredTags: $filteredTags,
                    newTag: $newTag,
                    onSave: saveArtwork
                )
            case .tagInput:
                EmptyView() // Not used in this context
            case .artworkDetail(let artwork):
                if let artwork = artworks.first(where: { $0.id == artwork.id }) {
                    ArtworkDetailView(
                        artwork: artwork,
                        onDelete: { deleteArtwork(artwork) },
                        onUpdate: { updatedArtwork in
                            updateArtwork(updatedArtwork)
                        }
                    )
                }
            }
        }
        .fullScreenCover(item: $selectedAlbum) { album in
            AlbumArtworkListScreen(
                artworks: album.videos,
                tag: album.tag,
                onArtworkDeleted: { deletedArtwork in
                    deleteArtwork(deletedArtwork)
                },
                onArtworkEdited: { editedArtwork in
                    updateArtwork(editedArtwork)
                }
            )
        }
    }
    
    // 以下、必要な関数を追加
    func loadArtworks() {
        let key = "character_artworks_\(character.id.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Artwork].self, from: data) {
            artworks = decoded
        }
    }
    
    func saveArtworks() {
        let key = "character_artworks_\(character.id.uuidString)"
        if let data = try? JSONEncoder().encode(artworks) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    func saveArtwork() {
        guard let selectedImage = selectedImage else { return }
        
        let fileName = "\(UUID().uuidString).jpg"
        guard let imagePath = saveImageToDocuments(selectedImage, fileName: fileName) else { return }
        
        let tags = photoTags
            .split(separator: " ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let artwork = Artwork(
            characterId: character.id,
            imagePath: imagePath,
            title: photoTitle.isEmpty ? "Untitled" : photoTitle,
            tags: tags
        )
        
        artworks.append(artwork)
        saveArtworks()
        updateAlbums()
        
        // Reset
        self.selectedImage = nil
        self.photoTitle = ""
        self.photoTags = ""
    }
    
    func deleteArtwork(_ artwork: Artwork) {
        artworks.removeAll { $0.id == artwork.id }
        saveArtworks()
        updateAlbums()
        
        // Delete image file
        if let imagePath = artwork.imagePath {
            try? FileManager.default.removeItem(atPath: imagePath)
        }
    }
    
    func updateArtwork(_ updatedArtwork: Artwork) {
        if let index = artworks.firstIndex(where: { $0.id == updatedArtwork.id }) {
            artworks[index] = updatedArtwork
            saveArtworks()
            updateAlbums()
        }
    }
    
    func updateAlbums() {
        let groupedByTag = Dictionary(grouping: artworks) { artwork -> String in
            artwork.tags.first ?? "Untagged"
        }
        
        albums = groupedByTag.map { tag, artworks in
            ArtworkAlbum(tag: tag, videos: artworks, characterImageName: character.name)
        }.sorted { $0.tag < $1.tag }
    }
}

// 必要な関数定義
func saveImageToDocuments(_ image: UIImage, fileName: String) -> String? {
    guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let fileURL = documentsDirectory.appendingPathComponent(fileName)
    
    do {
        try data.write(to: fileURL)
        return fileURL.path
    } catch {
        print("Error saving image: \(error)")
        return nil
    }
}

// AddPhotoSheet
struct AddPhotoSheet: View {
    @Binding var selectedImage: UIImage?
    @Binding var photoTitle: String
    @Binding var photoTags: String
    @Binding var showTagInput: Bool
    @Binding var filteredTags: [String]
    @Binding var newTag: String
    let onSave: () -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var imagePickerPresented = false
    
    var body: some View {
        NavigationView {
            VStack {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .padding()
                } else {
                    Button(action: { imagePickerPresented = true }) {
                        VStack {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("写真を選択")
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding()
                }
                
                Form {
                    Section(header: Text("タイトル")) {
                        TextField("タイトルを入力", text: $photoTitle)
                    }
                    
                    Section(header: Text("タグ")) {
                        TextField("タグをスペース区切りで入力", text: $photoTags)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("写真を追加")
            .navigationBarItems(
                leading: Button("キャンセル") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("保存") {
                    onSave()
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(selectedImage == nil)
            )
        }
        .sheet(isPresented: $imagePickerPresented) {
            ImagePicker(selectedImage: $selectedImage)
        }
    }
}

// ImagePicker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// ArtworkDetailView
struct ArtworkDetailView: View {
    let artwork: Artwork
    let onDelete: () -> Void
    let onUpdate: (Artwork) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var showDeleteAlert = false
    @State private var showEditTitle = false
    @State private var showEditTags = false
    @State private var editedTitle = ""
    @State private var editedTags = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if let imagePath = artwork.imagePath,
                   let image = UIImage(contentsOfFile: imagePath) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 400)
                }
                
                List {
                    Section {
                        HStack {
                            Text("タイトル")
                            Spacer()
                            Text(artwork.title)
                                .foregroundColor(.gray)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editedTitle = artwork.title
                            showEditTitle = true
                        }
                        
                        HStack {
                            Text("タグ")
                            Spacer()
                            Text(artwork.tags.joined(separator: " "))
                                .foregroundColor(.gray)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editedTags = artwork.tags.joined(separator: " ")
                            showEditTags = true
                        }
                    }
                    
                    Section {
                        Button(action: {
                            showDeleteAlert = true
                        }) {
                            Text("削除")
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle("アートワーク詳細")
            .navigationBarItems(trailing: Button("完了") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showDeleteAlert) {
                Alert(
                    title: Text("削除確認"),
                    message: Text("このアートワークを削除しますか？"),
                    primaryButton: .destructive(Text("削除")) {
                        onDelete()
                        presentationMode.wrappedValue.dismiss()
                    },
                    secondaryButton: .cancel(Text("キャンセル"))
                )
            }
            .sheet(isPresented: $showEditTitle) {
                EditTextView(
                    title: "タイトルを編集",
                    text: $editedTitle,
                    onSave: {
                        var updatedArtwork = artwork
                        updatedArtwork.title = editedTitle
                        onUpdate(updatedArtwork)
                    }
                )
            }
            .sheet(isPresented: $showEditTags) {
                EditTextView(
                    title: "タグを編集",
                    text: $editedTags,
                    onSave: {
                        var updatedArtwork = artwork
                        updatedArtwork.tags = editedTags
                            .split(separator: " ")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        onUpdate(updatedArtwork)
                    }
                )
            }
        }
    }
}

// EditTextView
struct EditTextView: View {
    let title: String
    @Binding var text: String
    let onSave: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                TextField(title, text: $text)
            }
            .navigationTitle(title)
            .navigationBarItems(
                leading: Button("キャンセル") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("保存") {
                    onSave()
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}