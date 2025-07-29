import SwiftUI

struct LanguageSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var localizationManager = LocalizationManager.shared
    @State private var selectedLanguage: AppLanguage
    @State private var isChangingLanguage = false
    @State private var showRestartAlert = false
    
    init() {
        _selectedLanguage = State(initialValue: LocalizationManager.shared.currentLanguage)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                List {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Button(action: {
                            if selectedLanguage != language {
                                selectedLanguage = language
                                changeLanguage(to: language)
                            }
                        }) {
                            HStack {
                                Text(language.flag)
                                    .font(.title2)
                                
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
                        .disabled(isChangingLanguage)
                    }
                }
                .navigationTitle(NSLocalizedString("language_title", comment: ""))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(NSLocalizedString("done", comment: "")) {
                            dismiss()
                        }
                        .disabled(isChangingLanguage)
                    }
                }
                
                // Loading overlay
                if isChangingLanguage {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text(NSLocalizedString("changing_language", comment: "Changing language..."))
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(40)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(20)
                }
            }
        }
        .alert(NSLocalizedString("restart_required", comment: "Restart Required"), isPresented: $showRestartAlert) {
            Button(NSLocalizedString("restart_now", comment: "Restart Now")) {
                // Force app restart
                exit(0)
            }
            Button(NSLocalizedString("restart_later", comment: "Later"), role: .cancel) {
                dismiss()
            }
        } message: {
            Text(NSLocalizedString("restart_message", comment: "The app needs to restart to apply the language change."))
        }
    }
    
    private func changeLanguage(to language: AppLanguage) {
        isChangingLanguage = true
        
        // Change language with completion
        localizationManager.setLanguage(language) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isChangingLanguage = false
                showRestartAlert = true
            }
        }
    }
}

// LanguageButtonは別ファイルに移動しました

#Preview {
    LanguageSelectionView()
}