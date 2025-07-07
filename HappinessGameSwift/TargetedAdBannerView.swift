import SwiftUI

struct TargetedAdBannerView: View {
    let advertisement: Advertisement
    @State private var isImageLoaded = false
    @State private var image: UIImage?
    
    var body: some View {
        Button(action: {
            recordClick()
            if let url = URL(string: advertisement.linkURL) {
                UIApplication.shared.open(url)
            }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(height: 100)
                
                HStack(spacing: 12) {
                    // 画像
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(width: 80, height: 80)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            )
                    }
                    
                    // テキスト
                    VStack(alignment: .leading, spacing: 4) {
                        Text(advertisement.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text(advertisement.description)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        
                        Text("広告")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 12)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadImage()
            recordImpression()
        }
    }
    
    private func loadImage() {
        guard let url = URL(string: advertisement.imageURL) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let uiImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.image = uiImage
                    self.isImageLoaded = true
                }
            }
        }.resume()
    }
    
    private func recordImpression() {
        // インプレッションを記録
        FirebaseManager.shared.recordAdImpression(advertisementId: advertisement.id ?? "")
    }
    
    private func recordClick() {
        // クリックを記録
        FirebaseManager.shared.recordAdClick(advertisementId: advertisement.id ?? "")
    }
}

// 広告表示管理
class AdManager: ObservableObject {
    @Published var currentAds: [Advertisement] = []
    @Published var isLoading = false
    
    func loadAds() {
        let profileManager = UserProfileManager()
        let currentUser = profileManager.currentUser
        
        isLoading = true
        FirebaseManager.shared.fetchAds(for: currentUser) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let ads):
                    self?.currentAds = ads
                case .failure(let error):
                    print("広告の読み込みに失敗: \(error)")
                }
            }
        }
    }
}