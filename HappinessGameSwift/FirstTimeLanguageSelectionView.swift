import SwiftUI

struct FirstTimeLanguageSelectionView: View {
    @Binding var hasSelectedLanguage: Bool
    @StateObject private var localizationManager = LocalizationManager.shared
    @State private var selectedLanguage: AppLanguage
    
    init(hasSelectedLanguage: Binding<Bool>) {
        self._hasSelectedLanguage = hasSelectedLanguage
        _selectedLanguage = State(initialValue: LocalizationManager.shared.currentLanguage)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 20) {
                Image(systemName: "globe")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding(.top, 60)
                
                Text("Select Your Language")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Choose your preferred language")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 40)
            
            // Language List
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Button(action: {
                            selectedLanguage = language
                            localizationManager.setLanguage(language, shouldRestart: false)
                        }) {
                            HStack {
                                Text(language.displayName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedLanguage == language {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.title2)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedLanguage == language ? Color.blue.opacity(0.1) : Color(.systemGray6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedLanguage == language ? Color.blue : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
            
            // Continue Button
            Button(action: {
                // Save the selection and continue
                UserDefaults.standard.set(true, forKey: "hasSelectedLanguage")
                hasSelectedLanguage = true
            }) {
                Text(NSLocalizedString("continue", comment: "Continue"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    FirstTimeLanguageSelectionView(hasSelectedLanguage: .constant(false))
}