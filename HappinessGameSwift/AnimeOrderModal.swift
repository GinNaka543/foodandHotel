import SwiftUI

struct AnimeOrderModal: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var animeManager: AnimeManager
    @State private var animes: [Anime] = []
    
    var body: some View {
        NavigationView {
            VStack {
                VStack(spacing: 8) {
                    Text("アニメの順番を変更")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("ドラッグ&ドロップで順番を変更できます")
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
        print("AnimeOrderModal: アニメを読み込み中...")
        print("AnimeOrderModal: animeManager.animes.count = \(animeManager.animes.count)")
        // タイトルのないアニメを除外してソート
        animes = animeManager.animes
            .filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted(by: { $0.order < $1.order })
        print("AnimeOrderModal: 読み込み完了. animes.count = \(animes.count)")
    }
    
    private func moveAnime(from source: IndexSet, to destination: Int) {
        animes.move(fromOffsets: source, toOffset: destination)
        
        // 順番を更新
        for index in 0..<animes.count {
            animes[index].order = index
        }
    }
    
    private func saveOrder() {
        print("AnimeOrderModal: 順番を保存中...")
        for (index, var anime) in animes.enumerated() {
            anime.order = index
            print("AnimeOrderModal: \(anime.title) の順番を \(index) に設定")
            animeManager.updateAnime(anime)
        }
        animeManager.saveAnimes()
        animeManager.refreshUI()
        print("AnimeOrderModal: 保存完了")
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