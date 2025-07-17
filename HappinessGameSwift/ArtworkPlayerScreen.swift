import SwiftUI
import Foundation

struct ArtworkPlayerScreen: View {
    @State var artwork: Artwork
    var allArtworks: [Artwork] = []
    var onDelete: (() -> Void)? = nil
    var onEdit: ((String, [String]) -> Void)? = nil
    var onArtworkChange: ((Artwork) -> Void)? = nil
    @Environment(\.presentationMode) var presentationMode
    @State private var showMenuSheet = false
    @State private var editTitle: String = ""
    @State private var editTags: String = ""
    @State private var showDeleteAlert = false
    @State private var showFullscreen = false
    @State private var selectedArtwork: Artwork?
    @State private var showPixivRedirect = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        if let imagePath = artwork.imagePath, let uiImage = loadImageFromPath(imagePath) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geometry.size.width, height: geometry.size.width * 9.0 / 16.0)
                                .clipped()
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
                                        .clipped()
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
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(artwork.title)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.black)
                                    .lineLimit(2)
                                Text("#" + (artwork.tags.isEmpty ? "nakajimaginsei" : artwork.tags.joined(separator: " #")))
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            Spacer(minLength: 8)
                            Button(action: {
                                showMenuSheet = true
                            }) {
                                Text("編集")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 16)
                                    .background(Color.black)
                                    .cornerRadius(8)
                            }
                            .padding(.trailing, 4)
                            Button(action: {
                                showFullscreen = true
                            }) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right.square")
                                    .font(.system(size: 21, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Circle())
                            }
                            .padding(.trailing, 8)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        
                        // 関連画像リスト
                        if allArtworks.count > 1 {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("関連画像")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 16)
                                
                                ScrollView {
                                    LazyVStack(spacing: 12) {
                                        ForEach(allArtworks.filter { $0.id != artwork.id }, id: \.id) { relatedArtwork in
                                            Button(action: {
                                                selectedArtwork = relatedArtwork
                                            }) {
                                                HStack(spacing: 16) {
                                                    // サムネイル画像
                                                    if let imagePath = relatedArtwork.imagePath, let uiImage = loadImageFromPath(imagePath) {
                                                        Image(uiImage: uiImage)
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fill)
                                                            .frame(width: 160, height: 100)
                                                            .clipped()
                                                            .cornerRadius(8)
                                                    } else if let pixivURL = relatedArtwork.pixivURL {
                                                        if let customThumbnailData = relatedArtwork.customThumbnailData,
                                                           let uiImage = UIImage(data: customThumbnailData) {
                                                            Image(uiImage: uiImage)
                                                                .resizable()
                                                                .aspectRatio(contentMode: .fill)
                                                                .frame(width: 160, height: 100)
                                                                .clipped()
                                                                .cornerRadius(8)
                                                        } else {
                                                            PixivThumbnailView(pixivURL: pixivURL)
                                                                .frame(width: 160, height: 100)
                                                                .clipped()
                                                                .cornerRadius(8)
                                                        }
                                                    } else {
                                                        Rectangle()
                                                            .fill(Color.gray.opacity(0.3))
                                                            .frame(width: 160, height: 100)
                                                            .cornerRadius(8)
                                                    }
                                                    
                                                    // タイトルとタグ
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(relatedArtwork.title)
                                                            .font(.system(size: 16, weight: .semibold))
                                                            .foregroundColor(.black)
                                                            .lineLimit(2)
                                                        Text("#" + (relatedArtwork.tags.isEmpty ? "nakajimaginsei" : relatedArtwork.tags.joined(separator: " #")))
                                                            .font(.system(size: 14))
                                                            .foregroundColor(.gray)
                                                            .lineLimit(1)
                                                    }
                                                    
                                                    Spacer()
                                                }
                                                .padding(.horizontal, 16)
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
                    FullScreenArtworkView(imagePath: artwork.imagePath, pixivURL: artwork.pixivURL, onDismiss: { showFullscreen = false })
                }
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showPixivRedirect) {
            if let pixivURL = artwork.pixivURL {
                PixivRedirectView(
                    pixivURL: pixivURL,
                    artwork: artwork,
                    onEdit: { newTitle, newTags in
                        onEdit?(newTitle, newTags)
                    },
                    onDelete: {
                        onDelete?()
                        presentationMode.wrappedValue.dismiss()
                    },
                    onThumbnailUpdate: { newThumbnailData in
                        // サムネイル更新の処理
                        artwork.customThumbnailData = newThumbnailData
                        // 親ビューにも変更を通知
                        onEdit?(artwork.title, artwork.tags)
                    }
                )
            }
        }
        .onAppear {
            editTitle = artwork.title
            editTags = artwork.tags.joined(separator: ",")
        }
        .onChange(of: selectedArtwork) { newArtwork in
            if let newArtwork = newArtwork {
                onArtworkChange?(newArtwork)
            }
        }
        .sheet(isPresented: $showMenuSheet) {
            VStack(spacing: 24) {
                Text("画像の編集")
                    .font(.headline)
                TextField("タイトル", text: $editTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("タグ（カンマ区切り）", text: $editTags)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("タイトル・タグを保存") {
                    onEdit?(editTitle, editTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) })
                    showMenuSheet = false
                }
                .font(.headline)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
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
    var onDismiss: () -> Void
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
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 100))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("Pixiv作品")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text(pixivURL)
                        .font(.headline)
                        .foregroundColor(.gray.opacity(0.7))
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .padding(.horizontal)
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