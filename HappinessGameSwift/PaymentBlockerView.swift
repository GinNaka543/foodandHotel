import SwiftUI

struct PaymentBlockerView: View {
    @StateObject private var gatekeeper = PaymentGatekeeper.shared
    @State private var showingPurchase = false
    
    var body: some View {
        ZStack {
            // 背景
            LinearGradient(
                gradient: Gradient(colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // アイコン
                Image(systemName: "lock.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .shadow(radius: 10)
                
                // メッセージ
                VStack(spacing: 16) {
                    Text(NSLocalizedString("free_trial_ended", comment: ""))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("アプリの利用を続けるには\nプレミアムプランへのアップグレードが必要です")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                // 価格
                VStack(spacing: 8) {
                    Text("¥600")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(NSLocalizedString("permanent_license", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.vertical, 20)
                
                // 購入ボタン
                Button(action: {
                    showingPurchase = true
                }) {
                    HStack {
                        Image(systemName: "crown.fill")
                        Text(NSLocalizedString("purchase", comment: ""))
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.purple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.white)
                    .cornerRadius(15)
                    .shadow(radius: 10)
                }
                .padding(.horizontal, 40)
                
                #if DEBUG
                // デバッグボタン
                VStack(spacing: 10) {
                    Text("Debug Options")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    
                    HStack(spacing: 20) {
                        Button("Reset Trial") {
                            gatekeeper.resetTrialPeriod()
                        }
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        
                        Button("Mark Premium") {
                            gatekeeper.markAsPremium()
                        }
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.top, 40)
                #endif
            }
            .padding()
        }
        .fullScreenCover(isPresented: $showingPurchase) {
            PremiumUpgradeView(showPaymentRequired: $showingPurchase)
        }
    }
}

#Preview {
    PaymentBlockerView()
}