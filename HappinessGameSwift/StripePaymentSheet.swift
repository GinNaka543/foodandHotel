import SwiftUI
import StripePaymentSheet

// SwiftUIでPaymentSheetを表示するためのViewModifier
struct StripePaymentSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    let clientSecret: String
    let completion: (PaymentSheetResult) -> Void
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if isPresented {
                    presentPaymentSheet()
                }
            }
            .onChange(of: isPresented) { newValue in
                if newValue {
                    presentPaymentSheet()
                }
            }
    }
    
    private func presentPaymentSheet() {
        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "アニコレ"
        configuration.allowsDelayedPaymentMethods = false
        configuration.defaultBillingDetails.address.country = "JP"
        
        let paymentSheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: configuration)
        
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                // 最前面のViewControllerを取得
                var topViewController = rootViewController
                while let presented = topViewController.presentedViewController {
                    topViewController = presented
                }
                
                paymentSheet.present(from: topViewController) { paymentResult in
                    isPresented = false
                    completion(paymentResult)
                }
            }
        }
    }
}

// 使いやすくするためのView拡張
extension View {
    func stripePaymentSheet(isPresented: Binding<Bool>, clientSecret: String, completion: @escaping (PaymentSheetResult) -> Void) -> some View {
        self.modifier(StripePaymentSheetModifier(isPresented: isPresented, clientSecret: clientSecret, completion: completion))
    }
}