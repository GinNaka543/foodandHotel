import SwiftUI
import PhotosUI
import Foundation
import UIKit

// 一時的な定義（ファイルがプロジェクトに追加されるまで）
struct AlbumArtworkListScreen: View {
    let artworks: [Artwork]
    let tag: String
    let onArtworkDeleted: ((Artwork) -> Void)?
    let onArtworkEdited: ((Artwork) -> Void)?
    
    init(artworks: [Artwork], tag: String, onArtworkDeleted: ((Artwork) -> Void)? = nil, onArtworkEdited: ((Artwork) -> Void)? = nil) {
        self.artworks = artworks
        self.tag = tag
        self.onArtworkDeleted = onArtworkDeleted
        self.onArtworkEdited = onArtworkEdited
    }
    
    var body: some View {
        VStack {
            Text("AlbumArtworkListScreen")
                .font(.title)
            Text("ファイルをXcodeプロジェクトに追加してください")
                .foregroundColor(.gray)
                .padding()
        }
    }
}

struct ArtworkPlayerScreen: View {
    let artwork: Artwork
    let onArtworkDeleted: ((Artwork) -> Void)?
    let onArtworkEdited: ((Artwork) -> Void)?
    
    init(artwork: Artwork, onArtworkDeleted: ((Artwork) -> Void)? = nil, onArtworkEdited: ((Artwork) -> Void)? = nil) {
        self.artwork = artwork
        self.onArtworkDeleted = onArtworkDeleted
        self.onArtworkEdited = onArtworkEdited
    }
    
    var body: some View {
        VStack {
            Text("ArtworkPlayerScreen")
                .font(.title)
            Text("ファイルをXcodeプロジェクトに追加してください")
                .foregroundColor(.gray)
                .padding()
        }
    }
}

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

// 簡単なArtworkScreen実装
struct ArtworkScreenSimple: View {
    let character: Character
    @State private var artworks: [Artwork] = []
    @State private var showAddSheet = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            // ヘッダー
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.black)
                }
                Spacer()
                Text(character.name)
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
                Button(action: { showAddSheet = true }) {
                    Text("Upload")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.black)
                        .cornerRadius(8)
                }
            }
            .padding()
            
            // アートワーク一覧
            if artworks.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "photo")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("アートワークがありません")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Text("「Upload」ボタンから追加してください")
                        .foregroundColor(.gray)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        ForEach(artworks) { artwork in
                            ArtworkCard(artwork: artwork)
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            Text("アートワーク追加画面")
                .padding()
        }
        .onAppear {
            loadArtworks()
        }
    }
    
    private func loadArtworks() {
        // UserDefaultsからアートワークを読み込み
        // 実装省略
    }
}

struct ArtworkCard: View {
    let artwork: Artwork
    
    var body: some View {
        VStack {
            if let imagePath = artwork.imagePath,
               let uiImage = UIImage(contentsOfFile: imagePath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipped()
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 120)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundColor(.gray)
                    )
            }
            
            Text(artwork.title)
                .font(.caption)
                .lineLimit(1)
        }
    }
}