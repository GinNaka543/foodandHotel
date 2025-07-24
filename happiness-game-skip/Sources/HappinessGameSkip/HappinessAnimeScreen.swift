import SwiftUI
import Foundation

// Simplified anime screen for Skip compatibility
struct HappinessAnimeScreen: View {
    @State internal var animes: [Anime] = sampleAnimes
    @State internal var showingAddAnime = false
    @State internal var searchText = ""
    @State internal var selectedCategory: AnimeCategory = .all
    
    var filteredAnimes: [Anime] {
        let categoryFiltered = selectedCategory == .all ? animes : animes.filter { $0.category == selectedCategory }
        
        if searchText.isEmpty {
            return categoryFiltered
        } else {
            return categoryFiltered.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Category picker
                Picker("カテゴリ", selection: $selectedCategory) {
                    ForEach(AnimeCategory.allCases, id: \.self) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("アニメを検索", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                // Anime list
                List {
                    ForEach(filteredAnimes) { anime in
                        AnimeRow(anime: anime)
                    }
                    .onDelete(perform: deleteAnimes)
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("アニメ")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingAddAnime = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddAnime) {
                AddAnimeView { newAnime in
                    animes.append(newAnime)
                    showingAddAnime = false
                }
            }
        }
    }
    
    func deleteAnimes(offsets: IndexSet) {
        animes.remove(atOffsets: offsets)
    }
}

enum AnimeCategory: String, CaseIterable, Codable {
    case all = "all"
    case action = "action"
    case romance = "romance"
    case comedy = "comedy"
    case drama = "drama"
    case fantasy = "fantasy"
    
    var displayName: String {
        switch self {
        case .all: return "全て"
        case .action: return "アクション"
        case .romance: return "恋愛"
        case .comedy: return "コメディ"
        case .drama: return "ドラマ"
        case .fantasy: return "ファンタジー"
        }
    }
}

struct Anime: Identifiable, Codable {
    let id = UUID()
    var title: String
    var category: AnimeCategory
    var rating: Int // 1-5 stars
    var notes: String
    var isWatched: Bool = false
    var createdAt: Date = Date()
}

struct AnimeRow: View {
    let anime: Anime
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(anime.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(anime.category.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Star rating
                HStack {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= anime.rating ? "star.fill" : "star")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
                
                if !anime.notes.isEmpty {
                    Text(anime.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            VStack {
                if anime.isWatched {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.gray)
                }
                
                Text(anime.isWatched ? "視聴済み" : "未視聴")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddAnimeView: View {
    @State internal var title = ""
    @State internal var category: AnimeCategory = .action
    @State internal var rating = 3
    @State internal var notes = ""
    @State internal var isWatched = false
    
    let onSave: (Anime) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("基本情報")) {
                    TextField("アニメタイトル", text: $title)
                    
                    Picker("カテゴリ", selection: $category) {
                        ForEach(AnimeCategory.allCases.filter { $0 != .all }, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                }
                
                Section(header: Text("評価")) {
                    HStack {
                        Text("評価:")
                        Spacer()
                        ForEach(1...5, id: \.self) { star in
                            Button(action: {
                                rating = star
                            }) {
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                }
                
                Section(header: Text("詳細")) {
                    TextField("メモ", text: $notes)
                        .lineLimit(6)
                    
                    Toggle("視聴済み", isOn: $isWatched)
                }
            }
            .navigationTitle("新しいアニメ")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        // Handle cancel
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let newAnime = Anime(
                            title: title,
                            category: category,
                            rating: rating,
                            notes: notes,
                            isWatched: isWatched
                        )
                        onSave(newAnime)
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// Sample data
let sampleAnimes: [Anime] = [
    Anime(title: "鬼滅の刃", category: .action, rating: 5, notes: "素晴らしいアニメーション", isWatched: true),
    Anime(title: "君の名は。", category: .romance, rating: 5, notes: "感動的な映画", isWatched: true),
    Anime(title: "ワンピース", category: .action, rating: 4, notes: "長編冒険アニメ", isWatched: false),
    Anime(title: "進撃の巨人", category: .drama, rating: 5, notes: "ダークな世界観", isWatched: true),
]