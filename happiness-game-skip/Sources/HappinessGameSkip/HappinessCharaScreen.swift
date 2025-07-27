import SwiftUI
import Foundation

// Simplified character screen for Skip compatibility
struct HappinessCharaScreen: View {
    @State internal var characters: [Character] = sampleCharacters
    @State internal var showingAddCharacter = false
    @State internal var searchText = ""
    
    var filteredCharacters: [Character] {
        if searchText.isEmpty {
            return characters
        } else {
            return characters.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("キャラクターを検索", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                // Character list
                List {
                    ForEach(filteredCharacters) { character in
                        CharacterRow(character: character)
                    }
                    .onDelete(perform: deleteCharacters)
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("キャラクター")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingAddCharacter = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCharacter) {
                AddCharacterView { newCharacter in
                    characters.append(newCharacter)
                    showingAddCharacter = false
                }
            }
        }
    }
    
    func deleteCharacters(offsets: IndexSet) {
        characters.remove(atOffsets: offsets)
    }
}

struct Character: Identifiable, Codable {
    let id = UUID()
    var name: String
    var series: String
    var description: String
    var isFavorite: Bool = false
    var createdAt: Date = Date()
}

struct CharacterRow: View {
    let character: Character
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(character.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(character.series)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !character.description.isEmpty {
                    Text(character.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            if character.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddCharacterView: View {
    @State internal var name = ""
    @State internal var series = ""
    @State internal var description = ""
    @State internal var isFavorite = false
    
    let onSave: (Character) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("基本情報")) {
                    TextField("キャラクター名", text: $name)
                    TextField("作品名", text: $series)
                }
                
                Section(header: Text("詳細")) {
                    TextField("説明", text: $description)
                        .lineLimit(6)
                    
                    Toggle("お気に入り", isOn: $isFavorite)
                }
            }
            .navigationTitle("新しいキャラクター")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        // Handle cancel
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let newCharacter = Character(
                            name: name,
                            series: series,
                            description: description,
                            isFavorite: isFavorite
                        )
                        onSave(newCharacter)
                    }
                    .disabled(name.isEmpty || series.isEmpty)
                }
            }
        }
    }
}

// Sample data
let sampleCharacters: [Character] = [
    Character(name: "サクラ", series: "カードキャプターさくら", description: "魔法少女"),
    Character(name: "ナルト", series: "NARUTO", description: "忍者"),
    Character(name: "ルフィ", series: "ワンピース", description: "海賊", isFavorite: true),
    Character(name: "炭治郎", series: "鬼滅の刃", description: "鬼殺隊"),
]