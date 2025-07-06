import SwiftUI
import PhotosUI
import Foundation
import UIKit

// 一時的なスタブ定義
struct AlbumArtworkListScreenStub: View {
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
            Text("Album Artwork List")
                .font(.title)
            Text("AlbumArtworkListScreen.swiftをプロジェクトに追加してください")
                .foregroundColor(.gray)
                .padding()
        }
    }
}

struct ArtworkPlayerScreenStub: View {
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
            Text("Artwork Player")
                .font(.title)
            Text("ArtworkPlayerScreen.swiftをプロジェクトに追加してください")
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

// 最小限のArtworkScreen実装
struct ArtworkScreenMinimal: View {
    let character: Character
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 20) {
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
                Button(action: {}) {
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
            
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "photo.artframe")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
                Text("ArtworkScreen")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("元のファイルが複雑すぎるため一時的に簡略化されました")
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                Text("完全な機能を使用するには、すべてのファイルをXcodeプロジェクトに追加してください")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            Spacer()
        }
    }
}

// 元のArtworkScreenを置き換え
typealias ArtworkScreen = ArtworkScreenMinimal