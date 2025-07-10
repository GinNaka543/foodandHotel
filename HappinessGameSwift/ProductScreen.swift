import SwiftUI
import PhotosUI

// 欲しい商品用のモデル
struct WishlistItem: Identifiable, Codable {
    let id = UUID()
    var name: String
    var price: Int
    var link: String
    var createdDate = Date()
}

// 欲しい商品管理用のクラス
class WishlistManager: ObservableObject {
    @Published var items: [WishlistItem] = []
    private let wishlistKey = "user_wishlist"
    
    init() {
        loadItems()
    }
    
    func loadItems() {
        if let data = UserDefaults.standard.data(forKey: wishlistKey),
           let decoded = try? JSONDecoder().decode([WishlistItem].self, from: data) {
            items = decoded
        }
    }
    
    func saveItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: wishlistKey)
        }
    }
    
    func addItem(_ item: WishlistItem) {
        items.append(item)
        saveItems()
    }
    
    func removeItem(_ item: WishlistItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
    }
}

struct ProductScreen: View {
    @StateObject private var productManager = ProductManager()
    @StateObject private var wishlistManager = WishlistManager()
    @State private var showMenu = false
    @State private var searchText = ""
    @State private var selectedProduct: Product?
    @State private var showingAdminPanel = false
    @State private var selectedTab = "おすすめ"
    @State private var showAddWishlistItem = false
    
    var filteredProducts: [Product] {
        let activeProducts = productManager.activeProducts
        if searchText.isEmpty { return activeProducts }
        return activeProducts.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Button(action: {
                    showMenu.toggle()
                }) {
                    Image(systemName: "line.horizontal.3")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                // 商品を追加ボタン
                Button(action: {
                    showAddWishlistItem = true
                }) {
                    Text("商品を追加")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.purple, Color.purple.opacity(0.7)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // 検索バー
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(.systemGray3))
                    .font(.system(size: 18))
                TextField("Search", text: $searchText)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .font(.system(size: 16))
                    .foregroundColor(.black)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(Color.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .frame(height: 38)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            // タブUI - シンプルに2つのみ
            HStack(spacing: 40) {
                Button(action: {
                    selectedTab = "おすすめ"
                }) {
                    VStack(spacing: 4) {
                        Text("おすすめ")
                            .font(.system(size: 16, weight: selectedTab == "おすすめ" ? .semibold : .regular))
                            .foregroundColor(selectedTab == "おすすめ" ? .black : .gray)
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(selectedTab == "おすすめ" ? .black : .clear)
                    }
                }
                
                Button(action: {
                    selectedTab = "欲しい商品"
                }) {
                    VStack(spacing: 4) {
                        Text("欲しい商品")
                            .font(.system(size: 16, weight: selectedTab == "欲しい商品" ? .semibold : .regular))
                            .foregroundColor(selectedTab == "欲しい商品" ? .black : .gray)
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(selectedTab == "欲しい商品" ? .black : .clear)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            if selectedTab == "おすすめ" {
                // Firebase広告
                FirebaseAdView(placement: "product")
                    .padding(.top, 8)
                
                Spacer()
            } else {
                // 欲しい商品リスト
                ScrollView {
                    VStack(spacing: 0) {
                        if wishlistManager.items.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "cart")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                Text("欲しい商品がありません")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                Text("右上の「商品を追加」から追加してください")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                        } else {
                            ForEach(wishlistManager.items) { item in
                                WishlistItemRow(item: item, wishlistManager: wishlistManager)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
                .padding(.top, 8)
            }
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(product: product)
        }
        .sheet(isPresented: $showAddWishlistItem) {
            AddWishlistItemView(wishlistManager: wishlistManager)
        }
    }
}

// 欲しい商品の行表示
struct WishlistItemRow: View {
    let item: WishlistItem
    let wishlistManager: WishlistManager
    @State private var showDeleteAlert = false
    
    var body: some View {
        HStack(spacing: 16) {
            // アイコン部分
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 168.48, height: 99)
                .overlay(
                    Image(systemName: "cart.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                )
            
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                Text("¥\(item.price)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.red)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = URL(string: item.link) {
                UIApplication.shared.open(url)
            }
        }
        .contextMenu {
            Button(action: {
                showDeleteAlert = true
            }) {
                Label("削除", systemImage: "trash")
            }
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("削除確認"),
                message: Text("この商品を削除しますか？"),
                primaryButton: .destructive(Text("削除")) {
                    wishlistManager.removeItem(item)
                },
                secondaryButton: .cancel(Text("キャンセル"))
            )
        }
    }
}

// 欲しい商品追加画面
struct AddWishlistItemView: View {
    let wishlistManager: WishlistManager
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var priceText = ""
    @State private var link = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("商品情報") {
                    TextField("商品名", text: $name)
                    TextField("価格", text: $priceText)
                        .keyboardType(.numberPad)
                    TextField("リンク", text: $link)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle("商品を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        if let price = Int(priceText), !name.isEmpty {
                            let item = WishlistItem(
                                name: name,
                                price: price,
                                link: link
                            )
                            wishlistManager.addItem(item)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || priceText.isEmpty)
                }
            }
        }
    }
}

struct ProductRow: View {
    let product: Product
    
    var body: some View {
        HStack(spacing: 12) {
            // サムネイル
            if let imageData = product.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 96, height: 80)
                    .cornerRadius(12)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(width: 96, height: 80)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 30))
                            .foregroundColor(.gray)
                    )
            }
            
            // 商品情報
            VStack(alignment: .leading, spacing: 6) {
                Text(product.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                
                Text("¥\(product.price)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.red)
                
                if !product.description.isEmpty {
                    Text(product.description)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}

struct ProductDetailView: View {
    @Environment(\.dismiss) var dismiss
    let product: Product
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 商品画像
                    if let imageData = product.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
                            .cornerRadius(12)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray5))
                            .frame(height: 300)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    // 商品名
                    Text(product.title)
                        .font(.system(size: 24, weight: .bold))
                    
                    // 価格
                    Text("¥\(product.price)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.red)
                    
                    // 商品説明
                    if !product.description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("商品説明")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.gray)
                            Text(product.description)
                                .font(.system(size: 16))
                        }
                    }
                    
                    // 購入ボタン
                    if !product.link.isEmpty, let url = URL(string: product.link) {
                        Button(action: {
                            UIApplication.shared.open(url)
                        }) {
                            Text("購入する")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.red)
                                .cornerRadius(12)
                        }
                        .padding(.top, 20)
                    }
                }
                .padding(16)
            }
            .navigationTitle("商品詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ProductAdminPanel: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var productManager: ProductManager
    @State private var showingAddProduct = false
    @State private var editingProduct: Product?
    
    var body: some View {
        NavigationView {
            List {
                Section("商品管理") {
                    Button(action: {
                        showingAddProduct = true
                    }) {
                        Label("新規商品追加", systemImage: "plus.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                Section("商品一覧") {
                    ForEach(productManager.products) { product in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(product.title)
                                    .font(.headline)
                                Text("¥\(product.price)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if !product.isActive {
                                Text("非表示")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingProduct = product
                        }
                    }
                    .onDelete { indexSet in
                        productManager.products.remove(atOffsets: indexSet)
                        productManager.saveProducts()
                    }
                }
            }
            .navigationTitle("商品管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddProduct) {
            AddEditProductView(productManager: productManager)
        }
        .sheet(item: $editingProduct) { product in
            AddEditProductView(productManager: productManager, editingProduct: product)
        }
    }
}

struct AddEditProductView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var productManager: ProductManager
    var editingProduct: Product?
    
    @State private var title = ""
    @State private var priceText = ""
    @State private var description = ""
    @State private var link = ""
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var isActive = true
    @State private var selectedPlacements: Set<AdPlacement> = []
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本情報") {
                    TextField("商品名", text: $title)
                    TextField("価格", text: $priceText)
                        .keyboardType(.numberPad)
                    TextField("商品説明", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("購入リンク", text: $link)
                        .autocapitalization(.none)
                }
                
                Section("商品画像") {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .frame(maxWidth: .infinity)
                    }
                    
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        Label(selectedImage == nil ? "画像を選択" : "画像を変更", 
                              systemImage: "photo")
                    }
                }
                
                Section("表示設定") {
                    Toggle("アクティブ", isOn: $isActive)
                    
                    VStack(alignment: .leading) {
                        Text("広告配置")
                            .font(.headline)
                        ForEach(AdPlacement.allCases, id: \.self) { placement in
                            HStack {
                                Image(systemName: selectedPlacements.contains(placement) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(selectedPlacements.contains(placement) ? .blue : .gray)
                                Text(placement.rawValue)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedPlacements.contains(placement) {
                                    selectedPlacements.remove(placement)
                                } else {
                                    selectedPlacements.insert(placement)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(editingProduct == nil ? "新規商品" : "商品編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveProduct()
                    }
                    .disabled(title.isEmpty || priceText.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .onAppear {
            if let product = editingProduct {
                title = product.title
                priceText = String(product.price)
                description = product.description
                link = product.link
                isActive = product.isActive
                selectedPlacements = product.adPlacements
                if let imageData = product.imageData {
                    selectedImage = UIImage(data: imageData)
                }
            }
        }
    }
    
    private func saveProduct() {
        guard let price = Int(priceText) else { return }
        
        let imageData = selectedImage?.jpegData(compressionQuality: 0.8)
        
        if let editingProduct = editingProduct,
           let index = productManager.products.firstIndex(where: { $0.id == editingProduct.id }) {
            // 編集
            productManager.products[index].title = title
            productManager.products[index].price = price
            productManager.products[index].description = description
            productManager.products[index].link = link
            productManager.products[index].imageData = imageData
            productManager.products[index].isActive = isActive
            productManager.products[index].adPlacements = selectedPlacements
        } else {
            // 新規追加
            let newProduct = Product(
                id: UUID(),
                title: title,
                price: price,
                description: description,
                imageData: imageData,
                link: link,
                createdDate: Date(),
                isActive: isActive,
                adPlacements: selectedPlacements
            )
            productManager.products.append(newProduct)
        }
        
        productManager.saveProducts()
        dismiss()
    }
}