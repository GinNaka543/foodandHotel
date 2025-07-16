import SwiftUI

struct NavigationMenuView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var mainTab: MainTabSelection
    @State private var showingCharacterOrderModal = false
    @State private var showingAnimeOrderModal = false
    
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
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    // ヘッダー
                    HStack {
                        Image("ログインロゴ")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 60)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    
                    Divider()
                    
                    // メニューアイテム
                    VStack(alignment: .leading, spacing: 0) {
                        // ホーム
                        NavigationMenuItem(
                            title: "ホーム"
                        ) {
                            mainTab.selectedTab = .home
                            isPresented = false
                        }
                        
                        // キャラクター
                        NavigationMenuItem(
                            title: "キャラクター"
                        ) {
                            mainTab.selectedTab = .chara
                            isPresented = false
                        }
                        
                        // アニメ
                        NavigationMenuItem(
                            title: "アニメ"
                        ) {
                            mainTab.selectedTab = .anime
                            isPresented = false
                        }
                        
                        // ビジット
                        NavigationMenuItem(
                            title: "ビジット"
                        ) {
                            mainTab.selectedTab = .visit
                            isPresented = false
                        }
                        
                        // プロダクト
                        NavigationMenuItem(
                            title: "プロダクト"
                        ) {
                            mainTab.selectedTab = .card
                            isPresented = false
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // キャラの順番変更
                        NavigationMenuItem(
                            title: "キャラの順番変更"
                        ) {
                            isPresented = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showingCharacterOrderModal = true
                            }
                        }
                        
                        // アニメの順番変更
                        NavigationMenuItem(
                            title: "アニメの順番変更"
                        ) {
                            isPresented = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showingAnimeOrderModal = true
                            }
                        }
                    }
                    .padding(.top, 8)
                    
                    Spacer()
                }
                .frame(width: 280)
                .background(Color(.systemBackground))
                .cornerRadius(0)
                
                Spacer()
            }
            .offset(x: isPresented ? 0 : -300)
            .animation(.easeOut(duration: 0.25), value: isPresented)
        }
        .sheet(isPresented: $showingCharacterOrderModal) {
            CharacterOrderModal()
        }
        .sheet(isPresented: $showingAnimeOrderModal) {
            AnimeOrderModal()
        }
    }
}

struct NavigationMenuItem: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
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