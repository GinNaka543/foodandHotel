import Foundation

enum AdPlacement: String, Codable, CaseIterable {
    case home = "ホームページ"
    case character = "キャラページ"
    case product = "プロダクトページ"
}

enum CharacterType: String, Codable, CaseIterable {
    case anime = "アニメ"
    case character = "キャラクター"
}

struct CharacterCategory: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: CharacterType
    var bannerImageData: Data?
    var createdDate: Date
    
    init(id: UUID = UUID(), name: String, type: CharacterType, bannerImageData: Data? = nil, createdDate: Date = Date()) {
        self.id = id
        self.name = name
        self.type = type
        self.bannerImageData = bannerImageData
        self.createdDate = createdDate
    }
}

struct Product: Identifiable, Codable {
    let id: UUID
    var title: String
    var price: Int
    var description: String
    var imageData: Data?
    var link: String
    var createdDate: Date
    var isActive: Bool
    var adPlacements: Set<AdPlacement>
    var characterCategoryId: UUID?
    
    init(id: UUID = UUID(), title: String, price: Int, description: String = "", imageData: Data? = nil, link: String = "", createdDate: Date = Date(), isActive: Bool = true, adPlacements: Set<AdPlacement> = [], characterCategoryId: UUID? = nil) {
        self.id = id
        self.title = title
        self.price = price
        self.description = description
        self.imageData = imageData
        self.link = link
        self.createdDate = createdDate
        self.isActive = isActive
        self.adPlacements = adPlacements
        self.characterCategoryId = characterCategoryId
    }
}

class ProductManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var characterCategories: [CharacterCategory] = []
    
    private let productsKey = "saved_products"
    private let categoriesKey = "saved_character_categories"
    
    init() {
        loadProducts()
        loadCharacterCategories()
    }
    
    func loadProducts() {
        if let data = UserDefaults.standard.data(forKey: productsKey),
           let decodedProducts = try? JSONDecoder().decode([Product].self, from: data) {
            products = decodedProducts
        }
    }
    
    func saveProducts() {
        if let encoded = try? JSONEncoder().encode(products) {
            UserDefaults.standard.set(encoded, forKey: productsKey)
        }
    }
    
    func addProduct(_ product: Product) {
        products.insert(product, at: 0)
        saveProducts()
    }
    
    func updateProduct(_ product: Product) {
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            products[index] = product
            saveProducts()
        }
    }
    
    func deleteProduct(_ product: Product) {
        products.removeAll { $0.id == product.id }
        saveProducts()
    }
    
    var activeProducts: [Product] {
        products.filter { $0.isActive }
    }
    
    func getProductsForPlacement(_ placement: AdPlacement) -> [Product] {
        products.filter { $0.isActive && $0.adPlacements.contains(placement) }
    }
    
    func loadCharacterCategories() {
        if let data = UserDefaults.standard.data(forKey: categoriesKey),
           let decodedCategories = try? JSONDecoder().decode([CharacterCategory].self, from: data) {
            characterCategories = decodedCategories
        }
    }
    
    func saveCharacterCategories() {
        if let encoded = try? JSONEncoder().encode(characterCategories) {
            UserDefaults.standard.set(encoded, forKey: categoriesKey)
        }
    }
    
    func addCharacterCategory(_ category: CharacterCategory) {
        characterCategories.insert(category, at: 0)
        saveCharacterCategories()
    }
    
    func updateCharacterCategory(_ category: CharacterCategory) {
        if let index = characterCategories.firstIndex(where: { $0.id == category.id }) {
            characterCategories[index] = category
            saveCharacterCategories()
        }
    }
    
    func deleteCharacterCategory(_ category: CharacterCategory) {
        characterCategories.removeAll { $0.id == category.id }
        products.forEach { product in
            if product.characterCategoryId == category.id {
                var updatedProduct = product
                updatedProduct.characterCategoryId = nil
                updateProduct(updatedProduct)
            }
        }
        saveCharacterCategories()
    }
    
    func getProductsForCategory(_ categoryId: UUID) -> [Product] {
        products.filter { $0.isActive && $0.characterCategoryId == categoryId }
    }
    
    func getProductsWithoutCategory() -> [Product] {
        products.filter { $0.isActive && $0.characterCategoryId == nil }
    }
}