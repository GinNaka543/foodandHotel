import SwiftUI

struct AlbumArtworkListScreen: View {
    let artworks: [Artwork]
    let tag: String
    @State private var selectedArtwork: Artwork? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("#" + tag)
                    .font(.system(size: 22, weight: .bold))
                    .padding(.leading, 16)
                Spacer()
            }
            .padding(.top, 24)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(artworks.enumerated()), id: \ .element.id) { idx, artwork in
                        if idx > 0 {
                            Spacer().frame(height: 35)
                        }
                        Button(action: {
                            selectedArtwork = artwork
                        }) {
                            HStack(alignment: .top, spacing: 16) {
                                if let imagePath = artwork.imagePath, let uiImage = UIImage(contentsOfFile: imagePath) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 183, height: 109)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .clipped()
                                } else {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 183, height: 109)
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
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedArtwork) { artwork in
            ArtworkPlayerScreen(artwork: artwork)
        }
    }
} 