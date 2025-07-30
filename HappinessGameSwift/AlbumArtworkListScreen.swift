import SwiftUI
import Foundation

struct AlbumArtworkListScreen: View {
    @State var artworks: [Artwork]
    let tag: String
    let character: Character?
    let anime: Anime?
    let onArtworkDeleted: ((Artwork) -> Void)?
    let onArtworkEdited: ((Artwork) -> Void)?
    let onAlbumDeleted: (() -> Void)?
    @State private var selectedArtwork: Artwork? = nil
    @State private var showDeleteAlbumAlert = false
    @Environment(\.presentationMode) var presentationMode
    
    // Increment view count for an artwork
    private func incrementViewCount(for artwork: Artwork) {
        if let index = artworks.firstIndex(where: { $0.id == artwork.id }) {
            artworks[index].viewCount = (artworks[index].viewCount ?? 0) + 1
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
                Button(action: {
                    showDeleteAlbumAlert = true
                }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.blue)
                }
                .padding(.trailing, 16)
            }
            .padding(.top, 24)
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 10)
                    ForEach(Array(artworks.enumerated()), id: \.element.id) { idx, artwork in
                        if idx > 0 {
                            Spacer().frame(height: 15.9)
                        }
                        Button(action: {
                            selectedArtwork = artwork
                            incrementViewCount(for: artwork)
                        }) {
                            HStack(alignment: .top, spacing: 8) {
                                // サムネイル
                                if let imagePath = artwork.imagePath, let uiImage = loadImageFromPath(imagePath) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 165, height: 90)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .clipped()
                                } else if let pixivURL = artwork.pixivURL {
                                    if let customThumbnailData = artwork.customThumbnailData,
                                       let uiImage = UIImage(data: customThumbnailData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 165, height: 90)
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                            .clipped()
                                    } else {
                                        PixivThumbnailView(pixivURL: pixivURL)
                                            .frame(width: 165, height: 90)
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                            .clipped()
                                    }
                                } else {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 165, height: 90)
                                }
                                
                                // タイトルとタグ
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(artwork.title)
                                        .font(.system(size: 16.5, weight: .semibold))
                                        .foregroundColor(.black)
                                        .padding(.vertical, 4)
                                    
                                    // ハッシュタグ
                                    if let firstTag = artwork.tags.first {
                                        Text("#\(firstTag)")
                                            .font(.system(size: 12, weight: .regular))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Text("\(formatViewCount(artwork.viewCount ?? 0))回・\(timeAgo(from: artwork.createdAt))")
                                        .font(.system(size: 13.8, weight: .regular))
                                        .foregroundColor(.gray)
                                        .padding(.vertical, 1)
                                }
                                .frame(alignment: .leading)
                                .padding(.top, 3)
                                .padding(.leading, 8)
                                
                                Spacer()
                            }
                            .padding(.leading, 8)
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
                character: character,
                anime: anime,
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
        .alert(isPresented: $showDeleteAlbumAlert) {
            Alert(
                title: Text(NSLocalizedString("delete_album_confirm_title", comment: "Delete album?")),
                message: Text(NSLocalizedString("delete_album_confirm_message", comment: "Delete permanently")),
                primaryButton: .destructive(Text(NSLocalizedString("delete", comment: "Delete"))) {
                    onAlbumDeleted?()
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel(Text(NSLocalizedString("cancel", comment: "Cancel")))
            )
        }
    }
} 
