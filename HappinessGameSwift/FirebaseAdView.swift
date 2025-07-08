import SwiftUI

struct FirebaseAdView: View {
    let placement: String
    @State private var advertisements: [Advertisement] = []
    @State private var currentIndex = 0
    @State private var timer: Timer?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
            } else if !advertisements.isEmpty {
                let ad = advertisements[currentIndex % advertisements.count]
                
                Button(action: {
                    if let url = URL(string: ad.linkURL) {
                        UIApplication.shared.open(url)
                        // クリック記録
                        if let adId = ad.id {
                            FirebaseManager.shared.recordAdClick(advertisementId: adId)
                        }
                    }
                }) {
                    HStack(spacing: 12) {
                        // 広告画像
                        AsyncImage(url: URL(string: ad.imageURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                                .overlay(
                                    ProgressView()
                                )
                        }
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        .clipped()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ad.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                                .lineLimit(1)
                            
                            Text(ad.description)
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        Text("広告")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                }
                .buttonStyle(PlainButtonStyle())
                .onAppear {
                    startTimer()
                    // インプレッション記録
                    if let adId = ad.id {
                        FirebaseManager.shared.recordAdImpression(advertisementId: adId)
                    }
                }
                .onDisappear {
                    stopTimer()
                }
            }
        }
        .onAppear {
            loadAds()
        }
    }
    
    func loadAds() {
        FirebaseManager.shared.fetchAds(for: placement) { result in
            switch result {
            case .success(let ads):
                self.advertisements = ads
                self.isLoading = false
            case .failure(let error):
                print("広告読み込みエラー: \(error)")
                self.isLoading = false
            }
        }
    }
    
    func startTimer() {
        guard advertisements.count > 1 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            withAnimation {
                currentIndex = (currentIndex + 1) % advertisements.count
                // 次の広告のインプレッション記録
                if let adId = advertisements[currentIndex].id {
                    FirebaseManager.shared.recordAdImpression(advertisementId: adId)
                }
            }
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}