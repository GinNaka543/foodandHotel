import Foundation
import SwiftUI

// MARK: - Character Model
struct Character: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var imageIdentifier: String?
    var tag: String
    var birthday: Date
    var favoriteFood: String
    var age: String
    var voiceActor: String
    var cupSize: String
    var seichi: String
    var height: String
    var shoeSize: String
    var clothingSize: String
    var bustSize: String
    var bankBalance: String
    var occupation: String
    var personality: String
    var hobby: String
    var bodyType: String
    var bloodType: String
    var backgroundImagePath: String?
    
    // Ranking scores
    var cuteScore: Double = 0
    var beautifulScore: Double = 0
    var coolScore: Double = 0
    var sexyScore: Double = 0
    var passionScore: Double = 0
    var smartScore: Double = 0
    var mysteriousScore: Double = 0
    var energeticScore: Double = 0
    
    init(id: UUID = UUID(), imageIdentifier: String? = nil, name: String = "", tag: String = "", 
         birthday: Date = Date(), favoriteFood: String = "", age: String = "", 
         voiceActor: String = "", cupSize: String = "", seichi: String = "", 
         height: String = "", shoeSize: String = "", clothingSize: String = "", 
         bustSize: String = "", bankBalance: String = "", occupation: String = "", 
         personality: String = "", hobby: String = "", bodyType: String = "", 
         bloodType: String = "", backgroundImagePath: String? = nil) {
        self.id = id
        self.name = name
        self.imageIdentifier = imageIdentifier
        self.tag = tag
        self.birthday = birthday
        self.favoriteFood = favoriteFood
        self.age = age
        self.voiceActor = voiceActor
        self.cupSize = cupSize
        self.seichi = seichi
        self.height = height
        self.shoeSize = shoeSize
        self.clothingSize = clothingSize
        self.bustSize = bustSize
        self.bankBalance = bankBalance
        self.occupation = occupation
        self.personality = personality
        self.hobby = hobby
        self.bodyType = bodyType
        self.bloodType = bloodType
        self.backgroundImagePath = backgroundImagePath
    }
}

// MARK: - Character Manager
class CharacterManager: ObservableObject {
    @Published var characters: [Character] = []
    private let userDefaultsKey = "characters"  // Firebase と同じキーに統一
    
    init() {
        loadCharacters()
        // データ同期通知を監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onUserDataSynced),
            name: Notification.Name("UserDataSynced"),
            object: nil
        )
    }
    
    @objc private func onUserDataSynced() {
        print("📱 [CharacterManager] User data synced notification received")
        loadCharacters()
    }
    
    func loadCharacters() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decodedCharacters = try? JSONDecoder().decode([Character].self, from: data) {
            self.characters = decodedCharacters
        }
    }
    
    func saveCharacters() {
        if let encodedData = try? JSONEncoder().encode(characters) {
            UserDefaults.standard.set(encodedData, forKey: userDefaultsKey)
        }
    }
    
    func addCharacter(_ character: Character) {
        characters.append(character)
        saveCharacters()
        
        // Firebase に保存
        if let userId = UserDefaults.standard.string(forKey: "userId") {
            FirebaseManager.shared.saveUserContentData(userId: userId)
        }
    }
    
    func updateCharacter(_ character: Character) {
        if let index = characters.firstIndex(where: { $0.id == character.id }) {
            characters[index] = character
            saveCharacters()
            
            // Firebase に保存
            if let userId = UserDefaults.standard.string(forKey: "userId") {
                FirebaseManager.shared.saveUserContentData(userId: userId)
            }
        }
    }
    
    func deleteCharacter(_ character: Character) {
        characters.removeAll { $0.id == character.id }
        saveCharacters()
    }
    
    func updateCharacterOrder(_ characters: [Character]) {
        self.characters = characters
        saveCharacters()
    }
}

// MARK: - Character Ranking
struct CharacterRanking: Identifiable {
    let id = UUID()
    let character: Character
    let rank: Int
    let score: Double
}

// MARK: - Date Formatters
extension DateFormatter {
    static let monthDayEnglish: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()
    
    static let japaneseFullDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
}

// MARK: - Image Utilities
func loadImageFromPath(_ path: String) -> UIImage? {
    // First try as a full path
    if let image = UIImage(contentsOfFile: path) {
        return image
    }
    
    // Then try in Documents directory
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let imagePath = documentsPath.appendingPathComponent(path)
    
    if let image = UIImage(contentsOfFile: imagePath.path) {
        return image
    }
    
    // Finally try as a bundle resource
    return UIImage(named: path)
}

func saveImageToDocuments(_ image: UIImage) -> String? {
    guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
    
    let filename = UUID().uuidString + ".jpg"
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let filePath = documentsPath.appendingPathComponent(filename)
    
    do {
        try data.write(to: filePath)
        return filename
    } catch {
        print("Error saving image: \(error)")
        return nil
    }
}

func deleteImageFromPath(_ path: String) {
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let imagePath = documentsPath.appendingPathComponent(path)
    
    try? FileManager.default.removeItem(at: imagePath)
}