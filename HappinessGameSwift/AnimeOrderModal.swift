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
        case .serious:
            return NSLocalizedString("serious", comment: "")
        case .romcom:
            return NSLocalizedString("romcom", comment: "")
        case .sports:
            return NSLocalizedString("sports", comment: "")
        case .comedy:
            return NSLocalizedString("comedy", comment: "")
        case .isekai:
            return NSLocalizedString("isekai", comment: "")
        case .sf:
            return NSLocalizedString("sf", comment: "")
        case .art:
            return NSLocalizedString("art", comment: "")
        case .brain:
            return NSLocalizedString("brain", comment: "")
        case .healing:
            return NSLocalizedString("healing", comment: "")
        case .action:
            return NSLocalizedString("action", comment: "")
        case .adventure:
            return NSLocalizedString("adventure", comment: "")
        case .drama:
            return NSLocalizedString("drama", comment: "")
        case .fantasy:
            return NSLocalizedString("fantasy", comment: "")
        case .horror:
            return NSLocalizedString("horror", comment: "")
        case .mystery:
            return NSLocalizedString("mystery", comment: "")
        case .psychological:
            return NSLocalizedString("psychological", comment: "")
        case .romance:
            return NSLocalizedString("romance", comment: "")
        case .slice_of_life:
            return NSLocalizedString("slice_of_life", comment: "")
        case .supernatural:
            return NSLocalizedString("supernatural", comment: "")
        case .thriller:
            return NSLocalizedString("thriller", comment: "")
        case .mecha:
            return NSLocalizedString("mecha", comment: "")
        case .music:
            return NSLocalizedString("music", comment: "")
        case .school:
            return NSLocalizedString("school", comment: "")
        case .military:
            return NSLocalizedString("military", comment: "")
        case .historical:
            return NSLocalizedString("historical", comment: "")
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
        case .serious:
            result = animesWithTitles.filter { $0.genres.contains(.serious) }
        case .romcom:
            result = animesWithTitles.filter { $0.genres.contains(.romcom) }
        case .sports:
            result = animesWithTitles.filter { $0.genres.contains(.sports) }
        case .comedy:
            result = animesWithTitles.filter { $0.genres.contains(.comedy) }
        case .isekai:
            result = animesWithTitles.filter { $0.genres.contains(.isekai) }
        case .sf:
            result = animesWithTitles.filter { $0.genres.contains(.sf) }
        case .art:
            result = animesWithTitles.filter { $0.genres.contains(.art) }
        case .brain:
            result = animesWithTitles.filter { $0.genres.contains(.brain) }
        case .healing:
            result = animesWithTitles.filter { $0.genres.contains(.healing) }
        case .action:
            result = animesWithTitles.filter { $0.genres.contains(.action) }
        case .adventure:
            result = animesWithTitles.filter { $0.genres.contains(.adventure) }
        case .drama:
            result = animesWithTitles.filter { $0.genres.contains(.drama) }
        case .fantasy:
            result = animesWithTitles.filter { $0.genres.contains(.fantasy) }
        case .horror:
            result = animesWithTitles.filter { $0.genres.contains(.horror) }
        case .mystery:
            result = animesWithTitles.filter { $0.genres.contains(.mystery) }
        case .psychological:
            result = animesWithTitles.filter { $0.genres.contains(.psychological) }
        case .romance:
            result = animesWithTitles.filter { $0.genres.contains(.romance) }
        case .slice_of_life:
            result = animesWithTitles.filter { $0.genres.contains(.slice_of_life) }
        case .supernatural:
            result = animesWithTitles.filter { $0.genres.contains(.supernatural) }
        case .thriller:
            result = animesWithTitles.filter { $0.genres.contains(.thriller) }
        case .mecha:
            result = animesWithTitles.filter { $0.genres.contains(.mecha) }
        case .music:
            result = animesWithTitles.filter { $0.genres.contains(.music) }
        case .school:
            result = animesWithTitles.filter { $0.genres.contains(.school) }
        case .military:
            result = animesWithTitles.filter { $0.genres.contains(.military) }
        case .historical:
            result = animesWithTitles.filter { $0.genres.contains(.historical) }
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