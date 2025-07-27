import SwiftUI
import Firebase

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
        
        let db = Firestore.firestore()
        
        db.collection("advertisements").getDocuments { snapshot, error in
            if let error = error {
                self.errorMessage = "エラー: \(error.localizedDescription)"
                self.isProcessing = false
                return
            }
            
            guard let documents = snapshot?.documents else {
                self.errorMessage = "広告が見つかりません"
                self.isProcessing = false
                return
            }
            
            self.totalCount = documents.count
            var updatedCount = 0
            
            let group = DispatchGroup()
            
            for document in documents {
                group.enter()
                
                let data = document.data()
                if let imageURL = data["imageURL"] as? String,
                   imageURL.contains("github.com") && imageURL.contains("/blob/") {
                    
                    // GitHub URLをraw URLに変換
                    let rawURL = imageURL
                        .replacingOccurrences(of: "github.com", with: "raw.githubusercontent.com")
                        .replacingOccurrences(of: "/blob/", with: "/")
                    
                    
                    // Firestoreを更新
                    db.collection("advertisements").document(document.documentID).updateData([
                        "imageURL": rawURL
                    ]) { error in
                        if error == nil {
                            updatedCount += 1
                        }
                        self.processedCount += 1
                        group.leave()
                    }
                } else {
                    self.processedCount += 1
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                self.isProcessing = false
                if updatedCount > 0 {
                    self.successMessage = "\(updatedCount)件の広告URLを修正しました"
                } else {
                    self.successMessage = "修正が必要な広告はありませんでした"
                }
            }
        }
    }
}

// 管理画面に追加するためのボタン
struct FixAdsButton: View {
    @State private var showingFixView = false
    
    var body: some View {
        Button(action: {
            showingFixView = true
        }) {
            Label("GitHub URL修正", systemImage: "wrench.and.screwdriver.fill")
                .foregroundColor(.orange)
        }
        .sheet(isPresented: $showingFixView) {
            NavigationView {
                FixExistingAdsView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("閉じる") {
                                showingFixView = false
                            }
                        }
                    }
            }
        }
    }
}