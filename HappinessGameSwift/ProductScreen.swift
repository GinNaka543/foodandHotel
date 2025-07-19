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
    @State private var selectedTab = "おすすめ"
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
                
                // 商品を追加ボタン
                Button(action: {
                    print("DEBUG: 商品を追加ボタンがタップされました")
                    print("DEBUG: showCategorySelection = true を設定します")
                    showCategorySelection = true
                    print("DEBUG: showCategorySelection = \(showCategorySelection)")
                }) {
                    Text("商品を追加")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.cyan, Color.cyan.opacity(0.6)]),
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
                    TextField("アニメもしくはキャラから検索", text: $searchText)
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
                        .background(Color.cyan)
                }
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.cyan, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            
            // タブUI - カプセル型デザイン（左寄せ）
            HStack(spacing: 8) {
                Button(action: {
                    selectedTab = "おすすめ"
                }) {
                    Text("おすすめ")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(selectedTab == "おすすめ" ? .white : .black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selectedTab == "おすすめ" ? Color(.darkGray) : Color(.systemGray5))
                        )
                }
                
                Button(action: {
                    selectedTab = "欲しい商品"
                }) {
                    Text("欲しい商品")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(selectedTab == "欲しい商品" ? .white : .black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selectedTab == "欲しい商品" ? Color(.darkGray) : Color(.systemGray5))
                        )
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            
            if selectedTab == "おすすめ" {
                // Firebase広告と商品を表示
                ScrollView {
                    VStack(spacing: 0) {
                        // 複数の広告を一度に表示
                        MultipleFirebaseAdView(placement: "product")
                            .padding(.top, 8)
                        
                        // おすすめ商品リスト
                        VStack(spacing: 0) {
                            ForEach(filteredProducts) { product in
                                Button(action: {
                                    selectedProduct = product
                                }) {
                                    ProductRow(product: product)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                        .padding(.top, 16)
                    }
                    .padding(.bottom, 100)
                }
            } else {
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
                                    Text("欲しい商品を登録しよう")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.black)
                                    
                                    Text("好きなキャラクターやアニメの\n商品を登録して管理できます")
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
                                        Text("商品を追加する")
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
                                Text("検索結果がありません")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                Text("別のキーワードで検索してください")
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
                        print("DEBUG: onCategorySelectedが呼ばれました。category = \(String(describing: category))")
                        showCategorySelection = false
                        
                        if category == nil {
                            // 新規カテゴリー作成
                            print("DEBUG: 新規カテゴリー作成を開始します")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                print("DEBUG: showNewCategoryCreation = true を設定します")
                                showNewCategoryCreation = true
                                print("DEBUG: showNewCategoryCreation = \(showNewCategoryCreation)")
                            }
                        } else {
                            // 既存カテゴリーを選択した場合、商品追加画面を表示
                            print("DEBUG: 既存カテゴリーが選択されました: \(category!.name)")
                            selectedCategory = category
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                print("DEBUG: showAddWishlistItem = true を設定します")
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
                        print("DEBUG: SimpleCategoryCreationView完了")
                        showNewCategoryCreation = false
                    }
                )
                .onAppear {
                    print("DEBUG: SimpleCategoryCreationViewが表示されました")
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
                            Text("\(itemCount)個の商品")
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
                showImagePicker = true
            }
            
            VStack(alignment: .leading, spacing: 6) {
                // 商品名
                if isEditingTitle {
                    TextField("商品名", text: $tempTitle, onCommit: {
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
                    TextField("サイト名", text: $tempSiteName, onCommit: {
                        saveSiteName()
                    })
                    .font(.system(size: 12))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                } else {
                    HStack {
                        Image(systemName: "globe")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Text(item.siteName.isEmpty ? "サイト名を追加" : item.siteName)
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
                    Text("メモ:")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    
                    if isEditingMemo {
                        TextField("メモを入力", text: $tempMemo, onCommit: {
                            saveMemo()
                        })
                        .font(.system(size: 12))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    } else {
                        Text(item.memo.isEmpty ? "タップしてメモを追加" : item.memo)
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
                
                // リンクボタン
                if !item.link.isEmpty {
                    Button(action: {
                        if let url = URL(string: item.link) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "safari")
                                .font(.system(size: 10))
                            Text("商品ページを開く")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.top, 8)
                }
                
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
        .sheet(isPresented: $showDeliveryPicker) {
            NavigationView {
                VStack {
                    Text("配送までの日数を選択")
                        .font(.headline)
                        .padding()
                    
                    Picker("配送日数", selection: $tempDeliveryDays) {
                        ForEach(1...30, id: \.self) { days in
                            Text("\(days)日後")
                                .tag(days)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 150)
                    
                    Spacer()
                }
                .navigationBarItems(
                    leading: Button("キャンセル") {
                        showDeliveryPicker = false
                    },
                    trailing: Button("保存") {
                        updateDeliveryDays(tempDeliveryDays)
                        showDeliveryPicker = false
                    }
                )
            }
        }
        .photosPicker(isPresented: $showImagePicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { newValue in
            Task {
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
            return "明日配送可能"
        } else {
            return "\(item.deliveryDays)日後に配送"
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
                    print("DEBUG: 新規カテゴリー作成ボタンがタップされました")
                    print("DEBUG: showNewCategoryView = \(showNewCategoryView)")
                    
                    // 一旦このモーダルを閉じて、新規作成画面を開く
                    print("DEBUG: dismissを呼び出します")
                    dismiss()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        print("DEBUG: onCategorySelected(nil)を呼び出します")
                        onCategorySelected(nil)
                    }
                }) {
                    HStack {
                        VStack(spacing: 16) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                            Text("新規キャラ/アニメを追加")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                            Text("誰の商品なのか指定します")
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
                
                Text("または")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .padding(.vertical, 20)
                
                Text("既存のキャラ/アニメを選択")
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
                                            Text("\(category.type.rawValue) ・ \(itemCount)個の商品")
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
            .navigationTitle("商品を追加")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("キャンセル") {
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
                Section("商品画像") {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .frame(maxWidth: .infinity)
                    }
                    
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(selectedImage == nil ? "画像を選択" : "画像を変更", 
                              systemImage: "photo")
                    }
                }
                
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
            .navigationBarItems(
                leading: Button("キャンセル") {
                    dismiss()
                },
                trailing: Button("保存") {
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
        .onChange(of: selectedPhotoItem) { newValue in
            Task {
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
            .navigationBarItems(
                trailing: Button("閉じる") {
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
                Section("カテゴリー管理") {
                    Button(action: {
                        showingAddCategory = true
                    }) {
                        Label("新規カテゴリー追加", systemImage: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                
                Section("カテゴリー一覧") {
                    ForEach(productManager.characterCategories) { category in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(category.name)
                                    .font(.headline)
                                Text(category.type.rawValue)
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
                                if let categoryId = product.characterCategoryId,
                                   let category = productManager.characterCategories.first(where: { $0.id == categoryId }) {
                                    Text(category.name)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
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
            .navigationBarItems(
                trailing: Button("完了") {
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
                        TextField("商品を検索", text: $searchText)
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
                            .background(Color.cyan)
                    }
                }
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.cyan, lineWidth: 1)
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
                                    Text(category?.name ?? "その他")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("\(categoryItems.count)個の商品")
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
                            Text(activeSearchText.isEmpty ? "商品がありません" : "検索結果がありません")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                            Text(activeSearchText.isEmpty ? "右上の「商品追加」から追加してください" : "別のキーワードで検索してください")
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
        .navigationTitle(category?.name ?? "その他")
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
                        Text("商品追加")
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
                    
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(selectedImage == nil ? "画像を選択" : "画像を変更", 
                              systemImage: "photo")
                    }
                }
                
                Section("カテゴリー") {
                    Picker("キャラクター・アニメ", selection: $selectedCategoryId) {
                        Text("なし").tag(nil as UUID?)
                        ForEach(productManager.characterCategories) { category in
                            Text("\(category.name) (\(category.type.rawValue))")
                                .tag(category.id as UUID?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
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
            .navigationBarItems(
                leading: Button("キャンセル") {
                    dismiss()
                },
                trailing: Button("保存") {
                    saveProduct()
                }
                .disabled(title.isEmpty || priceText.isEmpty)
            )
        }
        .onChange(of: selectedPhotoItem) { newValue in
            Task {
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
                Section("カテゴリー情報") {
                    TextField("名前", text: $categoryName)
                    
                    Picker("タイプ", selection: $selectedType) {
                        ForEach(CharacterType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
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
                        Label(categoryImage == nil ? "バナー画像を選択" : "バナー画像を変更", 
                              systemImage: "photo")
                    }
                }
                
                Section("最初の商品（必須）") {
                    TextField("商品名", text: $productName)
                    TextField("価格", text: $priceText)
                        .keyboardType(.numberPad)
                    TextField("リンク（任意）", text: $link)
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
                        Label(productImage == nil ? "商品画像を選択" : "商品画像を変更", 
                              systemImage: "photo")
                    }
                }
            }
            .navigationTitle("新規\(selectedType.rawValue)追加")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("キャンセル") {
                    dismiss()
                },
                trailing: Button("作成") {
                    createCategoryWithProduct()
                }
                .disabled(categoryName.isEmpty || productName.isEmpty || priceText.isEmpty)
            )
        }
        .onChange(of: categoryPhotoItem) { newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    categoryImage = image
                }
            }
        }
        .onChange(of: productPhotoItem) { newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    productImage = image
                }
            }
        }
    }
    
    private func createCategoryWithProduct() {
        print("DEBUG: createCategoryWithProductが呼ばれました")
        guard let price = Int(priceText) else { 
            print("DEBUG: 価格の変換に失敗しました: \(priceText)")
            return 
        }
        
        print("DEBUG: カテゴリーを作成します: \(categoryName)")
        // カテゴリーを作成
        let category = CharacterCategory(
            name: categoryName,
            type: selectedType,
            bannerImageData: categoryImage?.jpegData(compressionQuality: 0.8)
        )
        productManager.addCharacterCategory(category)
        print("DEBUG: カテゴリーが作成されました: \(category.id)")
        
        print("DEBUG: 商品を作成します: \(productName)")
        // 商品を作成
        let item = WishlistItem(
            name: productName,
            price: price,
            link: link,
            imageData: productImage?.jpegData(compressionQuality: 0.8),
            characterCategoryId: category.id
        )
        wishlistManager.addItem(item)
        print("DEBUG: 商品が作成されました: \(item.id)")
        
        print("DEBUG: onCompleteを呼び出します")
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
                Section("基本情報") {
                    TextField("名前", text: $name)
                    Picker("タイプ", selection: $selectedType) {
                        ForEach(CharacterType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("バナー画像") {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .frame(maxWidth: .infinity)
                    }
                    
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(selectedImage == nil ? "画像を選択" : "画像を変更", 
                              systemImage: "photo")
                    }
                }
            }
            .navigationTitle("新規\(selectedType.rawValue)追加")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("キャンセル") {
                    dismiss()
                },
                trailing: Button("次へ") {
                    showProductAdd = true
                }
                .disabled(name.isEmpty)
            )
        }
        .onChange(of: selectedPhotoItem) { newValue in
            Task {
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
                            Text("最初の商品を追加してください")
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
                .navigationTitle("商品を追加")
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
            Section("商品画像") {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .frame(maxWidth: .infinity)
                }
                
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(selectedImage == nil ? "画像を選択" : "画像を変更", 
                          systemImage: "photo")
                }
            }
            
            Section("商品情報") {
                TextField("商品名", text: $productName)
                TextField("価格", text: $priceText)
                    .keyboardType(.numberPad)
                TextField("リンク", text: $link)
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
                    Text("完了")
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
        .onChange(of: selectedPhotoItem) { newValue in
            Task {
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
                        Text("最初の商品を追加してください")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                
                Form {
                    Section("商品画像") {
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 200)
                                .frame(maxWidth: .infinity)
                        }
                        
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label(selectedImage == nil ? "画像を選択" : "画像を変更", 
                                  systemImage: "photo")
                        }
                    }
                    
                    Section("商品情報") {
                        TextField("商品名", text: $name)
                        TextField("価格", text: $priceText)
                            .keyboardType(.numberPad)
                        TextField("リンク", text: $link)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
            }
            .navigationTitle("商品を追加")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("完了") {
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
        .onChange(of: selectedPhotoItem) { newValue in
            Task {
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
                Section("基本情報") {
                    TextField("カテゴリー名", text: $name)
                    Picker("タイプ", selection: $selectedType) {
                        ForEach(CharacterType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("バナー画像") {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .frame(maxWidth: .infinity)
                    }
                    
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(selectedImage == nil ? "画像を選択" : "画像を変更", 
                              systemImage: "photo")
                    }
                }
            }
            .navigationTitle(editingCategory == nil ? "新規カテゴリー" : "カテゴリー編集")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("キャンセル") {
                    dismiss()
                },
                trailing: Button("保存") {
                    saveCategory()
                }
                .disabled(name.isEmpty)
            )
        }
        .onChange(of: selectedPhotoItem) { newValue in
            Task {
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
    
    var body: some View {
        NavigationView {
            Form {
                Section("カテゴリー情報") {
                    // カテゴリー名
                    TextField("カテゴリー名", text: $editedName)
                        .font(.system(size: 16))
                    
                    // バナー画像
                    VStack {
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
                                        Text("バナー画像なし")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                    }
                                )
                        }
                        
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            HStack {
                                Image(systemName: "photo")
                                Text("バナー画像を変更")
                            }
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                            .padding(.top, 8)
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        showDeleteAlert = true
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "trash")
                            Text("このカテゴリーを削除")
                            Spacer()
                        }
                        .foregroundColor(.red)
                        .font(.system(size: 16, weight: .medium))
                    }
                }
            }
            .navigationTitle("カテゴリー編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveChanges()
                    }
                    .disabled(editedName.isEmpty)
                }
            }
        }
        .onAppear {
            editedName = category.name
        }
        .onChange(of: selectedPhotoItem) { newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
        .alert("カテゴリーを削除", isPresented: $showDeleteAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                deleteCategory()
            }
        } message: {
            Text("「\(category.name)」を削除しますか？\nこのカテゴリーに含まれる商品も全て削除されます。")
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