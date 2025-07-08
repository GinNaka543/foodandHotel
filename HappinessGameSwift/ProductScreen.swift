import SwiftUI
import PhotosUI

struct ProductScreen: View {
    @StateObject private var productManager = ProductManager()
    @State private var showMenu = false
    @State private var searchText = ""
    @State private var selectedProduct: Product?
    @State private var showingAdminPanel = false
    
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
                
                Button(action: {
                    showingAdminPanel = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.black)
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
            
            // タブUI
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    Text("ALL")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.bottom, 4)
                        .overlay(
                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(.black),
                            alignment: .bottom
                        )
                    
                    ForEach(["Figures", "Keychains", "Apparel", "Accessories"], id: \.self) { category in
                        Text(category)
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 16)
            
            // Firebase広告
            FirebaseAdView(placement: "product")
                .padding(.top, 8)
            
            // 商品リスト
            ScrollView {
                VStack(spacing: 0) {
                    if filteredProducts.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "shippingbox")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("商品がまだ登録されていません")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                    } else {
                        ForEach(filteredProducts) { product in
                            Button(action: {
                                selectedProduct = product
                            }) {
                                ProductRow(product: product)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .sheet(isPresented: $showingAdminPanel) {
            ProductAdminPanel(productManager: productManager)
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(product: product)
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
                    .frame(width: 80, height: 80)
                    .cornerRadius(12)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 80)
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
                        Label("新規商品を追加", systemImage: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                
                Section("登録済み商品") {
                    ForEach(productManager.products) { product in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(product.title)
                                    .font(.system(size: 16, weight: .medium))
                                Text("¥\(product.price)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            if product.isActive {
                                Text("公開中")
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.2))
                                    .foregroundColor(.green)
                                    .cornerRadius(4)
                            } else {
                                Text("非公開")
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.2))
                                    .foregroundColor(.gray)
                                    .cornerRadius(4)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingProduct = product
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            productManager.deleteProduct(productManager.products[index])
                        }
                    }
                }
            }
            .navigationTitle("商品管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddProduct) {
            AddProductView(productManager: productManager)
        }
        .sheet(item: $editingProduct) { product in
            EditProductView(product: product, productManager: productManager)
        }
    }
}

struct AddProductView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var productManager: ProductManager
    
    @State private var title = ""
    @State private var price = ""
    @State private var description = ""
    @State private var link = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var productImage: UIImage?
    @State private var imageData: Data?
    @State private var selectedPlacements: Set<AdPlacement> = []
    
    var body: some View {
        NavigationView {
            Form {
                Section("商品画像") {
                    PhotosPicker(selection: $selectedImage,
                               matching: .images,
                               photoLibrary: .shared()) {
                        if let productImage = productImage {
                            Image(uiImage: productImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .clipped()
                                .cornerRadius(12)
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                                .frame(height: 200)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                        Text("画像を選択")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                    }
                                )
                        }
                    }
                    .onChange(of: selectedImage) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                productImage = UIImage(data: data)
                                imageData = data
                            }
                        }
                    }
                }
                
                Section("商品情報") {
                    TextField("商品名", text: $title)
                    TextField("価格", text: $price)
                        .keyboardType(.numberPad)
                    TextField("商品説明", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("購入リンク（URL）", text: $link)
                        .autocapitalization(.none)
                }
                
                Section("広告表示場所") {
                    ForEach(AdPlacement.allCases, id: \.self) { placement in
                        HStack {
                            Text(placement.rawValue)
                            Spacer()
                            if selectedPlacements.contains(placement) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
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
            .navigationTitle("新規商品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("追加") {
                        let newProduct = Product(
                            title: title,
                            price: Int(price) ?? 0,
                            description: description,
                            imageData: imageData,
                            link: link,
                            isActive: true,
                            adPlacements: selectedPlacements
                        )
                        productManager.addProduct(newProduct)
                        dismiss()
                    }
                    .disabled(title.isEmpty || price.isEmpty)
                }
            }
        }
    }
}

struct EditProductView: View {
    @Environment(\.dismiss) var dismiss
    let product: Product
    @ObservedObject var productManager: ProductManager
    
    @State private var title: String
    @State private var price: String
    @State private var description: String
    @State private var link: String
    @State private var isActive: Bool
    @State private var selectedImage: PhotosPickerItem?
    @State private var productImage: UIImage?
    @State private var imageData: Data?
    @State private var selectedPlacements: Set<AdPlacement>
    
    init(product: Product, productManager: ProductManager) {
        self.product = product
        self.productManager = productManager
        self._title = State(initialValue: product.title)
        self._price = State(initialValue: String(product.price))
        self._description = State(initialValue: product.description)
        self._link = State(initialValue: product.link)
        self._isActive = State(initialValue: product.isActive)
        self._imageData = State(initialValue: product.imageData)
        self._selectedPlacements = State(initialValue: product.adPlacements)
        if let data = product.imageData {
            self._productImage = State(initialValue: UIImage(data: data))
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("商品画像") {
                    PhotosPicker(selection: $selectedImage,
                               matching: .images,
                               photoLibrary: .shared()) {
                        if let productImage = productImage {
                            Image(uiImage: productImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .clipped()
                                .cornerRadius(12)
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                                .frame(height: 200)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                        Text("画像を選択")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                    }
                                )
                        }
                    }
                    .onChange(of: selectedImage) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                productImage = UIImage(data: data)
                                imageData = data
                            }
                        }
                    }
                }
                
                Section("商品情報") {
                    TextField("商品名", text: $title)
                    TextField("価格", text: $price)
                        .keyboardType(.numberPad)
                    TextField("商品説明", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("購入リンク（URL）", text: $link)
                        .autocapitalization(.none)
                }
                
                Section("広告表示場所") {
                    ForEach(AdPlacement.allCases, id: \.self) { placement in
                        HStack {
                            Text(placement.rawValue)
                            Spacer()
                            if selectedPlacements.contains(placement) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
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
                
                Section("公開設定") {
                    Toggle("商品を公開する", isOn: $isActive)
                }
            }
            .navigationTitle("商品編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        var updatedProduct = product
                        updatedProduct.title = title
                        updatedProduct.price = Int(price) ?? 0
                        updatedProduct.description = description
                        updatedProduct.link = link
                        updatedProduct.isActive = isActive
                        updatedProduct.imageData = imageData
                        updatedProduct.adPlacements = selectedPlacements
                        
                        productManager.updateProduct(updatedProduct)
                        dismiss()
                    }
                    .disabled(title.isEmpty || price.isEmpty)
                }
            }
        }
    }
}