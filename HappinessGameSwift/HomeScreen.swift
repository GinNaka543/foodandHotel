import SwiftUI

struct HomeScreen: View {
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

#Preview {
    HomeScreen()
} 