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
        print("CharacterOrderModal: キャラクターを読み込み中...")
        print("CharacterOrderModal: characterManager.characters.count = \(characterManager.characters.count)")
        characters = characterManager.characters.sorted(by: { $0.order < $1.order })
        print("CharacterOrderModal: 読み込み完了. characters.count = \(characters.count)")
    }
    
    private func moveCharacter(from source: IndexSet, to destination: Int) {
        characters.move(fromOffsets: source, toOffset: destination)
        
        // 順番を更新
        for index in 0..<characters.count {
            characters[index].order = index
        }
    }
    
    private func saveOrder() {
        print("CharacterOrderModal: 順番を保存中...")
        for (index, var character) in characters.enumerated() {
            character.order = index
            print("CharacterOrderModal: \(character.name) の順番を \(index) に設定")
            characterManager.updateCharacter(character)
        }
        characterManager.saveCharacters()
        characterManager.refreshUI()
        print("CharacterOrderModal: 保存完了")
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