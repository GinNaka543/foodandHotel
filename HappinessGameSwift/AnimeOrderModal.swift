import SwiftUI

struct AnimeOrderModal: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var animeManager: AnimeManager
    @State private var animes: [Anime] = []
    @State private var selectedTab: AnimeTab = .all
    
    // Available tabs for reordering - Use AnimeTab from AnimeScreen
    private let availableTabs: [AnimeTab] = AnimeTab.allCases
    
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
                
                // Tab Selection
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(availableTabs, id: \.self) { tab in
                            Button(action: {
                                selectedTab = tab
                                loadAnimesForTab(tab)
                            }) {
                                Text(localizedTabName(for: tab))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(selectedTab == tab ? .white : .primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(selectedTab == tab ? Color.blue : Color(.systemGray6))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 8)
                
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
            loadAnimesForTab(selectedTab)
        }
    }
    
    // Helper function from AnimeScreen
    private func localizedTabName(for tab: AnimeTab) -> String {
        switch tab {
        case .all:
            return NSLocalizedString("all", comment: "")
        case .watching:
            return NSLocalizedString("watching_status", comment: "")
        case .thisTerm:
            return NSLocalizedString("this_term_status", comment: "")
        case .willWatch:
            return NSLocalizedString("will_watch_status", comment: "")
        case .watchAgain:
            return NSLocalizedString("watch_again_status", comment: "")
        case .romcom:
            return NSLocalizedString("romcom", comment: "")
        case .isekai:
            return NSLocalizedString("isekai", comment: "")
        case .sf:
            return NSLocalizedString("sf", comment: "")
        case .sports:
            return NSLocalizedString("sports", comment: "")
        case .healing:
            return NSLocalizedString("healing", comment: "")
        }
    }
    
    private func loadAnimes() {
        loadAnimesForTab(selectedTab)
    }
    
    private func loadAnimesForTab(_ tab: AnimeTab) {
        // Use the filtering logic from AnimeScreen
        let animesWithTitles = animeManager.animes.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        let result: [Anime]
        switch tab {
        case .all:
            result = animesWithTitles
        case .watching:
            result = animesWithTitles.filter { $0.watchStatuses.contains(.watching) }
        case .willWatch:
            result = animesWithTitles.filter { $0.watchStatuses.contains(.willWatch) }
        case .watchAgain:
            result = animesWithTitles.filter { $0.watchStatuses.contains(.watchAgain) }
        case .thisTerm:
            result = animesWithTitles.filter { $0.watchStatuses.contains(.thisTerm) }
        // Genre filters
        case .romcom:
            result = animesWithTitles.filter { $0.genres.contains(.romcom) }
        case .isekai:
            result = animesWithTitles.filter { $0.genres.contains(.isekai) }
        case .sf:
            result = animesWithTitles.filter { $0.genres.contains(.sf) }
        case .sports:
            result = animesWithTitles.filter { $0.genres.contains(.sports) }
        case .healing:
            result = animesWithTitles.filter { $0.genres.contains(.healing) }
        }
        
        animes = result.sorted(by: { $0.order < $1.order })
    }
    
    private func moveAnime(from source: IndexSet, to destination: Int) {
        animes.move(fromOffsets: source, toOffset: destination)
        
        // Update order
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