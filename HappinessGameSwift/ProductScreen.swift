import SwiftUI
import PhotosUI

// 欲しい商品用のモデル
struct WishlistItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var price: Int
    var link: String
    var imageData: Data?
    var createdDate = Date()
    var characterCategoryId: UUID?
    var memo: String = ""
    var rating: Int = 0
    var deliveryDays: Int = 1
    var siteName: String = ""
    
    init(id: UUID = UUID(), name: String, price: Int, link: String = "", imageData: Data? = nil, createdDate: Date = Date(), characterCategoryId: UUID? = nil, memo: String = "", rating: Int = 0, deliveryDays: Int = 1, siteName: String = "") {
        self.id = id
        self.name = name
        self.price = price
        self.link = link
        self.imageData = imageData
        self.createdDate = createdDate
        self.characterCategoryId = characterCategoryId
        self.memo = memo
        self.rating = rating
        self.deliveryDays = deliveryDays
        self.siteName = siteName
    }
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
    
    func updateItem(_ item: WishlistItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            saveItems()
        }
    }
    
    func getItemsForCategory(_ categoryId: UUID) -> [WishlistItem] {
        items.filter { $0.characterCategoryId == categoryId }
    }
    
    func getItemsWithoutCategory() -> [WishlistItem] {
        items.filter { $0.characterCategoryId == nil }
    }
}

struct ProductScreen: View {
    @StateObject private var productManager = ProductManager()
    @StateObject private var wishlistManager = WishlistManager()
    @State private var showMenu = false
    @State private var showNavigationMenu = false
    @EnvironmentObject var mainTab: MainTabSelection
    @State private var searchText = ""
    @State private var activeSearchText = ""
    @State private var selectedProduct: Product?
    @State private var showingAdminPanel = false
    @State private var selectedTab = "wishlist_items"
    @State private var showAddWishlistItem = false
    @State private var navigateToCategoryList = false
    @State private var selectedCategory: CharacterCategory?
    @State private var showCategorySelection = false
    @State private var showCategoryListFullScreen = false
    @State private var showNewCategoryCreation = false
    
    var filteredProducts: [Product] {
        let activeProducts = productManager.activeProducts
        if activeSearchText.isEmpty { return activeProducts }
        return activeProducts.filter {
            $0.title.localizedCaseInsensitiveContains(activeSearchText) ||
            $0.description.localizedCaseInsensitiveContains(activeSearchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showNavigationMenu = true
                    }
                }) {
                    Image(systemName: "line.horizontal.3")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                // 言語切り替えボタン
                LanguageButton()
                    .padding(.trailing, 8)
                
                // 商品を追加ボタン
                Button(action: {
                    showCategorySelection = true
                }) {
                    Text(NSLocalizedString("add_product", comment: ""))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.purple, Color.purple.opacity(0.6)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // 検索バー（Amazon風デザイン）
            HStack(spacing: 0) {
                HStack {
                    TextField(NSLocalizedString("search_by_anime_or_character", comment: ""), text: $searchText)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            activeSearchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color(.systemGray3))
                                .font(.system(size: 14))
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.white)
                
                // 検索ボタン
                Button(action: {
                    // 検索を実行
                    activeSearchText = searchText
                    // キーボードを閉じる
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 45, height: 36)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.purple, Color.purple.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.purple, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            
            // タブUIを削除（欲しい商品のみ表示）
            
            // キャラクター・アニメ別バナー表示
                ScrollView {
                    VStack(spacing: 12) {
                        // 商品があるカテゴリーを探す
                        let categoriesWithItems = productManager.characterCategories.filter { category in
                            !wishlistManager.getItemsForCategory(category.id).isEmpty
                        }
                        
                        // 検索でフィルタリング
                        let filteredCategories = activeSearchText.isEmpty ? categoriesWithItems : categoriesWithItems.filter { category in
                            category.name.localizedCaseInsensitiveContains(activeSearchText)
                        }
                        
                        if filteredCategories.isEmpty && categoriesWithItems.isEmpty {
                            // 商品が1つもない場合の表示
                            VStack(spacing: 20) {
                                Image(systemName: "bag.circle")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray.opacity(0.5))
                                
                                VStack(spacing: 8) {
                                    Text(NSLocalizedString("register_wishlist_items", comment: ""))
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.black)
                                    
                                    Text(NSLocalizedString("register_favorite_character_anime_products", comment: ""))
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(4)
                                }
                                
                                Button(action: {
                                    showCategorySelection = true
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 18))
                                        Text(NSLocalizedString("add_product_button", comment: ""))
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.cyan, Color.cyan.opacity(0.6)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .cornerRadius(25)
                                }
                                .padding(.top, 10)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                        } else if filteredCategories.isEmpty {
                            // 検索結果がない場合
                            VStack(spacing: 16) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                Text(NSLocalizedString("search_results_not_found", comment: ""))
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                Text(NSLocalizedString("search_with_different_keyword", comment: ""))
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                        } else {
                            // カテゴリー別バナー表示（検索結果に基づいて表示）
                            ForEach(filteredCategories) { category in
                                let itemsForCategory = wishlistManager.getItemsForCategory(category.id)
                                NavigationLink(destination: CategoryListView(
                                    category: category,
                                    wishlistManager: wishlistManager,
                                    productManager: productManager
                                )) {
                                    CategoryBannerView(
                                        title: category.name,
                                        itemCount: itemsForCategory.count,
                                        bannerImageData: category.bannerImageData
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
            .sheet(item: $selectedProduct) { product in
                ProductDetailView(product: product)
            }
            .sheet(isPresented: $showAddWishlistItem) {
                AddWishlistItemView(wishlistManager: wishlistManager, categoryId: selectedCategory?.id)
            }
            .sheet(isPresented: $showingAdminPanel) {
                ProductAdminPanel(productManager: productManager)
            }
            .sheet(isPresented: $showCategorySelection) {
                CategorySelectionView(
                    productManager: productManager,
                    wishlistManager: wishlistManager,
                    onCategorySelected: { category in
                        showCategorySelection = false
                        
                        if category == nil {
                            // 新規カテゴリー作成
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showNewCategoryCreation = true
                            }
                        } else {
                            // 既存カテゴリーを選択した場合、商品追加画面を表示
                            selectedCategory = category
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showAddWishlistItem = true
                            }
                        }
                    }
                )
            }
            .overlay(
                Group {
                    if showNavigationMenu {
                        NavigationMenuView(
                            isPresented: $showNavigationMenu,
                            onShowCharacterOrder: nil,
                            onShowAnimeOrder: nil
                        )
                        .transition(.opacity)
                        .zIndex(2)
                    }
                }
            )
            .sheet(isPresented: $showNewCategoryCreation) {
                SimpleCategoryCreationView(
                    productManager: productManager,
                    wishlistManager: wishlistManager,
                    onComplete: {
                        showNewCategoryCreation = false
                    }
                )
                .onAppear {
                }
            }
        }
    }
}

// カテゴリーバナー表示
struct CategoryBannerView: View {
    let title: String
    let itemCount: Int
    let bannerImageData: Data?
    
    var body: some View {
        ZStack {
                // 背景画像またはデフォルト背景
                if let imageData = bannerImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.purple.opacity(0.7), Color.blue.opacity(0.7)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 120)
                }
                
                // グラデーションオーバーレイ
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black.opacity(0.4), Color.clear]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: 120)
                
                // テキスト情報
                VStack(alignment: .leading, spacing: 4) {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            Text(String(format: NSLocalizedString("product_count_format", comment: ""), itemCount))
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
        }
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// 欲しい商品の行表示
struct WishlistItemRow: View {
    let item: WishlistItem
    let wishlistManager: WishlistManager
    @State private var showDeleteAlert = false
    @State private var isEditingMemo = false
    @State private var tempMemo: String = ""
    @State private var showDeliveryPicker = false
    @State private var tempDeliveryDays: Int = 1
    @State private var showImagePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isEditingTitle = false
    @State private var tempTitle: String = ""
    @State private var isEditingSite = false
    @State private var tempSiteName: String = ""
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 商品画像（縦長）
            ZStack {
                if let imageData = item.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 180, height: 240)
                        .cornerRadius(4)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 180, height: 240)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 30))
                                .foregroundColor(.gray.opacity(0.4))
                        )
                }
            }
            .onTapGesture {
                if !item.link.isEmpty, let url = URL(string: item.link) {
                    UIApplication.shared.open(url)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                // 商品名
                if isEditingTitle {
                    TextField(NSLocalizedString("product_name", comment: ""), text: $tempTitle, onCommit: {
                        saveTitle()
                    })
                    .font(.system(size: 14))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                } else {
                    Text(item.name)
                        .font(.system(size: 14))
                        .foregroundColor(Color(UIColor.label))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .onTapGesture {
                            tempTitle = item.name
                            isEditingTitle = true
                        }
                }
                
                // 評価（星）
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= item.rating ? "star.fill" : "star")
                            .font(.system(size: 12))
                            .foregroundColor(star <= item.rating ? .orange : .gray.opacity(0.3))
                            .onTapGesture {
                                updateRating(star)
                            }
                    }
                    Text("(\(item.rating))")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                
                // サイト名
                if isEditingSite {
                    TextField(NSLocalizedString("site_name", comment: ""), text: $tempSiteName, onCommit: {
                        saveSiteName()
                    })
                    .font(.system(size: 12))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                } else {
                    HStack {
                        Image(systemName: "globe")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Text(item.siteName.isEmpty ? NSLocalizedString("add_site_name", comment: "") : item.siteName)
                            .font(.system(size: 12))
                            .foregroundColor(item.siteName.isEmpty ? .gray.opacity(0.6) : .gray)
                    }
                    .onTapGesture {
                        tempSiteName = item.siteName
                        isEditingSite = true
                    }
                }
                
                // 価格
                HStack(spacing: 0) {
                    Text("¥")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    Text(item.price.formatted())
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.red)
                }
                
                // プライム配送風の表示
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                    Text(getDeliveryText())
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                }
                .onTapGesture {
                    tempDeliveryDays = item.deliveryDays
                    showDeliveryPicker = true
                }
                
                // メモ欄
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("memo_label", comment: ""))
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    
                    if isEditingMemo {
                        TextField(NSLocalizedString("enter_memo", comment: ""), text: $tempMemo, onCommit: {
                            saveMemo()
                        })
                        .font(.system(size: 12))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    } else {
                        Text(item.memo.isEmpty ? NSLocalizedString("tap_to_add_memo", comment: "") : item.memo)
                            .font(.system(size: 12))
                            .foregroundColor(item.memo.isEmpty ? .gray.opacity(0.6) : Color(UIColor.label))
                            .lineLimit(2)
                            .onTapGesture {
                                tempMemo = item.memo
                                isEditingMemo = true
                            }
                    }
                }
                .padding(.top, 4)
                
                // 商品を見るボタン
                Button(action: {
                    if !item.link.isEmpty, let url = URL(string: item.link) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 12))
                        Text(NSLocalizedString("view_product", comment: ""))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black)
                    .cornerRadius(6)
                }
                .padding(.top, 8)
                .opacity(item.link.isEmpty ? 0.5 : 1.0)
                .disabled(item.link.isEmpty)
                
                Spacer()
            }
            
            Spacer()
        }
        .padding(.vertical, 16)
        .background(Color(UIColor.systemBackground))
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: {
                showDeleteAlert = true
            }) {
                Label(NSLocalizedString("delete", comment: ""), systemImage: "trash")
            }
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text(NSLocalizedString("delete_confirm_title", comment: "")),
                message: Text(NSLocalizedString("delete_product_confirm_message", comment: "")),
                primaryButton: .destructive(Text(NSLocalizedString("delete", comment: ""))) {
                    wishlistManager.removeItem(item)
                },
                secondaryButton: .cancel(Text(NSLocalizedString("cancel", comment: "")))
            )
        }
        .sheet(isPresented: $showDeliveryPicker) {
            NavigationView {
                VStack {
                    Text(NSLocalizedString("select_delivery_days", comment: ""))
                        .font(.headline)
                        .padding()
                    
                    Picker(NSLocalizedString("delivery_days", comment: ""), selection: $tempDeliveryDays) {
                        ForEach(1...30, id: \.self) { days in
                            Text(String(format: NSLocalizedString("days_later_format", comment: ""), days))
                                .tag(days)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 150)
                    
                    Spacer()
                }
                .navigationBarItems(
                    leading: Button(NSLocalizedString("cancel", comment: "")) {
                        showDeliveryPicker = false
                    },
                    trailing: Button(NSLocalizedString("save", comment: "")) {
                        updateDeliveryDays(tempDeliveryDays)
                        showDeliveryPicker = false
                    }
                )
            }
        }
        .photosPicker(isPresented: $showImagePicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task(priority: .userInitiated) { @MainActor in
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    selectedImage = uiImage
                    updateImage(uiImage)
                }
            }
        }
    }
    
    private func saveMemo() {
        var updatedItem = item
        updatedItem.memo = tempMemo
        wishlistManager.updateItem(updatedItem)
        isEditingMemo = false
    }
    
    private func updateRating(_ rating: Int) {
        var updatedItem = item
        updatedItem.rating = rating
        wishlistManager.updateItem(updatedItem)
    }
    
    private func updateDeliveryDays(_ days: Int) {
        var updatedItem = item
        updatedItem.deliveryDays = days
        wishlistManager.updateItem(updatedItem)
    }
    
    private func getDeliveryText() -> String {
        if item.deliveryDays == 1 {
            return NSLocalizedString("delivery_tomorrow", comment: "")
        } else {
            return String(format: NSLocalizedString("delivery_days_format", comment: ""), item.deliveryDays)
        }
    }
    
    private func saveTitle() {
        var updatedItem = item
        updatedItem.name = tempTitle
        wishlistManager.updateItem(updatedItem)
        isEditingTitle = false
    }
    
    private func saveSiteName() {
        var updatedItem = item
        updatedItem.siteName = tempSiteName
        wishlistManager.updateItem(updatedItem)
        isEditingSite = false
    }
    
    private func updateImage(_ image: UIImage) {
        var updatedItem = item
        updatedItem.imageData = image.jpegData(compressionQuality: 0.8)
        wishlistManager.updateItem(updatedItem)
    }
}

// 欲しい商品追加画面
// カテゴリー選択画面
struct CategorySelectionView: View {
    @ObservedObject var productManager: ProductManager
    @ObservedObject var wishlistManager: WishlistManager
    let onCategorySelected: (CharacterCategory?) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var showNewCategoryView = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 新規カテゴリー作成ボタン
                Button(action: {
                    
                    // 一旦このモーダルを閉じて、新規作成画面を開く
                    dismiss()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onCategorySelected(nil)
                    }
                }) {
                    HStack {
                        VStack(spacing: 16) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                            Text(NSLocalizedString("add_new_character_anime", comment: ""))
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                            Text(NSLocalizedString("specify_product_owner", comment: ""))
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 16)
                .padding(.top, 20)
                
                Text(NSLocalizedString("or_text", comment: ""))
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .padding(.vertical, 20)
                
                Text(NSLocalizedString("select_existing_character_anime", comment: ""))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.bottom, 16)
                
                // 既存カテゴリーリスト（商品があるカテゴリーのみ表示）
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(productManager.characterCategories) { category in
                            let itemCount = wishlistManager.getItemsForCategory(category.id).count
                            if itemCount > 0 {
                                Button(action: {
                                    onCategorySelected(category)
                                }) {
                                    HStack {
                                        // カテゴリー画像
                                        if let imageData = category.bannerImageData,
                                           let uiImage = UIImage(data: imageData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 60, height: 60)
                                                .clipShape(Circle())
                                        } else {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [Color.purple.opacity(0.7), Color.blue.opacity(0.7)]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 60, height: 60)
                                                .overlay(
                                                    Text(String(category.name.prefix(1)))
                                                        .font(.system(size: 24, weight: .bold))
                                                        .foregroundColor(.white)
                                                )
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(category.name)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.black)
                                            Text("\(category.type.displayName) ・ " + String(format: NSLocalizedString("product_count_format", comment: ""), itemCount))
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.gray.opacity(0.05))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle(NSLocalizedString("add_product", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(NSLocalizedString("cancel", comment: "")) {
                    dismiss()
                }
            )
        }
    }
}

struct AddWishlistItemView: View {
    let wishlistManager: WishlistManager
    var categoryId: UUID?
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var priceText = ""
    @State private var link = ""
    @State private var selectedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @StateObject private var productManager = ProductManager()
    
    var body: some View {
        NavigationView {
            Form {
                Section(NSLocalizedString("product_image", comment: "")) {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .frame(maxWidth: .infinity)
                    }
                    
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(selectedImage == nil ? NSLocalizedString("select_image", comment: "") : NSLocalizedString("change_image", comment: ""), 
                              systemImage: "photo")
                    }
                }
                
                Section(NSLocalizedString("basic_info_section", comment: "")) {
                    TextField(NSLocalizedString("product_name", comment: ""), text: $name)
                    TextField(NSLocalizedString("price_label", comment: ""), text: $priceText)
                        .keyboardType(.numberPad)
                    TextField(NSLocalizedString("purchase_link", comment: ""), text: $link)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle(NSLocalizedString("add_product", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(NSLocalizedString("cancel", comment: "")) {
                    dismiss()
                },
                trailing: Button(NSLocalizedString("save", comment: "")) {
                    if let price = Int(priceText), !name.isEmpty {
                        let imageData = selectedImage?.jpegData(compressionQuality: 0.8)
                        let item = WishlistItem(
                            name: name,
                            price: price,
                            link: link,
                            imageData: imageData,
                            characterCategoryId: categoryId
                        )
                        wishlistManager.addItem(item)
                        dismiss()
                    }
                }
                .disabled(name.isEmpty || priceText.isEmpty)
            )
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task(priority: .userInitiated) { @MainActor in
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
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
                            Text(NSLocalizedString("product_description", comment: ""))
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
                            Text(NSLocalizedString("purchase_button", comment: ""))
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
            .navigationTitle(NSLocalizedString("product_details", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button(NSLocalizedString("close", comment: "")) {
                    dismiss()
                }
            )
        }
    }
}

struct ProductAdminPanel: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var productManager: ProductManager
    @State private var showingAddProduct = false
    @State private var editingProduct: Product?
    @State private var showingAddCategory = false
    @State private var editingCategory: CharacterCategory?
    
    var body: some View {
        NavigationView {
            List {
                Section(NSLocalizedString("category_management", comment: "")) {
                    Button(action: {
                        showingAddCategory = true
                    }) {
                        Label(NSLocalizedString("add_new_category", comment: ""), systemImage: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                
                Section(NSLocalizedString("category_list", comment: "")) {
                    ForEach(productManager.characterCategories) { category in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(category.name)
                                    .font(.headline)
                                Text(category.type.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingCategory = category
                        }
                    }
                    .onDelete { indexSet in
                        let categories = productManager.characterCategories
                        for index in indexSet {
                            productManager.deleteCharacterCategory(categories[index])
                        }
                    }
                }
                
                Section(NSLocalizedString("product_management", comment: "")) {
                    Button(action: {
                        showingAddProduct = true
                    }) {
                        Label(NSLocalizedString("add_new_product", comment: ""), systemImage: "plus.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                Section(NSLocalizedString("product_list", comment: "")) {
                    ForEach(productManager.products) { product in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(product.title)
                                    .font(.headline)
                                Text("¥\(product.price)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if let categoryId = product.characterCategoryId,
                                   let category = productManager.characterCategories.first(where: { $0.id == categoryId }) {
                                    Text(category.name)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                            Spacer()
                            if !product.isActive {
                                Text(NSLocalizedString("hidden_label", comment: ""))
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
            .navigationTitle(NSLocalizedString("product_management", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button(NSLocalizedString("complete", comment: "")) {
                    dismiss()
                }
            )
        }
        .sheet(isPresented: $showingAddProduct) {
            AddEditProductView(productManager: productManager)
        }
        .sheet(item: $editingProduct) { product in
            AddEditProductView(productManager: productManager, editingProduct: product)
        }
        .sheet(isPresented: $showingAddCategory) {
            AddEditCategoryView(productManager: productManager)
        }
        .sheet(item: $editingCategory) { category in
            AddEditCategoryView(productManager: productManager, editingCategory: category)
        }
    }
}

struct CategoryListView: View {
    let category: CharacterCategory?
    @ObservedObject var wishlistManager: WishlistManager
    @ObservedObject var productManager: ProductManager
    @State private var showAddWishlistItem = false
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var activeSearchText = ""
    @State private var showCategoryEdit = false
    
    var categoryItems: [WishlistItem] {
        let items: [WishlistItem]
        if let category = category {
            items = wishlistManager.getItemsForCategory(category.id)
        } else {
            items = wishlistManager.getItemsWithoutCategory()
        }
        
        if activeSearchText.isEmpty {
            return items
        } else {
            return items.filter { item in
                item.name.localizedCaseInsensitiveContains(activeSearchText) ||
                item.siteName.localizedCaseInsensitiveContains(activeSearchText) ||
                item.memo.localizedCaseInsensitiveContains(activeSearchText)
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 検索バー（Amazon風デザイン）
                HStack(spacing: 0) {
                    HStack {
                        TextField(NSLocalizedString("search_by_anime_or_character", comment: ""), text: $searchText)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .font(.system(size: 14))
                            .foregroundColor(.black)
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                activeSearchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color(.systemGray3))
                                    .font(.system(size: 14))
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.white)
                    
                    // 検索ボタン
                    Button(action: {
                        // 検索を実行
                        activeSearchText = searchText
                        // キーボードを閉じる
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 45, height: 36)
                            .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.purple, Color.purple.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    }
                }
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.purple, lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                    // バナー部分（角丸で両端に余白）
                    ZStack {
                        // 背景画像またはデフォルト背景
                        if let category = category,
                           let imageData = category.bannerImageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 180)
                                .clipped()
                                .cornerRadius(16)
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.purple.opacity(0.7), Color.blue.opacity(0.7)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: 180)
                        }
                        
                        // グラデーションオーバーレイ
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.black.opacity(0.6), Color.clear]),
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(height: 180)
                        
                        // テキスト情報
                        VStack(alignment: .leading, spacing: 4) {
                            Spacer()
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category?.name ?? NSLocalizedString("other_category", comment: ""))
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                    Text(String(format: NSLocalizedString("product_count_format", comment: ""), categoryItems.count))
                                        .font(.system(size: 16))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    
                    // 商品リスト
                    VStack(spacing: 0) {
                    if categoryItems.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: activeSearchText.isEmpty ? "cart" : "magnifyingglass")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text(activeSearchText.isEmpty ? NSLocalizedString("no_products", comment: "") : NSLocalizedString("search_results_not_found", comment: ""))
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                            Text(activeSearchText.isEmpty ? NSLocalizedString("add_products_instruction", comment: "") : NSLocalizedString("search_with_different_keyword", comment: ""))
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                    } else {
                        ForEach(categoryItems) { item in
                            VStack(spacing: 0) {
                                WishlistItemRow(item: item, wishlistManager: wishlistManager)
                                    .padding(.horizontal, 16)
                                
                                Divider()
                                    .padding(.leading, 208)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 100)
        }
        .navigationTitle(category?.name ?? NSLocalizedString("other_category", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 10) {
                    // ギアボタン
                    if category != nil {
                        Button(action: {
                            showCategoryEdit = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // 商品追加ボタン
                    Button(action: {
                        showAddWishlistItem = true
                    }) {
                        Text(NSLocalizedString("add_product", comment: ""))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.cyan, Color.cyan.opacity(0.6)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(16)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddWishlistItem) {
            AddWishlistItemView(wishlistManager: wishlistManager, categoryId: category?.id)
        }
        .sheet(isPresented: $showCategoryEdit) {
            if let category = category {
                CategoryEditView(
                    category: category,
                    productManager: productManager,
                    wishlistManager: wishlistManager,
                    onDelete: {
                        dismiss()
                    }
                )
            }
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
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isActive = true
    @State private var selectedPlacements: Set<AdPlacement> = []
    @State private var selectedCategoryId: UUID?
    
    var body: some View {
        NavigationView {
            Form {
                Section(NSLocalizedString("basic_info_section", comment: "")) {
                    TextField(NSLocalizedString("product_form_title", comment: ""), text: $title)
                    TextField(NSLocalizedString("price_label", comment: ""), text: $priceText)
                        .keyboardType(.numberPad)
                    TextField(NSLocalizedString("description_label", comment: ""), text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    TextField(NSLocalizedString("purchase_link", comment: ""), text: $link)
                        .autocapitalization(.none)
                }
                
                Section(NSLocalizedString("product_image", comment: "")) {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .frame(maxWidth: .infinity)
                    }
                    
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(selectedImage == nil ? NSLocalizedString("select_image", comment: "") : NSLocalizedString("change_image", comment: ""), 
                              systemImage: "photo")
                    }
                }
                
                Section(NSLocalizedString("category_info_section", comment: "")) {
                    Picker(NSLocalizedString("character_anime_label", comment: ""), selection: $selectedCategoryId) {
                        Text(NSLocalizedString("none_option", comment: "")).tag(nil as UUID?)
                        ForEach(productManager.characterCategories) { category in
                            Text("\(category.name) (\(category.type.displayName))")
                                .tag(category.id as UUID?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section(NSLocalizedString("display_settings_section", comment: "")) {
                    Toggle(NSLocalizedString("active_toggle", comment: ""), isOn: $isActive)
                    
                    VStack(alignment: .leading) {
                        Text(NSLocalizedString("ad_placement", comment: ""))
                            .font(.headline)
                        ForEach(AdPlacement.allCases, id: \.self) { placement in
                            HStack {
                                Image(systemName: selectedPlacements.contains(placement) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(selectedPlacements.contains(placement) ? .blue : .gray)
                                Text(placement.displayName)
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
            .navigationTitle(editingProduct == nil ? NSLocalizedString("new_product_title", comment: "") : NSLocalizedString("edit_product_title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(NSLocalizedString("cancel", comment: "")) {
                    dismiss()
                },
                trailing: Button(NSLocalizedString("save", comment: "")) {
                    saveProduct()
                }
                .disabled(title.isEmpty || priceText.isEmpty)
            )
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task(priority: .userInitiated) { @MainActor in
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
        .onAppear {
            if let product = editingProduct {
                title = product.title
                priceText = String(product.price)
                description = product.description
                link = product.link
                isActive = product.isActive
                selectedPlacements = product.adPlacements
                selectedCategoryId = product.characterCategoryId
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
            productManager.products[index].characterCategoryId = selectedCategoryId
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
                adPlacements: selectedPlacements,
                characterCategoryId: selectedCategoryId
            )
            productManager.products.append(newProduct)
        }
        
        productManager.saveProducts()
        dismiss()
    }
}

// シンプルな新規カテゴリー作成画面
struct SimpleCategoryCreationView: View {
    @ObservedObject var productManager: ProductManager
    @ObservedObject var wishlistManager: WishlistManager
    let onComplete: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var categoryName = ""
    @State private var selectedType: CharacterType = .character
    @State private var categoryImage: UIImage?
    @State private var categoryPhotoItem: PhotosPickerItem?
    
    @State private var productName = ""
    @State private var priceText = ""
    @State private var link = ""
    @State private var productImage: UIImage?
    @State private var productPhotoItem: PhotosPickerItem?
    
    var body: some View {
        NavigationView {
            Form {
                Section(NSLocalizedString("category_info_section", comment: "")) {
                    TextField(NSLocalizedString("name_label", comment: ""), text: $categoryName)
                    
                    Picker(NSLocalizedString("type_label", comment: ""), selection: $selectedType) {
                        ForEach(CharacterType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    // カテゴリー画像
                    if let image = categoryImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 150)
                            .frame(maxWidth: .infinity)
                    }
                    
                    PhotosPicker(selection: $categoryPhotoItem, matching: .images) {
                        Label(categoryImage == nil ? NSLocalizedString("select_banner_image", comment: "") : NSLocalizedString("change_banner_image", comment: ""), 
                              systemImage: "photo")
                    }
                }
                
                Section(NSLocalizedString("first_product_required", comment: "")) {
                    TextField(NSLocalizedString("product_name", comment: ""), text: $productName)
                    TextField(NSLocalizedString("price_label", comment: ""), text: $priceText)
                        .keyboardType(.numberPad)
                    TextField(NSLocalizedString("link_optional", comment: ""), text: $link)
                        .autocapitalization(.none)
                    
                    // 商品画像
                    if let image = productImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 150)
                            .frame(maxWidth: .infinity)
                    }
                    
                    PhotosPicker(selection: $productPhotoItem, matching: .images) {
                        Label(productImage == nil ? NSLocalizedString("select_image", comment: "") : NSLocalizedString("change_image", comment: ""), 
                              systemImage: "photo")
                    }
                }
            }
            .navigationTitle(String(format: NSLocalizedString("new_character_format", comment: ""), selectedType.displayName))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(NSLocalizedString("cancel", comment: "")) {
                    dismiss()
                },
                trailing: Button(NSLocalizedString("create", comment: "")) {
                    createCategoryWithProduct()
                }
                .disabled(categoryName.isEmpty || productName.isEmpty || priceText.isEmpty)
            )
        }
        .onChange(of: categoryPhotoItem) { _, newValue in
            Task(priority: .userInitiated) { @MainActor in
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    categoryImage = image
                }
            }
        }
        .onChange(of: productPhotoItem) { _, newValue in
            Task(priority: .userInitiated) { @MainActor in
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    productImage = image
                }
            }
        }
    }
    
    private func createCategoryWithProduct() {
        guard let price = Int(priceText) else { 
            return 
        }
        
        // カテゴリーを作成
        let category = CharacterCategory(
            name: categoryName,
            type: selectedType,
            bannerImageData: categoryImage?.jpegData(compressionQuality: 0.8)
        )
        productManager.addCharacterCategory(category)
        
        // 商品を作成
        let item = WishlistItem(
            name: productName,
            price: price,
            link: link,
            imageData: productImage?.jpegData(compressionQuality: 0.8),
            characterCategoryId: category.id
        )
        wishlistManager.addItem(item)
        
        onComplete()
    }
}

// 新規カテゴリー作成画面
struct NewCategoryCreationView: View {
    @ObservedObject var productManager: ProductManager
    @ObservedObject var wishlistManager: WishlistManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var selectedType: CharacterType = .character
    @State private var selectedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showProductAdd = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(NSLocalizedString("basic_info_section", comment: "")) {
                    TextField(NSLocalizedString("name_label", comment: ""), text: $name)
                    Picker(NSLocalizedString("type_label", comment: ""), selection: $selectedType) {
                        ForEach(CharacterType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(NSLocalizedString("product_image", comment: "")) {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .frame(maxWidth: .infinity)
                    }
                    
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(selectedImage == nil ? NSLocalizedString("select_image", comment: "") : NSLocalizedString("change_image", comment: ""), 
                              systemImage: "photo")
                    }
                }
            }
            .navigationTitle(String(format: NSLocalizedString("new_character_format", comment: ""), selectedType.displayName))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(NSLocalizedString("cancel", comment: "")) {
                    dismiss()
                },
                trailing: Button(NSLocalizedString("next", comment: "")) {
                    showProductAdd = true
                }
                .disabled(name.isEmpty)
            )
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task(priority: .userInitiated) { @MainActor in
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
        .sheet(isPresented: $showProductAdd) {
            NavigationView {
                VStack(spacing: 0) {
                    // カテゴリー情報表示
                    HStack {
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.purple.opacity(0.7))
                                .frame(width: 60, height: 60)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(name)
                                .font(.system(size: 18, weight: .semibold))
                            Text(NSLocalizedString("first_product_required", comment: ""))
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    
                    AddWishlistItemForm(
                        name: name,
                        selectedType: selectedType,
                        bannerImageData: selectedImage?.jpegData(compressionQuality: 0.8),
                        productManager: productManager,
                        wishlistManager: wishlistManager,
                        onComplete: {
                            // すべてのモーダルを閉じる
                            showProductAdd = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                dismiss()
                            }
                        }
                    )
                }
                .navigationTitle(NSLocalizedString("add_product", comment: ""))
                .navigationBarTitleDisplayMode(.inline)
            }
            .interactiveDismissDisabled()
        }
    }
}

// 商品追加フォーム（新規カテゴリー用）
struct AddWishlistItemForm: View {
    let name: String
    let selectedType: CharacterType
    let bannerImageData: Data?
    @ObservedObject var productManager: ProductManager
    @ObservedObject var wishlistManager: WishlistManager
    let onComplete: () -> Void
    
    @State private var productName = ""
    @State private var priceText = ""
    @State private var link = ""
    @State private var selectedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    var body: some View {
        Form {
            Section(NSLocalizedString("product_image", comment: "")) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .frame(maxWidth: .infinity)
                }
                
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(selectedImage == nil ? NSLocalizedString("select_image", comment: "") : NSLocalizedString("change_image", comment: ""), 
                          systemImage: "photo")
                }
            }
            
            Section(NSLocalizedString("basic_info_section", comment: "")) {
                TextField("商品名", text: $productName)
                TextField(NSLocalizedString("price_label", comment: ""), text: $priceText)
                    .keyboardType(.numberPad)
                TextField(NSLocalizedString("purchase_link", comment: ""), text: $link)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            Section {
                Button(action: {
                    if let price = Int(priceText), !productName.isEmpty {
                        // カテゴリーを作成・保存
                        let category = CharacterCategory(
                            name: name,
                            type: selectedType,
                            bannerImageData: bannerImageData
                        )
                        productManager.addCharacterCategory(category)
                        
                        // 商品を保存
                        let imageData = selectedImage?.jpegData(compressionQuality: 0.8)
                        let item = WishlistItem(
                            name: productName,
                            price: price,
                            link: link,
                            imageData: imageData,
                            characterCategoryId: category.id
                        )
                        wishlistManager.addItem(item)
                        
                        // 完了処理
                        DispatchQueue.main.async {
                            onComplete()
                        }
                    }
                }) {
                    Text(NSLocalizedString("complete", comment: ""))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue)
                                .opacity(productName.isEmpty || priceText.isEmpty ? 0.5 : 1.0)
                        )
                }
                .disabled(productName.isEmpty || priceText.isEmpty)
            }
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task(priority: .userInitiated) { @MainActor in
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
    }
}

// 新規カテゴリー作成時の必須商品追加画面
struct NewCategoryProductAddView: View {
    let category: CharacterCategory
    @ObservedObject var productManager: ProductManager
    @ObservedObject var wishlistManager: WishlistManager
    let onComplete: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var priceText = ""
    @State private var link = ""
    @State private var selectedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // カテゴリー情報表示
                HStack {
                    if let imageData = category.bannerImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.purple.opacity(0.7))
                            .frame(width: 60, height: 60)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name)
                            .font(.system(size: 18, weight: .semibold))
                        Text(NSLocalizedString("add_first_product", comment: ""))
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                
                Form {
                    Section(NSLocalizedString("product_image", comment: "")) {
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 200)
                                .frame(maxWidth: .infinity)
                        }
                        
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label(selectedImage == nil ? NSLocalizedString("select_image", comment: "") : NSLocalizedString("change_image", comment: ""), 
                                  systemImage: "photo")
                        }
                    }
                    
                    Section(NSLocalizedString("basic_info_section", comment: "")) {
                        TextField(NSLocalizedString("product_name", comment: ""), text: $name)
                        TextField(NSLocalizedString("price_label", comment: ""), text: $priceText)
                            .keyboardType(.numberPad)
                        TextField(NSLocalizedString("purchase_link", comment: ""), text: $link)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("add_product", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button(NSLocalizedString("complete", comment: "")) {
                    if let price = Int(priceText), !name.isEmpty {
                        // カテゴリーを保存
                        productManager.addCharacterCategory(category)
                        
                        // 商品を保存
                        let imageData = selectedImage?.jpegData(compressionQuality: 0.8)
                        let item = WishlistItem(
                            name: name,
                            price: price,
                            link: link,
                            imageData: imageData,
                            characterCategoryId: category.id
                        )
                        wishlistManager.addItem(item)
                        
                        onComplete()
                    }
                }
                .disabled(name.isEmpty || priceText.isEmpty)
            )
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task(priority: .userInitiated) { @MainActor in
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
        .interactiveDismissDisabled()  // スワイプで閉じるのを無効化
    }
}

struct AddEditCategoryView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var productManager: ProductManager
    var editingCategory: CharacterCategory?
    
    @State private var name = ""
    @State private var selectedType: CharacterType = .character
    @State private var selectedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    var body: some View {
        NavigationView {
            Form {
                Section(NSLocalizedString("basic_info_section", comment: "")) {
                    TextField(NSLocalizedString("name_label", comment: ""), text: $name)
                    Picker(NSLocalizedString("type_label", comment: ""), selection: $selectedType) {
                        ForEach(CharacterType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(NSLocalizedString("product_image", comment: "")) {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .frame(maxWidth: .infinity)
                    }
                    
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(selectedImage == nil ? NSLocalizedString("select_image", comment: "") : NSLocalizedString("change_image", comment: ""), 
                              systemImage: "photo")
                    }
                }
            }
            .navigationTitle(editingCategory == nil ? NSLocalizedString("new_category_creation", comment: "") : NSLocalizedString("category_management", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(NSLocalizedString("cancel", comment: "")) {
                    dismiss()
                },
                trailing: Button(NSLocalizedString("save", comment: "")) {
                    saveCategory()
                }
                .disabled(name.isEmpty)
            )
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task(priority: .userInitiated) { @MainActor in
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
        .onAppear {
            if let category = editingCategory {
                name = category.name
                selectedType = category.type
                if let imageData = category.bannerImageData {
                    selectedImage = UIImage(data: imageData)
                }
            }
        }
    }
    
    private func saveCategory() {
        let imageData = selectedImage?.jpegData(compressionQuality: 0.8)
        
        if let editingCategory = editingCategory {
            var updatedCategory = editingCategory
            updatedCategory.name = name
            updatedCategory.type = selectedType
            updatedCategory.bannerImageData = imageData
            productManager.updateCharacterCategory(updatedCategory)
        } else {
            let newCategory = CharacterCategory(
                name: name,
                type: selectedType,
                bannerImageData: imageData
            )
            productManager.addCharacterCategory(newCategory)
        }
        
        dismiss()
    }
}

// MARK: - CategoryEditView Helper Views

// カテゴリー情報セクション
struct CategoryInfoSection: View {
    @Binding var editedName: String
    @Binding var selectedImage: UIImage?
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let category: CharacterCategory
    
    var body: some View {
        Section("カテゴリー情報") {
            // カテゴリー名
            TextField(NSLocalizedString("name_label", comment: ""), text: $editedName)
                .font(.system(size: 16))
            
            // バナー画像
            VStack {
                CategoryBannerImage(selectedImage: selectedImage, category: category)
                
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack {
                        Image(systemName: "photo")
                        Text(NSLocalizedString("change_banner_image", comment: ""))
                    }
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .padding(.top, 8)
                }
            }
        }
    }
}

// バナー画像表示
struct CategoryBannerImage: View {
    let selectedImage: UIImage?
    let category: CharacterCategory
    
    var body: some View {
        if let image = selectedImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 150)
                .clipped()
                .cornerRadius(12)
        } else if let imageData = category.bannerImageData,
                  let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 150)
                .clipped()
                .cornerRadius(12)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 150)
                .overlay(
                    VStack {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text(NSLocalizedString("no_banner_image", comment: ""))
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                )
        }
    }
}

// 商品リストセクション
struct CategoryProductsSection: View {
    let category: CharacterCategory
    let wishlistManager: WishlistManager
    @Binding var itemToDelete: WishlistItem?
    @Binding var showDeleteItemAlert: Bool
    
    var body: some View {
        Section(NSLocalizedString("registered_products", comment: "")) {
            let categoryItems = wishlistManager.getItemsForCategory(category.id)
            if categoryItems.isEmpty {
                Text(NSLocalizedString("no_products", comment: ""))
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
            } else {
                ForEach(categoryItems) { item in
                    CategoryProductRow(
                        item: item,
                        itemToDelete: $itemToDelete,
                        showDeleteItemAlert: $showDeleteItemAlert
                    )
                }
            }
        }
    }
}

// 商品行
struct CategoryProductRow: View {
    let item: WishlistItem
    @Binding var itemToDelete: WishlistItem?
    @Binding var showDeleteItemAlert: Bool
    
    var body: some View {
        HStack {
            // 商品画像
            ProductThumbnail(item: item)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                Text("¥\(item.price)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // 削除ボタン
            Button(action: {
                itemToDelete = item
                showDeleteItemAlert = true
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.vertical, 4)
    }
}

// 商品サムネイル
struct ProductThumbnail: View {
    let item: WishlistItem
    
    var body: some View {
        if let imageData = item.imageData,
           let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .cornerRadius(4)
                .clipped()
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 16))
                        .foregroundColor(.gray.opacity(0.5))
                )
        }
    }
}

// カテゴリー編集ビュー（ポップアップ用）
struct CategoryEditView: View {
    let category: CharacterCategory
    @ObservedObject var productManager: ProductManager
    @ObservedObject var wishlistManager: WishlistManager
    let onDelete: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var editedName: String = ""
    @State private var selectedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showDeleteAlert = false
    @State private var showDeleteItemAlert = false
    @State private var itemToDelete: WishlistItem?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // カスタムヘッダー
                ZStack {
                    Text(NSLocalizedString("edit_category", comment: ""))
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                    
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.black)
                        }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemGray6))
                
                Form {
                    // カテゴリー情報セクション
                    CategoryInfoSection(
                        editedName: $editedName,
                        selectedImage: $selectedImage,
                        selectedPhotoItem: $selectedPhotoItem,
                        category: category
                    )
                    
                    // 商品リストセクション
                    CategoryProductsSection(
                        category: category,
                        wishlistManager: wishlistManager,
                        itemToDelete: $itemToDelete,
                        showDeleteItemAlert: $showDeleteItemAlert
                    )
                    
                    // 削除セクション
                    Section {
                        Button(action: {
                            showDeleteAlert = true
                        }) {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text(NSLocalizedString("delete_category", comment: ""))
                                Spacer()
                            }
                            .foregroundColor(.red)
                            .font(.system(size: 16, weight: .medium))
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            editedName = category.name
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue = newValue else { return }
            Task.detached(priority: .userInitiated) {
                if let data = try? await newValue.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        self.selectedImage = image
                    }
                }
            }
        }
        .alert(NSLocalizedString("delete_category_title", comment: ""), isPresented: $showDeleteAlert) {
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {}
            Button(NSLocalizedString("delete", comment: ""), role: .destructive) {
                deleteCategory()
            }
        } message: {
            Text(String(format: NSLocalizedString("delete_category_confirmation", comment: ""), category.name))
        }
        .alert(NSLocalizedString("delete_item_title", comment: ""), isPresented: $showDeleteItemAlert) {
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {}
            Button(NSLocalizedString("delete", comment: ""), role: .destructive) {
                if let item = itemToDelete {
                    withAnimation {
                        wishlistManager.removeItem(item)
                    }
                }
            }
        } message: {
            Text(String(format: NSLocalizedString("delete_item_confirmation", comment: ""), itemToDelete?.name ?? ""))
        }
    }
    
    private func saveChanges() {
        var updatedCategory = category
        updatedCategory.name = editedName
        
        if let image = selectedImage {
            updatedCategory.bannerImageData = image.jpegData(compressionQuality: 0.8)
        }
        
        productManager.updateCharacterCategory(updatedCategory)
        dismiss()
    }
    
    private func deleteCategory() {
        // カテゴリーに属する商品を削除
        let itemsToDelete = wishlistManager.getItemsForCategory(category.id)
        for item in itemsToDelete {
            wishlistManager.removeItem(item)
        }
        
        // カテゴリーを削除
        productManager.deleteCharacterCategory(category)
        
        dismiss()
        onDelete()
    }
}