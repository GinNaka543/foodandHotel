import SwiftUI

struct ArtworkPlayerScreen: View {
    let artwork: Artwork
    var onDelete: (() -> Void)? = nil
    var onEdit: ((String, [String]) -> Void)? = nil
    @Environment(\.presentationMode) var presentationMode
    @State private var showMenuSheet = false
    @State private var editTitle: String = ""
    @State private var editTags: String = ""
    @State private var showDeleteAlert = false
    @State private var showFullscreen = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        if let imagePath = artwork.imagePath, let uiImage = UIImage(contentsOfFile: imagePath) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geometry.size.width, height: geometry.size.width * 9.0 / 16.0)
                                .clipped()
                                .background(Color.black)
                                .padding(.top, -10)
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
                                    .background(Color.blue)
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
                    }
                    Spacer()
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
                    FullScreenArtworkView(imagePath: artwork.imagePath, onDismiss: { showFullscreen = false })
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            editTitle = artwork.title
            editTags = artwork.tags.joined(separator: ",")
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
    var onDismiss: () -> Void
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let imagePath = imagePath, let uiImage = UIImage(contentsOfFile: imagePath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Color.gray
            }
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
    }
} 