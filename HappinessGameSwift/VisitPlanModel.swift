import Foundation

// Firebase用のVisitPlanモデル
struct VisitPlanModel: Codable, Identifiable {
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
    let isDraft: Bool // 下書きかどうか
    let isConfirmed: Bool? // 確定済みかどうか
    let streamingUrls: [StreamingService] // ストリーミングサービスURL
    let language: String? // プランの言語 (ja, en, ko, zh, de, fr, es, it, pt)
    
    // 標準的な初期化子
    init(id: String, userId: String, animeName: String, title: String, description: String,
         duration: String, spots: [VisitSpot], thumbnailUrl: String?, price: Int, budget: Int,
         createdDate: Date, startTime: Date, numberOfDays: Int, totalCost: Int,
         isPublic: Bool, purchasedBy: [String], createdAt: Date, updatedAt: Date, isDraft: Bool = false, isConfirmed: Bool? = nil, streamingUrls: [StreamingService] = [], language: String? = nil) {
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
        self.isDraft = isDraft
        self.isConfirmed = isConfirmed
        self.streamingUrls = streamingUrls
        self.language = language
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
                    "imageUrl": !spot.imageUrl.isEmpty ? spot.imageUrl : (spot.imageData != nil ? "image_\(spot.id.uuidString)" : nil),
                    "images": spot.images,
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
            "updatedAt": updatedAt.timeIntervalSince1970,
            "isDraft": isDraft,
            "isConfirmed": isConfirmed ?? false,
            "streamingUrls": streamingUrls.map { service in
                [
                    "name": service.name,
                    "url": service.url,
                    "icon": service.icon ?? ""
                ]
            },
            "language": language ?? ""
        ]
    }
    
    // Firebaseからの初期化
    init?(dictionary: [String: Any]) {
        // デバッグ情報を追加
        
        guard let id = dictionary["id"] as? String else {
            return nil
        }
        
        guard let userId = dictionary["userId"] as? String else {
            return nil
        }
        
        guard let animeName = dictionary["animeName"] as? String else {
            return nil
        }
        
        guard let title = dictionary["title"] as? String else {
            return nil
        }
        
        guard let description = dictionary["description"] as? String else {
            return nil
        }
        
        guard let duration = dictionary["duration"] as? String else {
            return nil
        }
        
        // price を柔軟に変換
        let price: Int
        if let intPrice = dictionary["price"] as? Int {
            price = intPrice
        } else if let stringPrice = dictionary["price"] as? String, let convertedPrice = Int(stringPrice) {
            price = convertedPrice
        } else {
            return nil
        }
        
        // numberOfDays を柔軟に変換
        let numberOfDays: Int
        if let intDays = dictionary["numberOfDays"] as? Int {
            numberOfDays = intDays
        } else if let stringDays = dictionary["numberOfDays"] as? String, let convertedDays = Int(stringDays) {
            numberOfDays = convertedDays
        } else {
            return nil
        }
        
        // totalCost を柔軟に変換
        let totalCost: Int
        if let intCost = dictionary["totalCost"] as? Int {
            totalCost = intCost
        } else if let stringCost = dictionary["totalCost"] as? String, let convertedCost = Int(stringCost) {
            totalCost = convertedCost
        } else {
            return nil
        }
        
        guard let isPublicValue = dictionary["isPublic"] else {
            return nil
        }
        
        guard let purchasedBy = dictionary["purchasedBy"] as? [String] else {
            return nil
        }
        
        guard let createdAtTimestamp = dictionary["createdAt"] as? Double else {
            return nil
        }
        
        guard let updatedAtTimestamp = dictionary["updatedAt"] as? Double else {
            return nil
        }
        
        guard let startTimeTimestamp = dictionary["startTime"] as? Double else {
            return nil
        }
        
        guard let spotsData = dictionary["spots"] as? [[String: Any]] else {
            if let spotsArray = dictionary["spots"] as? [Any] {
            }
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
        // budget を柔軟に変換
        if let intBudget = dictionary["budget"] as? Int {
            self.budget = intBudget
        } else if let stringBudget = dictionary["budget"] as? String, let convertedBudget = Int(stringBudget) {
            self.budget = convertedBudget
        } else {
            self.budget = 0
        }
        self.startTime = Date(timeIntervalSince1970: startTimeTimestamp)
        self.numberOfDays = numberOfDays
        self.totalCost = totalCost
        // isPublicの値を適切に変換（数値の場合も考慮）
        if let boolValue = isPublicValue as? Bool {
            self.isPublic = boolValue
        } else if let intValue = isPublicValue as? Int {
            self.isPublic = intValue != 0
        } else if let stringValue = isPublicValue as? String {
            self.isPublic = stringValue.lowercased() == "true"
        } else {
            self.isPublic = false
        }
        self.purchasedBy = purchasedBy
        self.createdAt = Date(timeIntervalSince1970: createdAtTimestamp)
        self.updatedAt = Date(timeIntervalSince1970: updatedAtTimestamp)
        self.createdDate = self.createdAt
        self.isDraft = dictionary["isDraft"] as? Bool ?? false
        self.isConfirmed = dictionary["isConfirmed"] as? Bool
        
        // Streaming URLsの変換
        if let streamingUrlsData = dictionary["streamingUrls"] as? [[String: Any]] {
            self.streamingUrls = streamingUrlsData.compactMap { serviceDict in
                guard let name = serviceDict["name"] as? String,
                      let url = serviceDict["url"] as? String else {
                    return nil
                }
                return StreamingService(name: name, url: url, icon: serviceDict["icon"] as? String)
            }
        } else {
            self.streamingUrls = []
        }
        
        // 言語フィールドの初期化
        self.language = dictionary["language"] as? String
        
        // Spotsの変換
        self.spots = spotsData.compactMap { spotDict in
            
            // より柔軟な変換を試す
            let idString = spotDict["id"] as? String ?? UUID().uuidString
            let name = spotDict["name"] as? String ?? ""
            
            if name.isEmpty {
                return nil
            }
            
            
            guard !name.isEmpty else {
                return nil
            }
            
            // UUIDでない場合は新しいUUIDを生成
            let id = UUID(uuidString: idString) ?? UUID()
            
            var transportInfo: TransportInfo?
            if let transportDict = spotDict["transportToNext"] as? [String: Any],
               let method = transportDict["method"] as? String,
               let duration = transportDict["duration"] as? Int,
               let cost = transportDict["cost"] as? Int,
               let route = transportDict["route"] as? String {
                transportInfo = TransportInfo(method: method, duration: duration, cost: cost, route: route)
            }
            
            // stayDurationの柔軟な変換
            let stayDuration: Int
            if let intDuration = spotDict["stayDuration"] as? Int {
                stayDuration = intDuration
            } else if let stringDuration = spotDict["stayDuration"] as? String, let convertedDuration = Int(stringDuration) {
                stayDuration = convertedDuration
            } else {
                stayDuration = 60
            }
            
            // dayNumberの柔軟な変換
            let dayNumber: Int
            if let intDayNumber = spotDict["dayNumber"] as? Int {
                dayNumber = intDayNumber
            } else if let stringDayNumber = spotDict["dayNumber"] as? String, let convertedDayNumber = Int(stringDayNumber) {
                dayNumber = convertedDayNumber
            } else {
                dayNumber = 1
            }
            
            // spotCostの柔軟な変換
            let spotCost: Int
            if let intCost = spotDict["spotCost"] as? Int {
                spotCost = intCost
            } else if let stringCost = spotDict["spotCost"] as? String, let convertedCost = Int(stringCost) {
                spotCost = convertedCost
            } else {
                spotCost = 0
            }
            
            let imageUrl = spotDict["imageUrl"] as? String ?? ""
            let images = spotDict["images"] as? [String] ?? []
            
            let visitSpot = VisitSpot(
                id: id,
                name: name,
                address: spotDict["address"] as? String ?? "",
                notes: spotDict["notes"] as? String ?? "",
                nearestStation: spotDict["nearestStation"] as? String ?? "",
                stayDuration: stayDuration,
                transportToNext: transportInfo,
                timeRange: spotDict["timeRange"] as? String ?? "",
                activity: spotDict["activity"] as? String ?? "",
                dayNumber: dayNumber,
                spotCost: spotCost,
                imageUrl: imageUrl,
                images: images
            )
            return visitSpot
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