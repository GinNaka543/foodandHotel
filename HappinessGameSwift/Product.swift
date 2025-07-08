import Foundation

struct Product: Identifiable, Codable {
    let id: UUID
    var title: String
    var price: Int
    var description: String
    var imageData: Data?
    var link: String
    var createdDate: Date
    var isActive: Bool
    
    init(id: UUID = UUID(), title: String, price: Int, description: String = "", imageData: Data? = nil, link: String = "", createdDate: Date = Date(), isActive: Bool = true) {
        self.id = id
        self.title = title
        self.price = price
        self.description = description
        self.imageData = imageData
        self.link = link
        self.createdDate = createdDate
        self.isActive = isActive
    }
}

class ProductManager: ObservableObject {
    @Published var products: [Product] = []
    
    private let productsKey = "saved_products"
    
    init() {
        loadProducts()
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
}