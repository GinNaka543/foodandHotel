import SwiftUI
// Firebase removed - import Firebase

// 既存の広告のGitHub URLをraw URLに修正するユーティリティ画面
struct FixExistingAdsView: View {
    @State private var isProcessing = false
    @State private var processedCount = 0
    @State private var totalCount = 0
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("既存広告のGitHub URL修正")
                .font(.title2)
                .bold()
            
            Text("GitHub blob URLを含む広告画像URLを\nraw URLに自動変換します")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            if let success = successMessage {
                Text(success)
                    .foregroundColor(.green)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
            
            if isProcessing {
                ProgressView("処理中... (\(processedCount)/\(totalCount))")
                    .padding()
            } else {
                Button(action: fixExistingAds) {
                    Label("修正を開始", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(isProcessing)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("GitHub URL修正")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func fixExistingAds() {
        isProcessing = true
        errorMessage = nil
        successMessage = nil
        processedCount = 0
        
        // Firebase disabled - functionality not available
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.errorMessage = "Firebase functionality disabled"
            self.isProcessing = false
        }
    }
}