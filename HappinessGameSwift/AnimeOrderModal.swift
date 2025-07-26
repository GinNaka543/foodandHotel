import SwiftUI

struct AnimeOrderModal: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var animeManager: AnimeManager
    @State private var animes: [Anime] = []
    
    var body: some View {
        NavigationView {
            VStack {
                VStack(spacing: 8) {
                    Text(NSLocalizedString("anime_order_title", comment: "Anime order title"))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(NSLocalizedString("drag_drop_to_reorder", comment: "Drag and drop instruction"))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
                
                List {
                    ForEach(animes, id: \.id) { anime in
                        HStack {
                            if let imageIdentifier = anime.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            VStack(alignment: .leading) {
                                Text(anime.title)
                                    .font(.headline)
                                Text(anime.hashtag)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove(perform: moveAnime)
                }
                .listStyle(PlainListStyle())
                .environment(\.editMode, .constant(.active))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("cancel", comment: "Cancel button")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("save", comment: "Save button")) {
                        saveOrder()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadAnimes()
        }
    }
    
    private func loadAnimes() {
        // タイトルのないアニメを除外してソート
        animes = animeManager.animes
            .filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted(by: { $0.order < $1.order })
    }
    
    private func moveAnime(from source: IndexSet, to destination: Int) {
        animes.move(fromOffsets: source, toOffset: destination)
        
        // 順番を更新
        for index in 0..<animes.count {
            animes[index].order = index
        }
    }
    
    private func saveOrder() {
        for (index, var anime) in animes.enumerated() {
            anime.order = index
            animeManager.updateAnime(anime)
        }
        animeManager.saveAnimes()
        animeManager.refreshUI()
    }
    
    private func loadImageFromPath(_ imagePath: String) -> UIImage? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imageURL = documentsPath.appendingPathComponent(imagePath)
        return UIImage(contentsOfFile: imageURL.path)
    }
}

#Preview {
    AnimeOrderModal()
}