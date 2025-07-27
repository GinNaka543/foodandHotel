import SwiftUI

struct CharacterOrderModal: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var characterManager: CharacterManager
    @State private var characters: [Character] = []
    
    var body: some View {
        NavigationView {
            VStack {
                VStack(spacing: 8) {
                    Text(NSLocalizedString("character_order_title", comment: "Character order title"))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(NSLocalizedString("drag_drop_to_reorder", comment: "Drag and drop instruction"))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
                
                List {
                    ForEach(characters, id: \.id) { character in
                        HStack {
                            if let imageIdentifier = character.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                            }
                            
                            VStack(alignment: .leading) {
                                Text(character.name)
                                    .font(.headline)
                                Text(character.tag)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove(perform: moveCharacter)
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
            loadCharacters()
        }
    }
    
    private func loadCharacters() {
        // 名前のないキャラクターを除外してソート
        characters = characterManager.characters
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted(by: { $0.order < $1.order })
    }
    
    private func moveCharacter(from source: IndexSet, to destination: Int) {
        characters.move(fromOffsets: source, toOffset: destination)
        
        // 順番を更新
        for index in 0..<characters.count {
            characters[index].order = index
        }
    }
    
    private func saveOrder() {
        for (index, var character) in characters.enumerated() {
            character.order = index
            characterManager.updateCharacter(character)
        }
        characterManager.saveCharacters()
        characterManager.refreshUI()
    }
    
    private func loadImageFromPath(_ imagePath: String) -> UIImage? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imageURL = documentsPath.appendingPathComponent(imagePath)
        return UIImage(contentsOfFile: imageURL.path)
    }
}

#Preview {
    CharacterOrderModal()
}