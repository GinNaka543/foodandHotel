import SwiftUI
import Foundation

struct AlbumArtworkListScreen: View {
    @State var artworks: [Artwork]
    let tag: String
    let onArtworkDeleted: ((Artwork) -> Void)?
    let onArtworkEdited: ((Artwork) -> Void)?
    @State private var selectedArtwork: Artwork? = nil
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // アルバムバナー
            if let firstArtwork = artworks.first {
                ZStack(alignment: .bottomLeading) {
                    // バナー背景画像
                    Group {
                        if let imagePath = firstArtwork.imagePath, let uiImage = loadImageFromPath(imagePath) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                        } else if let pixivURL = firstArtwork.pixivURL {
                            if let customThumbnailData = firstArtwork.customThumbnailData,
                               let uiImage = UIImage(data: customThumbnailData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                PixivThumbnailView(pixivURL: pixivURL)
                            }
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                        }
                    }
                    .frame(height: 180)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black.opacity(0.6), Color.black.opacity(0)]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    
                    // アルバム情報
                    VStack(alignment: .leading, spacing: 4) {
                        Text("#" + tag)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Text("\(artworks.count)件の作品")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.black)
                        .font(.system(size: 24, weight: .bold))
                }
                .padding(.leading, 16)
                Spacer()
            }
            .padding(.top, 24)
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 10)
                    ForEach(Array(artworks.enumerated()), id: \.element.id) { idx, artwork in
                        if idx > 0 {
                            Spacer().frame(height: 35)
                        }
                        Button(action: {
                            selectedArtwork = artwork
                        }) {
                            HStack(alignment: .top, spacing: 16) {
                                if let imagePath = artwork.imagePath, let uiImage = loadImageFromPath(imagePath) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 160, height: 90)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .clipped()
                                } else if let pixivURL = artwork.pixivURL {
                                    if let customThumbnailData = artwork.customThumbnailData,
                                       let uiImage = UIImage(data: customThumbnailData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 160, height: 90)
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                            .clipped()
                                    } else {
                                        PixivThumbnailView(pixivURL: pixivURL)
                                            .frame(width: 160, height: 90)
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                            .clipped()
                                    }
                                } else {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 160, height: 90)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(artwork.title)
                                        .font(.system(size: 16.5, weight: .semibold))
                                        .foregroundColor(.black)
                                        .padding(.vertical, 8)
                                    Text(artwork.tags.isEmpty ? "#nakajimaginsei" : "#" + artwork.tags.joined(separator: " #"))
                                        .font(.system(size: 13.8, weight: .regular))
                                        .foregroundColor(.gray)
                                        .padding(.vertical, 2)
                                }
                                .frame(height: 50, alignment: .leading)
                                .padding(.top, 3)
                                .padding(.leading, 8)
                                Spacer()
                            }
                            .padding(.leading, 8)
                            .background(Color.clear)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .background(Color.white)
        .fullScreenCover(item: $selectedArtwork) { artwork in
            ArtworkPlayerScreen(
                artwork: artwork,
                allArtworks: artworks,
                onDelete: {
                    // 親画面に削除を通知
                    onArtworkDeleted?(artwork)
                    // ローカルリストからも削除
                    if let index = artworks.firstIndex(where: { $0.id == artwork.id }) {
                        artworks.remove(at: index)
                    }
                },
                onEdit: { newTitle, newTags in
                    // 編集されたartworkを作成
                    var editedArtwork = artwork
                    editedArtwork.title = newTitle
                    editedArtwork.tags = newTags
                    
                    // 親画面に編集を通知
                    onArtworkEdited?(editedArtwork)
                    
                    // ローカルリストも更新
                    if let index = artworks.firstIndex(where: { $0.id == artwork.id }) {
                        artworks[index].title = newTitle
                        artworks[index].tags = newTags
                        // 既存のcustomThumbnailDataも保持
                        artworks[index].customThumbnailData = artwork.customThumbnailData
                    }
                },
                onArtworkChange: { newArtwork in
                    selectedArtwork = newArtwork
                }
            )
        }
    }
} 
