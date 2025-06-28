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
    
    var body: some View {
        ZStack(alignment: .topLeading) {
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
                    Text(character.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .shadow(radius: 2)
                        .frame(maxWidth: .infinity)
                        .offset(x: 9)
                    Spacer()
                    // 空白でUploadボタン分のスペースを確保
                    Color.clear.frame(width: 80, height: 1)
                }
                .frame(height: 56)
                .padding(.top, 8)
                .padding(.leading, 30)

                // タブバー
                HStack(spacing: 0) {
                    Spacer()
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
                    Spacer()
                    Button(action: { showAddSheet = true }) {
                        Text("Upload")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                            .background(Color.black)
                            .cornerRadius(4)
                    }
                    Spacer()
                }
                .frame(height: 40)
                .padding(.bottom, 8)
                // 画像リスト or Album
                ZStack {
                    if showAlbum {
                        ScrollView {
                            AlbumGridView(artworks: artworks)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showAddSheet) {
            AddPhotoView(selectedImage: $selectedImage, photoTitle: $photoTitle, photoTags: $photoTags) {
                if !photoTitle.trimmingCharacters(in: .whitespaces).isEmpty && !photoTags.trimmingCharacters(in: .whitespaces).isEmpty {
                    saveArtwork()
                }
            }
        }
    }
    
    private func saveArtwork() {
        guard let image = selectedImage, let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        let tags = photoTags.isEmpty ? [] : photoTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let newArtwork = Artwork(id: UUID(), characterId: character.id, imageData: imageData, title: photoTitle, tags: tags, date: Date())
        artworks.insert(newArtwork, at: 0)
        selectedImage = nil
        photoTitle = ""
        photoTags = ""
        showAddSheet = false
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
                        .shadow(radius: 6)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct AlbumGridView: View {
    let artworks: [Artwork]
    let columns: Int = 8
    var rows: Int { (artworks.count + columns - 1) / columns }
    var body: some View {
        VStack(spacing: 24) {
            ForEach(0..<rows, id: \.self) { row in
                let start = row * columns
                let end = min(start + columns, artworks.count)
                let images = artworks[start..<end].compactMap { UIImage(data: $0.imageData) }
                HStack(spacing: 24) {
                    AlbumRowView(images: images)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.top, 16)
    }
} 