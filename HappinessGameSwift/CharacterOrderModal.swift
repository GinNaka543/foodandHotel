import SwiftUI

struct CharacterOrderModal: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var characterManager: CharacterManager
    @State private var characters: [Character] = []
    
    var body: some View {
        NavigationView {
            VStack {
                Text("キャラクターの順番を変更")
                    .font(.title2)
                    .fontWeight(.semibold)
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
            loadCharacters()
        }
    }
    
    private func loadCharacters() {
        characters = characterManager.characters.sorted(by: { $0.order < $1.order })
    }
    
    private func moveCharacter(from source: IndexSet, to destination: Int) {
        characters.move(fromOffsets: source, toOffset: destination)
        
        // 順番を更新
        for (index, _) in characters.enumerated() {
            characters[index].order = index
        }
    }
    
    private func saveOrder() {
        for character in characters {
            characterManager.updateCharacter(character)
        }
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