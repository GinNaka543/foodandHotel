import SwiftUI

// 言語切り替えボタン（ナビゲーションバー用）
struct LanguageButton: View {
    @State private var showingLanguageSelection = false
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        Button(action: {
            showingLanguageSelection = true
        }) {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                Text(localizationManager.currentLanguage.flag)
                    .font(.caption)
            }
        }
        .sheet(isPresented: $showingLanguageSelection) {
            LanguageSelectionView()
        }
    }
}