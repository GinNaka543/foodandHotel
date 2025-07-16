import SwiftUI

struct AnimeOrderModal: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var animeManager = AnimeManager()
    @State private var animes: [Anime] = []
    
    var body: some View {
        NavigationView {
            VStack {
                Text("アニメの順番を変更")
                    .font(.title2)
                    .fontWeight(.semibold)
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
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
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
        animes = animeManager.animes.sorted(by: { $0.order < $1.order })
    }
    
    private func moveAnime(from source: IndexSet, to destination: Int) {
        animes.move(fromOffsets: source, toOffset: destination)
        
        // 順番を更新
        for (index, _) in animes.enumerated() {
            animes[index].order = index
        }
    }
    
    private func saveOrder() {
        for anime in animes {
            animeManager.updateAnime(anime)
        }
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