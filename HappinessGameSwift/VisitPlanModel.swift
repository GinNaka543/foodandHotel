import Foundation

// Firebase用のVisitPlanモデル
struct VisitPlanModel: Codable {
    let id: String
    let userId: String
    let animeName: String
    let title: String
    let description: String
    let duration: String
    let spots: [VisitSpot]
    let thumbnailUrl: String? // GitHub画像URL
    let price: Int // プラン価格（円）
    let budget: Int // プラン予算（円）
    let createdDate: Date
    let startTime: Date
    let numberOfDays: Int
    let totalCost: Int
    let isPublic: Bool
    let purchasedBy: [String] // 購入したユーザーIDリスト
    let createdAt: Date
    let updatedAt: Date
    
    // 標準的な初期化子
    init(id: String, userId: String, animeName: String, title: String, description: String,
         duration: String, spots: [VisitSpot], thumbnailUrl: String?, price: Int, budget: Int,
         createdDate: Date, startTime: Date, numberOfDays: Int, totalCost: Int,
         isPublic: Bool, purchasedBy: [String], createdAt: Date, updatedAt: Date) {
        self.id = id
        self.userId = userId
        self.animeName = animeName
        self.title = title
        self.description = description
        self.duration = duration
        self.spots = spots
        self.thumbnailUrl = thumbnailUrl
        self.price = price
        self.budget = budget
        self.createdDate = createdDate
        self.startTime = startTime
        self.numberOfDays = numberOfDays
        self.totalCost = totalCost
        self.isPublic = isPublic
        self.purchasedBy = purchasedBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Firebaseとの連携用
    var dictionary: [String: Any] {
        return [
            "id": id,
            "userId": userId,
            "animeName": animeName,
            "title": title,
            "description": description,
            "duration": duration,
            "spots": spots.map { spot in
                [
                    "id": spot.id.uuidString,
                    "name": spot.name,
                    "address": spot.address,
                    "notes": spot.notes,
                    "nearestStation": spot.nearestStation,
                    "stayDuration": spot.stayDuration,
                    "timeRange": spot.timeRange,
                    "activity": spot.activity,
                    "dayNumber": spot.dayNumber,
                    "spotCost": spot.spotCost,
                    "imageUrl": spot.imageData != nil ? "image_\(spot.id.uuidString)" : nil,
                    "transportToNext": spot.transportToNext != nil ? [
                        "method": spot.transportToNext!.method,
                        "duration": spot.transportToNext!.duration,
                        "cost": spot.transportToNext!.cost,
                        "route": spot.transportToNext!.route
                    ] : nil
                ]
            },
            "thumbnailUrl": thumbnailUrl ?? "",
            "price": price,
            "budget": budget,
            "startTime": startTime.timeIntervalSince1970,
            "numberOfDays": numberOfDays,
            "totalCost": totalCost,
            "isPublic": isPublic,
            "purchasedBy": purchasedBy,
            "createdAt": createdAt.timeIntervalSince1970,
            "updatedAt": updatedAt.timeIntervalSince1970
        ]
    }
    
    // Firebaseからの初期化
    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let userId = dictionary["userId"] as? String,
              let animeName = dictionary["animeName"] as? String,
              let title = dictionary["title"] as? String,
              let description = dictionary["description"] as? String,
              let duration = dictionary["duration"] as? String,
              let price = dictionary["price"] as? Int,
              let numberOfDays = dictionary["numberOfDays"] as? Int,
              let totalCost = dictionary["totalCost"] as? Int,
              let isPublic = dictionary["isPublic"] as? Bool,
              let purchasedBy = dictionary["purchasedBy"] as? [String],
              let createdAtTimestamp = dictionary["createdAt"] as? Double,
              let updatedAtTimestamp = dictionary["updatedAt"] as? Double,
              let startTimeTimestamp = dictionary["startTime"] as? Double,
              let spotsData = dictionary["spots"] as? [[String: Any]] else {
            return nil
        }
        
        self.id = id
        self.userId = userId
        self.animeName = animeName
        self.title = title
        self.description = description
        self.duration = duration
        self.thumbnailUrl = dictionary["thumbnailUrl"] as? String
        self.price = price
        self.budget = dictionary["budget"] as? Int ?? 0
        self.startTime = Date(timeIntervalSince1970: startTimeTimestamp)
        self.numberOfDays = numberOfDays
        self.totalCost = totalCost
        self.isPublic = isPublic
        self.purchasedBy = purchasedBy
        self.createdAt = Date(timeIntervalSince1970: createdAtTimestamp)
        self.updatedAt = Date(timeIntervalSince1970: updatedAtTimestamp)
        self.createdDate = self.createdAt
        
        // Spotsの変換
        self.spots = spotsData.compactMap { spotDict in
            guard let idString = spotDict["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let name = spotDict["name"] as? String else {
                return nil
            }
            
            var transportInfo: TransportInfo?
            if let transportDict = spotDict["transportToNext"] as? [String: Any],
               let method = transportDict["method"] as? String,
               let duration = transportDict["duration"] as? Int,
               let cost = transportDict["cost"] as? Int,
               let route = transportDict["route"] as? String {
                transportInfo = TransportInfo(method: method, duration: duration, cost: cost, route: route)
            }
            
            return VisitSpot(
                id: id,
                name: name,
                address: spotDict["address"] as? String ?? "",
                notes: spotDict["notes"] as? String ?? "",
                nearestStation: spotDict["nearestStation"] as? String ?? "",
                stayDuration: spotDict["stayDuration"] as? Int ?? 60,
                transportToNext: transportInfo,
                timeRange: spotDict["timeRange"] as? String ?? "",
                activity: spotDict["activity"] as? String ?? "",
                dayNumber: spotDict["dayNumber"] as? Int ?? 1,
                spotCost: spotDict["spotCost"] as? Int ?? 0
            )
        }
    }
}

// 購入記録モデル
struct PlanPurchase: Codable {
    let id: String
    let userId: String
    let planId: String
    let planOwnerId: String
    let purchasePrice: Int
    let purchasedAt: Date
    let stripePaymentIntentId: String?
    
    var dictionary: [String: Any] {
        return [
            "id": id,
            "userId": userId,
            "planId": planId,
            "planOwnerId": planOwnerId,
            "purchasePrice": purchasePrice,
            "purchasedAt": purchasedAt.timeIntervalSince1970,
            "stripePaymentIntentId": stripePaymentIntentId ?? ""
        ]
    }
}

// プラン投稿料金モデル
struct PlanPostingPayment: Codable {
    let id: String
    let userId: String
    let amount: Int // 1000円
    let paidAt: Date
    let stripePaymentIntentId: String?
    let status: String // "pending", "completed", "failed"
    
    var dictionary: [String: Any] {
        return [
            "id": id,
            "userId": userId,
            "amount": amount,
            "paidAt": paidAt.timeIntervalSince1970,
            "stripePaymentIntentId": stripePaymentIntentId ?? "",
            "status": status
        ]
    }
}