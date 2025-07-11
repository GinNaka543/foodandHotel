import SwiftUI

struct NavigationMenuView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var mainTab: MainTabSelection
    
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
                        Image(systemName: "house.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.blue)
                        Text("Happiness Game")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    
                    Divider()
                    
                    // メニューアイテム
                    VStack(alignment: .leading, spacing: 0) {
                        // ホーム
                        NavigationMenuItem(
                            icon: "house.fill",
                            title: "ホーム",
                            iconColor: .blue
                        ) {
                            mainTab.selectedTab = .home
                            isPresented = false
                        }
                        
                        // キャラクター
                        NavigationMenuItem(
                            icon: "person.3.fill",
                            title: "キャラクター",
                            iconColor: .orange
                        ) {
                            mainTab.selectedTab = .chara
                            isPresented = false
                        }
                        
                        // アニメ
                        NavigationMenuItem(
                            icon: "tv.fill",
                            title: "アニメ",
                            iconColor: .purple
                        ) {
                            mainTab.selectedTab = .anime
                            isPresented = false
                        }
                        
                        // ビジット
                        NavigationMenuItem(
                            icon: "mappin.and.ellipse",
                            title: "ビジット",
                            iconColor: .green
                        ) {
                            mainTab.selectedTab = .visit
                            isPresented = false
                        }
                        
                        // プロダクト
                        NavigationMenuItem(
                            icon: "bag.fill",
                            title: "プロダクト",
                            iconColor: .red
                        ) {
                            mainTab.selectedTab = .card
                            isPresented = false
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
    }
}

struct NavigationMenuItem: View {
    let icon: String
    let title: String
    let iconColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(iconColor)
                    .frame(width: 30)
                
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