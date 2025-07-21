import Foundation
import UIKit
import Combine
import StripePaymentSheet

class StripePaymentManager: NSObject, ObservableObject {
    static let shared = StripePaymentManager()
    
    // Stripe設定
    private let publishableKey = "pk_live_51RjjWjD7PsaPGu6xz0RGH0Gnw36ORTqI9pjec4ycPMlxAQ8biO4igeEMwoKZxdwhB8EJGeW947jmgaCWNKZi3ZTR005t6UHTLA"
    private let baseURL = "https://server-demaddadf-ginnaka543s-projects.vercel.app/api" // バックエンドURL
    
    @Published var paymentSheet: PaymentSheet?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private var currentCompletion: ((Result<Void, Error>) -> Void)?
    
    private override init() {
        super.init()
    }
    
    // プランを購入する
    func purchasePlan(userId: String, plan: VisitPlanModel, completion: @escaping (Result<PlanPurchase, Error>) -> Void) {
        let url = URL(string: "\(baseURL)/create-payment-intent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "amount": plan.price,
            "userId": userId,
            "pointAmount": 0, // プラン購入は直接支払い
            "planId": plan.id,
            "planOwnerId": plan.userId,
            "type": "plan_purchase"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let clientSecret = json["clientSecret"] as? String,
                  let paymentIntentId = json["paymentIntentId"] as? String else {
                completion(.failure(NSError(domain: "StripePaymentManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            // 支払い処理を実行
            DispatchQueue.main.async {
                self.processPayment(clientSecret: clientSecret) { result in
                    switch result {
                    case .success:
                        let purchase = PlanPurchase(
                            id: UUID().uuidString,
                            userId: userId,
                            planId: plan.id,
                            planOwnerId: plan.userId,
                            purchasePrice: plan.price,
                            purchasedAt: Date(),
                            stripePaymentIntentId: paymentIntentId
                        )
                        completion(.success(purchase))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            }
        }.resume()
    }
    
    // 支払い処理（Stripe Payment Sheetを使用）
    private func processPayment(clientSecret: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // 保存する
        self.currentCompletion = completion
        
        // PaymentSheet設定
        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "アニレコ"
        configuration.applePay = PaymentSheet.ApplePayConfiguration(
            merchantId: "merchant.com.anireco", 
            merchantCountryCode: "JP"
        )
        configuration.allowsDelayedPaymentMethods = false
        
        // 日本の決済方法を有効化
        configuration.allowsPaymentMethodsRequiringShippingAddress = false
        configuration.defaultBillingDetails.address.country = "JP"
        
        // PaymentSheetを作成
        self.paymentSheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: configuration)
        
        print("📝 [StripePaymentManager] PaymentSheet準備完了")
        
        // ViewControllerが必要なので、現在のウィンドウから取得
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let viewController = window.rootViewController {
                
                self.presentPaymentSheet(from: viewController)
            } else {
                print("❌ [StripePaymentManager] ViewControllerが見つかりません")
                completion(.failure(NSError(domain: "StripePaymentManager", code: 1002, userInfo: [NSLocalizedDescriptionKey: "決済画面を表示できません"])))
            }
        }
    }
    
    // Payment Sheetを表示
    private func presentPaymentSheet(from viewController: UIViewController) {
        guard let paymentSheet = self.paymentSheet else {
            print("❌ [StripePaymentManager] PaymentSheetが初期化されていません")
            self.currentCompletion?(.failure(NSError(domain: "StripePaymentManager", code: 1003, userInfo: [NSLocalizedDescriptionKey: "PaymentSheetエラー"])))
            return
        }
        
        print("🎯 [StripePaymentManager] PaymentSheet表示")
        
        // 最前面のViewControllerを取得
        var topViewController = viewController
        while let presented = topViewController.presentedViewController {
            topViewController = presented
        }
        
        // 少し遅延させて、現在の画面遷移が完了するのを待つ
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            paymentSheet.present(from: topViewController) { paymentResult in
                switch paymentResult {
                case .completed:
                    print("✅ [StripePaymentManager] 決済成功")
                    self.currentCompletion?(.success(()))
                    
                case .canceled:
                    print("⚠️ [StripePaymentManager] 決済キャンセル")
                    self.currentCompletion?(.failure(NSError(domain: "StripePaymentManager", code: 1004, userInfo: [NSLocalizedDescriptionKey: "決済がキャンセルされました"])))
                    
                case .failed(let error):
                    print("❌ [StripePaymentManager] 決済エラー: \(error.localizedDescription)")
                    self.currentCompletion?(.failure(error))
                }
                
                // クリーンアップ
                self.paymentSheet = nil
                self.currentCompletion = nil
            }
        }
    }
    
    // ポイントを購入する
    func purchasePoints(userId: String, package: PointPackage, completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔥 [StripePaymentManager] purchasePoints開始: userId=\(userId), points=\(package.points), price=\(package.price)")
        
        let url = URL(string: "\(baseURL)/create-payment-intent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "amount": package.price,
            "userId": userId,
            "pointAmount": package.points,
            "type": "point_purchase"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [StripePaymentManager] ネットワークエラー: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("❌ [StripePaymentManager] データが空です")
                completion(.failure(NSError(domain: "StripePaymentManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            // レスポンスをログ出力
            if let responseString = String(data: data, encoding: .utf8) {
                print("📝 [StripePaymentManager] サーバーレスポンス: \(responseString)")
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let clientSecret = json["clientSecret"] as? String else {
                print("❌ [StripePaymentManager] JSONパースエラー")
                completion(.failure(NSError(domain: "StripePaymentManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                return
            }
            
            // 支払い処理を実行（実際のアプリではStripe SDKを使用）
            DispatchQueue.main.async {
                self.processPayment(clientSecret: clientSecret) { result in
                    switch result {
                    case .success:
                        print("✅ [StripePaymentManager] ポイント購入決済成功")
                        completion(.success(()))
                    case .failure(let error):
                        print("❌ [StripePaymentManager] ポイント購入決済エラー: \(error)")
                        completion(.failure(error))
                    }
                }
            }
        }.resume()
    }
}

