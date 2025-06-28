import SwiftUI

struct HomeScreen: View {
    @State private var selectedTab = 0
    @State private var happinessLevel: Double = 0.6
    @State private var showingQuote = false
    @State private var currentQuote = ""
    
    private let quotes = [
        "幸せはいつも自分の心が決める",
        "今日一日を大切に生きよう",
        "小さな幸せを積み重ねることが大きな幸せになる",
        "笑顔は幸せの第一歩",
        "感謝の気持ちが幸せを呼び込む"
    ]
    
    var body: some View {
        ZStack {
            // 背景色
            Color.white
                .ignoresSafeArea()
            
            // メインコンテンツ
            if selectedTab == 1 {
                VStack(spacing: 0) {
                    CharaScreen()
                    Spacer()
                    CustomBottomNavigationBar(selectedTab: $selectedTab)
                }
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 24) {
                            // 幸福度メーター
                            VStack(spacing: 8) {
                                Text("今日の幸福度")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                                
                                ProgressView(value: happinessLevel)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .black))
                                    .scaleEffect(y: 2)
                                    .padding(.horizontal)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(radius: 2)
                            
                            // 今日の幸せTips
                            VStack(alignment: .leading, spacing: 8) {
                                Text("今日の幸せTips")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                                
                                Text("・朝日を浴びて深呼吸しよう")
                                    .foregroundColor(.black)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(radius: 2)
                            
                            // 今週のクエスト
                            VStack(alignment: .leading, spacing: 8) {
                                Text("今週のクエスト")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("・旅に出かけよう")
                                    Text("・美味しいもの探し")
                                    Text("・運動しよう")
                                    Text("・SNSやめよう")
                                    Text("・健康になろう")
                                }
                                .foregroundColor(.black)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(radius: 2)
                            
                            // 名言ガチャボタン
                            Button(action: {
                                showRandomQuote()
                            }) {
                                Text("名言ガチャを引く")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 60)
                                    .background(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 0)
                                            .stroke(Color.black, lineWidth: 1)
                                    )
                            }
                            .shadow(radius: 2)
                        }
                        .padding()
                        .padding(.bottom, 95) // ナビゲーションバーの高さ分
                    }
                    Spacer()
                    CustomBottomNavigationBar(selectedTab: $selectedTab)
                }
            }
        }
        .alert("今日の名言", isPresented: $showingQuote) {
            Button("閉じる") { }
        } message: {
            Text(currentQuote)
        }
    }
    
    private func showRandomQuote() {
        currentQuote = quotes.randomElement() ?? "幸せはいつも自分の心が決める"
        showingQuote = true
    }
}

struct CustomBottomNavigationBar: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack(spacing: 0) {
            NavigationItem(
                imageName: "Clogo",
                label: "Home",
                isSelected: selectedTab == 0
            ) {
                selectedTab = 0
            }
            
            NavigationItem(
                systemImage: "person.outline",
                label: "Chara",
                isSelected: selectedTab == 1
            ) {
                selectedTab = 1
            }
            
            NavigationItem(
                systemImage: "play.rectangle",
                label: "Anime",
                isSelected: selectedTab == 2
            ) {
                selectedTab = 2
            }
            
            NavigationItem(
                systemImage: "paintbrush",
                label: "Create",
                isSelected: selectedTab == 3
            ) {
                selectedTab = 3
            }
            
            NavigationItem(
                systemImage: "arrow.left.arrow.right",
                label: "Trade",
                isSelected: selectedTab == 4
            ) {
                selectedTab = 4
            }
        }
    }
}

struct NavigationItem: View {
    let imageName: String?
    let systemImage: String?
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    init(imageName: String? = nil, systemImage: String? = nil, label: String, isSelected: Bool, action: @escaping () -> Void) {
        self.imageName = imageName
        self.systemImage = systemImage
        self.label = label
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // Homeロゴ
                if label == "Home" {
                    Image("Clogo")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 27, height: 27)
                        .foregroundColor(isSelected ? Color.black : Color.gray)
                        .padding(.top, 30)
                }
                // Charaアイコン
                else if label == "Chara" {
                    Image(systemName: "person")
                        .font(.system(size: 24))
                        .frame(height: 24)
                        .foregroundColor(isSelected ? .black : .gray)
                }
                // その他
                else if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 24))
                        .frame(height: 24)
                        .foregroundColor(isSelected ? .black : .gray)
                }
                
                // ラベル（常に表示、色も明示的に指定）
                Text(label)
                    .font(.system(size: 8.4))
                    .foregroundColor(isSelected ? .black : .gray)
                    .padding(.top, 4)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    HomeScreen()
} 