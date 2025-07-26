import SwiftUI

struct ProductAdView: View {
    let placement: AdPlacement
    @EnvironmentObject var productManager: ProductManager
    @State private var currentIndex = 0
    @State private var timer: Timer?
    
    var adsForPlacement: [Product] {
        productManager.getProductsForPlacement(placement)
    }
    
    var body: some View {
        Group {
            if !adsForPlacement.isEmpty {
                let product = adsForPlacement[currentIndex % adsForPlacement.count]
                
                Button(action: {
                    if let url = URL(string: product.link), !product.link.isEmpty {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack(spacing: 12) {
                        // 商品画像
                        if let imageData = product.imageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .cornerRadius(8)
                                .clipped()
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                                .lineLimit(1)
                            
                            Text("¥\(product.price)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        Text(NSLocalizedString("advertisement", comment: "Advertisement"))
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
                }
                .onDisappear {
                    stopTimer()
                }
            }
        }
    }
    
    func startTimer() {
        guard adsForPlacement.count > 1 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            withAnimation {
                currentIndex = (currentIndex + 1) % adsForPlacement.count
            }
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}