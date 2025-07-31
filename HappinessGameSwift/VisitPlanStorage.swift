import Foundation
import UIKit

// Helper class to manage visit plan storage
// Stores plan metadata in UserDefaults and images in files
class VisitPlanStorage {
    static let shared = VisitPlanStorage()
    
    private init() {}
    
    // MARK: - Directory Management
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private var visitPlansDirectory: URL {
        documentsDirectory.appendingPathComponent("VisitPlans")
    }
    
    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(at: visitPlansDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Image Storage
    
    private func imageURL(for planId: String, spotId: String, imageType: String = "main") -> URL {
        visitPlansDirectory
            .appendingPathComponent(planId)
            .appendingPathComponent("\(spotId)_\(imageType).jpg")
    }
    
    private func saveImage(_ imageData: Data, planId: String, spotId: String, imageType: String = "main") throws {
        ensureDirectoryExists()
        
        let planDirectory = visitPlansDirectory.appendingPathComponent(planId)
        try? FileManager.default.createDirectory(at: planDirectory, withIntermediateDirectories: true)
        
        let imageURL = self.imageURL(for: planId, spotId: spotId, imageType: imageType)
        try imageData.write(to: imageURL)
    }
    
    private func loadImage(planId: String, spotId: String, imageType: String = "main") -> Data? {
        let imageURL = self.imageURL(for: planId, spotId: spotId, imageType: imageType)
        return try? Data(contentsOf: imageURL)
    }
    
    private func deleteImages(planId: String, spotId: String) {
        let planDirectory = visitPlansDirectory.appendingPathComponent(planId)
        let fileManager = FileManager.default
        
        // Delete main image
        let mainImageURL = imageURL(for: planId, spotId: spotId, imageType: "main")
        try? fileManager.removeItem(at: mainImageURL)
        
        // Delete detail images
        if let files = try? fileManager.contentsOfDirectory(at: planDirectory, includingPropertiesForKeys: nil) {
            for file in files where file.lastPathComponent.hasPrefix("\(spotId)_detail_") {
                try? fileManager.removeItem(at: file)
            }
        }
    }
    
    // MARK: - Plan Storage
    
    func savePlan(planId: String, planTitle: String, spots: [VisitSpot], planThumbnailData: Data? = nil) {
        let planKey = "visit_plan_\(planId)"
        
        // Convert spots to dictionary format without image data
        let spotsData = spots.map { spot -> [String: Any] in
            var spotDict: [String: Any] = [
                "id": spot.id.uuidString,
                "name": spot.name,
                "address": spot.address,
                "notes": spot.notes,
                "nearestStation": spot.nearestStation,
                "stayDuration": spot.stayDuration,
                "isCompleted": spot.isCompleted,
                "timeRange": spot.timeRange,
                "activity": spot.activity,
                "dayNumber": spot.dayNumber,
                "spotCost": spot.spotCost,
                "imageUrl": spot.imageUrl,
                "images": spot.images
            ]
            
            // Save dates
            if let arrivalTime = spot.arrivalTime {
                spotDict["arrivalTime"] = arrivalTime.timeIntervalSince1970
            }
            if let departureTime = spot.departureTime {
                spotDict["departureTime"] = departureTime.timeIntervalSince1970
            }
            
            // Save transport info
            if let transport = spot.transportToNext {
                spotDict["transportToNext"] = [
                    "method": transport.method,
                    "duration": transport.duration,
                    "cost": transport.cost,
                    "route": transport.route
                ]
            }
            
            // Save images to files
            if let imageData = spot.imageData {
                try? saveImage(imageData, planId: planId, spotId: spot.id.uuidString)
                spotDict["hasMainImage"] = true
            }
            
            // Save detail images
            if let detailImages = spot.detailImagesData {
                for (index, imageData) in detailImages.enumerated() {
                    try? saveImage(imageData, planId: planId, spotId: spot.id.uuidString, imageType: "detail_\(index)")
                }
                spotDict["detailImageCount"] = detailImages.count
            }
            
            return spotDict
        }
        
        // Save plan thumbnail if provided
        if let thumbnailData = planThumbnailData {
            ensureDirectoryExists()
            let planDirectory = visitPlansDirectory.appendingPathComponent(planId)
            try? FileManager.default.createDirectory(at: planDirectory, withIntermediateDirectories: true)
            
            let thumbnailURL = planDirectory.appendingPathComponent("plan_thumbnail.jpg")
            do {
                try thumbnailData.write(to: thumbnailURL)
                print("[VisitPlanStorage] Successfully saved plan thumbnail for \(planId), size: \(thumbnailData.count) bytes at \(thumbnailURL.path)")
            } catch {
                print("[VisitPlanStorage] Failed to save plan thumbnail: \(error)")
            }
        } else {
            print("[VisitPlanStorage] No thumbnail data provided for plan \(planId)")
        }
        
        // Save plan data without images
        let planData: [String: Any] = [
            "spots": spotsData,
            "lastModified": Date().timeIntervalSince1970,
            "hasPlanThumbnail": planThumbnailData != nil
        ]
        
        UserDefaults.standard.set(planData, forKey: planKey)
    }
    
    func loadPlan(planId: String) -> [VisitSpot]? {
        let planKey = "visit_plan_\(planId)"
        
        guard let planData = UserDefaults.standard.dictionary(forKey: planKey),
              let spotsData = planData["spots"] as? [[String: Any]] else {
            return nil
        }
        
        var restoredSpots: [VisitSpot] = []
        
        for spotData in spotsData {
            guard let idString = spotData["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let name = spotData["name"] as? String else { continue }
            
            var spot = VisitSpot(
                id: id,
                name: name,
                address: spotData["address"] as? String ?? "",
                notes: spotData["notes"] as? String ?? "",
                nearestStation: spotData["nearestStation"] as? String ?? "",
                stayDuration: spotData["stayDuration"] as? Int ?? 60,
                isCompleted: spotData["isCompleted"] as? Bool ?? false,
                timeRange: spotData["timeRange"] as? String ?? "",
                activity: spotData["activity"] as? String ?? "",
                dayNumber: spotData["dayNumber"] as? Int ?? 1,
                spotCost: spotData["spotCost"] as? Int ?? 0,
                imageUrl: spotData["imageUrl"] as? String ?? "",
                images: spotData["images"] as? [String] ?? []
            )
            
            // Restore dates
            if let arrivalInterval = spotData["arrivalTime"] as? Double {
                spot.arrivalTime = Date(timeIntervalSince1970: arrivalInterval)
            }
            if let departureInterval = spotData["departureTime"] as? Double {
                spot.departureTime = Date(timeIntervalSince1970: departureInterval)
            }
            
            // Restore transport info
            if let transportData = spotData["transportToNext"] as? [String: Any],
               let method = transportData["method"] as? String,
               let duration = transportData["duration"] as? Int,
               let cost = transportData["cost"] as? Int,
               let route = transportData["route"] as? String {
                spot.transportToNext = TransportInfo(
                    method: method,
                    duration: duration,
                    cost: cost,
                    route: route
                )
            }
            
            // Load images from files
            if spotData["hasMainImage"] as? Bool == true {
                spot.imageData = loadImage(planId: planId, spotId: idString)
            }
            
            // Load detail images
            if let detailImageCount = spotData["detailImageCount"] as? Int {
                var detailImages: [Data] = []
                for index in 0..<detailImageCount {
                    if let imageData = loadImage(planId: planId, spotId: idString, imageType: "detail_\(index)") {
                        detailImages.append(imageData)
                    }
                }
                if !detailImages.isEmpty {
                    spot.detailImagesData = detailImages
                }
            }
            
            restoredSpots.append(spot)
        }
        
        return restoredSpots.isEmpty ? nil : restoredSpots
    }
    
    func deletePlan(planId: String) {
        let planKey = "visit_plan_\(planId)"
        
        // Delete from UserDefaults
        UserDefaults.standard.removeObject(forKey: planKey)
        
        // Delete image directory
        let planDirectory = visitPlansDirectory.appendingPathComponent(planId)
        try? FileManager.default.removeItem(at: planDirectory)
    }
    
    // MARK: - Plan Thumbnail
    
    func loadPlanThumbnail(planId: String) -> Data? {
        let thumbnailURL = visitPlansDirectory.appendingPathComponent(planId).appendingPathComponent("plan_thumbnail.jpg")
        return try? Data(contentsOf: thumbnailURL)
    }
    
    // MARK: - Migration
    
    func migrateExistingPlans() {
        // Find all visit plan keys in UserDefaults
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let visitPlanKeys = allKeys.filter { $0.hasPrefix("visit_plan_") }
        
        for planKey in visitPlanKeys {
            guard let planData = userDefaults.dictionary(forKey: planKey),
                  let spotsData = planData["spots"] as? [[String: Any]] else {
                continue
            }
            
            // Extract plan ID from key
            let planId = planKey.replacingOccurrences(of: "visit_plan_", with: "")
            var needsMigration = false
            
            // Check if any spot has Base64 image data
            for spotData in spotsData {
                if spotData["imageDataBase64"] != nil {
                    needsMigration = true
                    break
                }
            }
            
            if needsMigration {
                // Load spots with Base64 data
                var migratedSpots: [VisitSpot] = []
                
                for spotData in spotsData {
                    guard let idString = spotData["id"] as? String,
                          let id = UUID(uuidString: idString),
                          let name = spotData["name"] as? String else { continue }
                    
                    var spot = VisitSpot(
                        id: id,
                        name: name,
                        address: spotData["address"] as? String ?? "",
                        notes: spotData["notes"] as? String ?? "",
                        nearestStation: spotData["nearestStation"] as? String ?? "",
                        stayDuration: spotData["stayDuration"] as? Int ?? 60,
                        isCompleted: spotData["isCompleted"] as? Bool ?? false,
                        timeRange: spotData["timeRange"] as? String ?? "",
                        activity: spotData["activity"] as? String ?? "",
                        dayNumber: spotData["dayNumber"] as? Int ?? 1,
                        spotCost: spotData["spotCost"] as? Int ?? 0,
                        imageUrl: spotData["imageUrl"] as? String ?? "",
                        images: spotData["images"] as? [String] ?? []
                    )
                    
                    // Restore dates
                    if let arrivalInterval = spotData["arrivalTime"] as? Double {
                        spot.arrivalTime = Date(timeIntervalSince1970: arrivalInterval)
                    }
                    if let departureInterval = spotData["departureTime"] as? Double {
                        spot.departureTime = Date(timeIntervalSince1970: departureInterval)
                    }
                    
                    // Restore transport info
                    if let transportData = spotData["transportToNext"] as? [String: Any],
                       let method = transportData["method"] as? String,
                       let duration = transportData["duration"] as? Int,
                       let cost = transportData["cost"] as? Int,
                       let route = transportData["route"] as? String {
                        spot.transportToNext = TransportInfo(
                            method: method,
                            duration: duration,
                            cost: cost,
                            route: route
                        )
                    }
                    
                    // Migrate Base64 image data
                    if let imageDataBase64 = spotData["imageDataBase64"] as? String,
                       let imageData = Data(base64Encoded: imageDataBase64) {
                        spot.imageData = imageData
                    }
                    
                    migratedSpots.append(spot)
                }
                
                // Save using new method
                if !migratedSpots.isEmpty {
                    savePlan(planId: planId, planTitle: planId, spots: migratedSpots)
                }
            }
        }
    }
}