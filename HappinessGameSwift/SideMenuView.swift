import SwiftUI

struct SideMenuView: View {
    @Binding var isShowing: Bool
    @State private var selectedMenuItem: MenuItem?
    
    enum MenuItem: String, CaseIterable, Identifiable {
        var id: String { self.rawValue }
        case profile = "プロフィール"
        case settings = "設定"
        case adminAds = "広告管理"
        case about = "アバウト"
        case logout = "ログアウト"
        
        var icon: String {
            switch self {
            case .profile:
                return "person.circle"
            case .settings:
                return "gear"
            case .adminAds:
                return "megaphone"
            case .about:
                return "info.circle"
            case .logout:
                return "arrow.backward.square"
            }
        }
        
        var isAdminOnly: Bool {
            switch self {
            case .adminAds:
                return true
            default:
                return false
            }
        }
    }
    
    // TODO: 実際のアプリではユーザーの権限を確認
    @State private var isAdmin = true
    
    var body: some View {
        ZStack(alignment: .leading) {
            // 背景（タップで閉じる）
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowing = false
                    }
                }
            
            // メニュー本体
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    // ヘッダー
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text(UserDefaults.standard.string(forKey: "username") ?? "ゲスト")
                            .font(.system(size: 20, weight: .semibold))
                        
                        Text(UserDefaults.standard.string(forKey: "userId") ?? "")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 50)
                    .padding(.bottom, 30)
                    
                    Divider()
                    
                    // メニューアイテム
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(MenuItem.allCases, id: \.self) { item in
                                if !item.isAdminOnly || isAdmin {
                                    MenuItemRow(item: item) {
                                        handleMenuSelection(item)
                                    }
                                    
                                    if item == .settings && isAdmin {
                                        Divider()
                                            .padding(.vertical, 8)
                                        
                                        Text("管理者メニュー")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.gray)
                                            .padding(.horizontal, 20)
                                            .padding(.bottom, 8)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 20)
                    }
                    
                    Spacer()
                    
                    // フッター
                    Text("Happiness Game v1.0")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
                .frame(width: 280)
                .background(Color.white)
                
                Spacer()
            }
            .offset(x: isShowing ? 0 : -280)
        }
        .fullScreenCover(item: $selectedMenuItem) { item in
            switch item {
            case .adminAds:
                AdvertisementAdminScreen()
            default:
                EmptyView()
            }
        }
    }
    
    func handleMenuSelection(_ item: MenuItem) {
        switch item {
        case .profile:
            // プロフィール画面を表示
            print("プロフィール")
        case .settings:
            // 設定画面を表示
            print("設定")
        case .adminAds:
            selectedMenuItem = item
        case .about:
            // アバウト画面を表示
            print("アバウト")
        case .logout:
            // ログアウト処理
            print("ログアウト")
        }
        
        // メニューを閉じる
        withAnimation(.easeInOut(duration: 0.2)) {
            isShowing = false
        }
    }
}

struct MenuItemRow: View {
    let item: SideMenuView.MenuItem
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: item.icon)
                    .font(.system(size: 20))
                    .frame(width: 24)
                    .foregroundColor(item.isAdminOnly ? .purple : .gray)
                
                Text(item.rawValue)
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                
                Spacer()
                
                if item.isAdminOnly {
                    Text("Admin")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.purple.opacity(0.1))
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.white)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}