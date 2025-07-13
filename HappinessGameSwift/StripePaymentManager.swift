import Foundation
import UIKit
import Combine

class StripePaymentManager: ObservableObject {
    static let shared = StripePaymentManager()
    
    // Stripe設定
    private let publishableKey = "pk_test_..." // 要変更: Stripeのpublishable key
    private let baseURL = "https://your-backend-url.com/api" // 要変更: バックエンドURL
    
    private init() {}
    
    // プラン投稿料金（1000円）を支払う
    func payForPlanPosting(userId: String, completion: @escaping (Result<PlanPostingPayment, Error>) -> Void) {
        let amount = 1000 // 1000円
        
        // PaymentIntentを作成するためのリクエスト
        let url = URL(string: "\(baseURL)/create-payment-intent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "amount": amount,
            "currency": "jpy",
            "userId": userId,
            "type": "plan_posting"
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
            
            // 支払い処理を実行（実際のアプリではStripe SDKを使用）
            DispatchQueue.main.async {
                self.processPayment(clientSecret: clientSecret) { result in
                    switch result {
                    case .success:
                        let payment = PlanPostingPayment(
                            id: UUID().uuidString,
                            userId: userId,
                            amount: amount,
                            paidAt: Date(),
                            stripePaymentIntentId: paymentIntentId,
                            status: "completed"
                        )
                        completion(.success(payment))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            }
        }.resume()
    }
    
    // プランを購入する
    func purchasePlan(userId: String, plan: VisitPlanModel, completion: @escaping (Result<PlanPurchase, Error>) -> Void) {
        let url = URL(string: "\(baseURL)/create-payment-intent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "amount": plan.price,
            "currency": "jpy",
            "userId": userId,
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
    
    // 支払い処理（実際のアプリではStripe SDKを使用）
    private func processPayment(clientSecret: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // 注意: 実際の実装では、Stripe iOS SDKを使用して支払いを処理します
        // ここでは簡略化のため、成功したと仮定
        
        // 実際の実装例:
        // STPPaymentHandler.shared().confirmPayment(withParams: paymentParams, authenticationContext: self) { status, paymentIntent, error in
        //     switch status {
        //     case .succeeded:
        //         completion(.success(()))
        //     case .failed:
        //         completion(.failure(error ?? NSError(...)))
        //     case .canceled:
        //         completion(.failure(NSError(...)))
        //     }
        // }
        
        // デモ用: 2秒後に成功を返す
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            completion(.success(()))
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
            "currency": "jpy",
            "userId": userId,
            "points": package.points,
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
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let clientSecret = json["clientSecret"] as? String else {
                completion(.failure(NSError(domain: "StripePaymentManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
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

// Stripeバックエンドとの通信用モデル
struct PaymentIntentResponse: Codable {
    let clientSecret: String
    let paymentIntentId: String
    let amount: Int
}