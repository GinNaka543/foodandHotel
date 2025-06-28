import SwiftUI

struct TitleScreen: View {
    @State private var showingHome = false
    
    var body: some View {
        ZStack {
            // 背景色
            Color.black
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // タイトル画像
                Image("title")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 300)
                
                Spacer()
                
                // スタートボタン
                Button(action: {
                    showingHome = true
                }) {
                    Text("START")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(Color.blue)
                        .cornerRadius(25)
                }
                
                Spacer()
            }
        }
        .fullScreenCover(isPresented: $showingHome) {
            HomeScreen()
        }
    }
}

#Preview {
    TitleScreen()
} 