import SwiftUI

struct HomeScreen: View {
    @State private var showCharaScreen = false
    @State private var showAnimeScreen = false
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // ヘッダー
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("中島 銀星")
                            .font(.system(size: 28, weight: .bold))
                        Text("Enter a status message")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Image("sample") // 仮のアイコン画像
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                // ステータスボタン
                HStack {
                    Button(action: {}) {
                        HStack(spacing: 6) {
                            Image(systemName: "music.note")
                                .foregroundColor(.green)
                            Text("Select music")
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                // 検索バー
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search", text: .constant(""))
                        .font(.system(size: 16))
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                // リスト
                VStack(alignment: .leading, spacing: 0) {
                    Text("Friend lists")
                        .font(.system(size: 18, weight: .bold))
                        .padding(.top, 16)
                        .padding(.bottom, 4)
                    ForEach(["Birthday reminders", "Friends", "Groups"], id: \.self) { name in
                        HStack {
                            Circle().fill(Color.gray).frame(width: 40, height: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name)
                                    .font(.system(size: 16, weight: .semibold))
                                Text("サンプル説明")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Text("2")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding(.horizontal, 20)
                // サービス
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Services")
                            .font(.system(size: 18, weight: .bold))
                        Spacer()
                        Text("See all")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 4)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 24) {
                            ForEach(["LINE AI", "Stickers", "Themes", "LINE GIFT", "LINE POINT C", "LINE GAME"], id: \.self) { service in
                                VStack(spacing: 6) {
                                    Circle().stroke(Color.gray, lineWidth: 2).frame(width: 36, height: 36)
                                    Text(service)
                                        .font(.system(size: 12))
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal, 20)
                Spacer(minLength: 0)
            }
            // 下部ナビゲーションバー
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 0) {
                    NavigationBarItem(icon: "house.fill", title: "Home", isSelected: true)
                        .onTapGesture {
                            // 何もしない（現在の画面）
                        }
                    NavigationBarItem(icon: "person.2", title: "Chara", isSelected: false)
                        .onTapGesture {
                            showCharaScreen = true
                        }
                    NavigationBarItem(icon: "tv", title: "Anime", isSelected: false)
                        .onTapGesture {
                            showAnimeScreen = true
                        }
                    NavigationBarItem(icon: "map", title: "Visit", isSelected: false)
                        .onTapGesture {
                            // Visit画面への遷移（未実装）
                        }
                    NavigationBarItem(icon: "creditcard", title: "Card", isSelected: false)
                        .onTapGesture {
                            // Card画面への遷移（未実装）
                        }
                }
                .frame(height: 75)
                .background(Color.white)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(.systemGray4)),
                    alignment: .top
                )
            }
            .edgesIgnoringSafeArea(.bottom)
        }
        .background(Color.white)
        .fullScreenCover(isPresented: $showCharaScreen) {
            CharaScreen()
        }
        .fullScreenCover(isPresented: $showAnimeScreen) {
            AnimeScreen()
        }
    }
}

// プレビュー用
struct HomeScreen_Previews: PreviewProvider {
    static var previews: some View {
        HomeScreen()
    }
} 