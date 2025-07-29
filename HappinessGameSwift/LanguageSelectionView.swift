import SwiftUI

struct LanguageSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var localizationManager = LocalizationManager.shared
    @State private var selectedLanguage: AppLanguage
    
    init() {
        _selectedLanguage = State(initialValue: LocalizationManager.shared.currentLanguage)
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    Button(action: {
                        selectedLanguage = language
                        localizationManager.setLanguage(language)
                    }) {
                        HStack {
                            Text(language.displayName)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("language_title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("done", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// LanguageButtonは別ファイルに移動しました

#Preview {
    LanguageSelectionView()
}