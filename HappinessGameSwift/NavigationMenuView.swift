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
                ScrollView {
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
                        // グルメ
                        NavigationMenuItem(
                            title: "グルメ"
                        ) {
                            mainTab.selectedTab = .chara
                            isPresented = false
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // グルメの順番変更
                        NavigationMenuItem(
                            title: "グルメの順番変更"
                        ) {
                            isPresented = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                mainTab.showCharacterOrderModal = true
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        
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