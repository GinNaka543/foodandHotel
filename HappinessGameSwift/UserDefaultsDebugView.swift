import SwiftUI

struct UserDefaultsDebugView: View {
    @State private var sizeReport = ""
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading {
                        ProgressView("Analyzing UserDefaults...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Text(sizeReport)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                    }
                }
            }
            .navigationTitle("UserDefaults Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        analyzeUserDefaults()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clean Up") {
                        performCleanup()
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .onAppear {
            analyzeUserDefaults()
        }
    }
    
    private func analyzeUserDefaults() {
        isLoading = true
        
        DispatchQueue.global(qos: .background).async {
            let report = DataMigrationManager.shared.estimateUserDefaultsSize()
            
            DispatchQueue.main.async {
                self.sizeReport = report
                self.isLoading = false
            }
        }
    }
    
    private func performCleanup() {
        let alert = UIAlertController(
            title: "Clean Up UserDefaults",
            message: "This will remove old migrated data. Are you sure?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clean Up", style: .destructive) { _ in
            DataMigrationManager.shared.cleanupOldData()
            analyzeUserDefaults()
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
}

#if DEBUG
struct UserDefaultsDebugView_Previews: PreviewProvider {
    static var previews: some View {
        UserDefaultsDebugView()
    }
}
#endif