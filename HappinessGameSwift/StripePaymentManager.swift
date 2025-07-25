import Foundation
import UIKit
import Combine
import StripePaymentSheet

class StripePaymentManager: NSObject, ObservableObject {
    static let shared = StripePaymentManager()
    
    // Stripe設定
    private let publishableKey: String = {
        // Read Stripe publishable key from Info.plist
        guard let infoDict = Bundle.main.infoDictionary,
              let key = infoDict["STRIPE_PUBLISHABLE_KEY"] as? String,
              !key.isEmpty else {
            fatalError("STRIPE_PUBLISHABLE_KEY not found in Info.plist")
        }
        return key
    }()
    private let baseURL = "https://happiness-game.onrender.com/api" // バックエンドURL
    
    @Published var paymentSheet: PaymentSheet?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private var currentCompletion: ((Result<Void, Error>) -> Void)?
    
    private override init() {
        super.init()
    }
    
    // リトライ付きのネットワークリクエスト実行
    private func performRequestWithRetry(session: URLSession, request: URLRequest, retryCount: Int, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        session.dataTask(with: request) { data, response, error in
            // サーバーが起動中の可能性がある場合はリトライ
            if let error = error as? NSError,
               retryCount < 2,  // 最大2回リトライ
               (error.code == NSURLErrorTimedOut || error.code == NSURLErrorCannotConnectToHost) {
                
                DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) { // 3秒待ってリトライ
                    self.performRequestWithRetry(session: session, request: request, retryCount: retryCount + 1, completion: completion)
                }
                return
            }
            
            completion(data, response, error)
        }.resume()
    }
    
    // プランを購入する
    func purchasePlan(userId: String, plan: VisitPlanModel, completion: @escaping (Result<PlanPurchase, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/create-payment-intent") else {
            completion(.failure(NSError(domain: "StripePaymentManager", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
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
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60.0 // 60秒のタイムアウト（Renderの起動時間を考慮）
        configuration.timeoutIntervalForResource = 60.0
        
        let session = URLSession(configuration: configuration)
        
        performRequestWithRetry(session: session, request: request, retryCount: 0) { data, response, error in
            if let error = error {
                let nsError = error as NSError
                if nsError.code == NSURLErrorTimedOut {
                    completion(.failure(NSError(domain: "StripePaymentManager", code: 1005, userInfo: [NSLocalizedDescriptionKey: "リクエストがタイムアウトしました。もう一度お試しください。"])))
                } else if nsError.code == NSURLErrorNotConnectedToInternet {
                    completion(.failure(NSError(domain: "StripePaymentManager", code: 1006, userInfo: [NSLocalizedDescriptionKey: "インターネット接続を確認してください。"])))
                } else {
                    completion(.failure(error))
                }
                return
            }
            
            // HTTPステータスコードをチェック
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 500 {
                    completion(.failure(NSError(domain: "StripePaymentManager", code: 1007, userInfo: [NSLocalizedDescriptionKey: "サーバーエラーが発生しました。しばらく待ってからもう一度お試しください。"])))
                    return
                }
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
        }
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
        
        
        // ViewControllerが必要なので、現在のウィンドウから取得
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let viewController = window.rootViewController {
                
                self.presentPaymentSheet(from: viewController)
            } else {
                completion(.failure(NSError(domain: "StripePaymentManager", code: 1002, userInfo: [NSLocalizedDescriptionKey: "決済画面を表示できません"])))
            }
        }
    }
    
    // Payment Sheetを表示
    private func presentPaymentSheet(from viewController: UIViewController) {
        guard let paymentSheet = self.paymentSheet else {
            self.currentCompletion?(.failure(NSError(domain: "StripePaymentManager", code: 1003, userInfo: [NSLocalizedDescriptionKey: "PaymentSheetエラー"])))
            return
        }
        
        
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
                    self.currentCompletion?(.success(()))
                    
                case .canceled:
                    self.currentCompletion?(.failure(NSError(domain: "StripePaymentManager", code: 1004, userInfo: [NSLocalizedDescriptionKey: "決済がキャンセルされました"])))
                    
                case .failed(let error):
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
        
        guard let url = URL(string: "\(baseURL)/create-payment-intent") else {
            completion(.failure(NSError(domain: "StripePaymentManager", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
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
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60.0 // 60秒のタイムアウト（Renderの起動時間を考慮）
        configuration.timeoutIntervalForResource = 60.0
        
        let session = URLSession(configuration: configuration)
        
        performRequestWithRetry(session: session, request: request, retryCount: 0) { data, response, error in
            if let error = error {
                let nsError = error as NSError
                if nsError.code == NSURLErrorTimedOut {
                    completion(.failure(NSError(domain: "StripePaymentManager", code: 1005, userInfo: [NSLocalizedDescriptionKey: "リクエストがタイムアウトしました。もう一度お試しください。"])))
                } else if nsError.code == NSURLErrorNotConnectedToInternet {
                    completion(.failure(NSError(domain: "StripePaymentManager", code: 1006, userInfo: [NSLocalizedDescriptionKey: "インターネット接続を確認してください。"])))
                } else {
                    completion(.failure(error))
                }
                return
            }
            
            // HTTPステータスコードをチェック
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 500 {
                    completion(.failure(NSError(domain: "StripePaymentManager", code: 1007, userInfo: [NSLocalizedDescriptionKey: "サーバーエラーが発生しました。しばらく待ってからもう一度お試しください。"])))
                    return
                }
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "StripePaymentManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            // レスポンスをログ出力
            if let responseString = String(data: data, encoding: .utf8) {
                print("Stripe API Response: \(responseString)")
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let clientSecret = json["clientSecret"] as? String else {
                // エラーレスポンスの詳細を取得
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = json["error"] as? String {
                    completion(.failure(NSError(domain: "StripePaymentManager", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                } else {
                    completion(.failure(NSError(domain: "StripePaymentManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                }
                return
            }
            
            // 支払い処理を実行（実際のアプリではStripe SDKを使用）
            DispatchQueue.main.async {
                self.processPayment(clientSecret: clientSecret) { result in
                    switch result {
                    case .success:
                        completion(.success(()))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            }
        }
    }
}

