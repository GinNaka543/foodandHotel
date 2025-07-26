import SwiftUI

struct NavigationMenuView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var mainTab: MainTabSelection
    var onShowCharacterOrder: (() -> Void)?
    var onShowAnimeOrder: (() -> Void)?
    var onShowTermsOfService: (() -> Void)?
    var onShowPrivacyPolicy: (() -> Void)?
    
    var body: some View {
        ZStack {
            // 背景のオーバーレイ
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isPresented = false
                    }
                }
            
            // メニューコンテンツ
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    // セーフエリア対応のための上部スペース
                    Rectangle()
                        .fill(Color.white)
                        .frame(height: 0)
                        .ignoresSafeArea(edges: .top)
                    
                    // ヘッダー
                    HStack {
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                isPresented = false
                            }
                        }) {
                            Image("ログインロゴ")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 60)
                        }
                        .buttonStyle(PlainButtonStyle())
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .padding(.top, 44) // ステータスバーの高さ分
                    
                    Divider()
                    
                    // メニューアイテム
                    VStack(alignment: .leading, spacing: 0) {
                        // ホーム
                        NavigationMenuItem(
                            title: NSLocalizedString("home", comment: "Home menu item")
                        ) {
                            mainTab.selectedTab = .home
                            isPresented = false
                        }
                        
                        // キャラクター
                        NavigationMenuItem(
                            title: NSLocalizedString("character", comment: "Character menu item")
                        ) {
                            mainTab.selectedTab = .chara
                            isPresented = false
                        }
                        
                        // アニメ
                        NavigationMenuItem(
                            title: NSLocalizedString("anime", comment: "Anime menu item")
                        ) {
                            mainTab.selectedTab = .anime
                            isPresented = false
                        }
                        
                        // ビジット
                        NavigationMenuItem(
                            title: NSLocalizedString("visit", comment: "Visit menu item")
                        ) {
                            mainTab.selectedTab = .visit
                            isPresented = false
                        }
                        
                        // プロダクト
                        NavigationMenuItem(
                            title: NSLocalizedString("product", comment: "Product menu item")
                        ) {
                            mainTab.selectedTab = .card
                            isPresented = false
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // キャラの順番変更
                        NavigationMenuItem(
                            title: NSLocalizedString("character_order_menu", comment: "Character order menu item")
                        ) {
                            isPresented = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onShowCharacterOrder?()
                            }
                        }
                        
                        // アニメの順番変更
                        NavigationMenuItem(
                            title: NSLocalizedString("anime_order_menu", comment: "Anime order menu item")
                        ) {
                            isPresented = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onShowAnimeOrder?()
                            }
                        }
                    }
                    .padding(.top, 8)
                    
                    Spacer()
                    
                    // 利用規約
                    Divider()
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                    
                    NavigationMenuItem(
                        title: NSLocalizedString("terms_of_service", comment: "Terms of service"),
                        action: {
                            isPresented = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                NotificationCenter.default.post(
                                    name: Notification.Name("ShowTermsOfService"),
                                    object: nil
                                )
                            }
                        },
                        isGrayed: true
                    )
                    
                    NavigationMenuItem(
                        title: NSLocalizedString("privacy_policy", comment: "Privacy policy"),
                        action: {
                            isPresented = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onShowPrivacyPolicy?()
                            }
                        },
                        isGrayed: true
                    )
                    .padding(.bottom, 20)
                }
                .frame(width: 280)
                .background(Color.white)
                .clipped()
                .ignoresSafeArea(edges: .top)
                
                // 残りの画面エリア（タップでメニューを閉じる）
                Rectangle()
                    .fill(Color.clear)
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isPresented = false
                        }
                    }
            }
            .offset(x: isPresented ? 0 : -280)
            .animation(.easeOut(duration: 0.25), value: isPresented)
        }
    }
}

struct NavigationMenuItem: View {
    let title: String
    let action: () -> Void
    var isGrayed: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isGrayed ? .gray : .primary)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            Color.gray.opacity(0.0001)
        )
    }
}