import Foundation

// Helper class to manage complete visit plan data storage
// Stores plan metadata in UserDefaults and images/thumbnails in files
class VisitPlanDataStorage {
    static let shared = VisitPlanDataStorage()
    
    private init() {}
    
    // MARK: - Directory Management
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private var visitPlansDirectory: URL {
        documentsDirectory.appendingPathComponent("VisitPlanData")
    }
    
    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(at: visitPlansDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - File Management
    
    private func planDirectory(for planId: String) -> URL {
        visitPlansDirectory.appendingPathComponent(planId)
    }
    
    private func planThumbnailURL(for planId: String) -> URL {
        planDirectory(for: planId).appendingPathComponent("plan_thumbnail.jpg")
    }
    
    // MARK: - Save and Load Functions
    
    func savePlanData(_ plan: VisitPlanData) {
        ensureDirectoryExists()
        let planId = plan.id.uuidString
        
        // Create plan directory
        let planDir = planDirectory(for: planId)
        try? FileManager.default.createDirectory(at: planDir, withIntermediateDirectories: true)
        
        // Save plan thumbnail
        if let thumbnailData = plan.thumbnailData {
            let thumbnailURL = planThumbnailURL(for: planId)
            try? thumbnailData.write(to: thumbnailURL)
        }
        
        // Save spots using existing VisitPlanStorage
        VisitPlanStorage.shared.savePlan(
            planId: planId,
            planTitle: plan.title,
            spots: plan.spots,
            planThumbnailData: plan.thumbnailData
        )
        
        // Create plan metadata without thumbnail data
        var planDict: [String: Any] = [
            "id": planId,
            "animeName": plan.animeName,
            "title": plan.title,
            "duration": plan.duration,
            "createdDate": plan.createdDate.timeIntervalSince1970,
            "startTime": plan.startTime.timeIntervalSince1970,
            "totalCost": plan.totalCost,
            "numberOfDays": plan.numberOfDays,
            "isPurchased": plan.isPurchased,
            "isDraft": plan.isDraft,
            "streamingUrls": plan.streamingUrls.map { ["service": $0.service, "url": $0.url] },
            "hasThumbnail": plan.thumbnailData != nil
        ]
        
        if let thumbnailUrl = plan.thumbnailUrl {
            planDict["thumbnailUrl"] = thumbnailUrl
        }
        
        if let lastVisitedDate = plan.lastVisitedDate {
            planDict["lastVisitedDate"] = lastVisitedDate.timeIntervalSince1970
        }
        
        // Save to appropriate storage based on plan type
        if plan.isDraft {
            // Save draft plans separately
            var drafts = loadAllDraftPlansMetadata()
            drafts[planId] = planDict
            saveDraftPlansMetadata(drafts)
        } else {
            // Save regular plans
            var plans = loadAllSavedPlansMetadata()
            plans[planId] = planDict
            saveSavedPlansMetadata(plans)
        }
    }
    
    func loadPlanData(planId: String, isDraft: Bool = false) -> VisitPlanData? {
        // Load metadata
        let metadata: [String: Any]
        if isDraft {
            let drafts = loadAllDraftPlansMetadata()
            guard let draft = drafts[planId] else { return nil }
            metadata = draft
        } else {
            let plans = loadAllSavedPlansMetadata()
            guard let plan = plans[planId] else { return nil }
            metadata = plan
        }
        
        // Load spots
        let spots = VisitPlanStorage.shared.loadPlan(planId: planId) ?? []
        
        // Create plan data
        var planData = VisitPlanData(
            id: UUID(uuidString: planId) ?? UUID(),
            animeName: metadata["animeName"] as? String ?? "",
            title: metadata["title"] as? String ?? "",
            duration: metadata["duration"] as? String ?? "",
            spots: spots,
            thumbnailData: nil,
            thumbnailUrl: metadata["thumbnailUrl"] as? String,
            createdDate: Date(timeIntervalSince1970: metadata["createdDate"] as? TimeInterval ?? 0),
            startTime: Date(timeIntervalSince1970: metadata["startTime"] as? TimeInterval ?? 0),
            numberOfDays: metadata["numberOfDays"] as? Int ?? 1,
            isPurchased: metadata["isPurchased"] as? Bool ?? false,
            isDraft: metadata["isDraft"] as? Bool ?? false
        )
        
        // Load thumbnail
        if metadata["hasThumbnail"] as? Bool == true {
            let thumbnailURL = planThumbnailURL(for: planId)
            planData.thumbnailData = try? Data(contentsOf: thumbnailURL)
        }
        
        // Load other properties
        planData.totalCost = metadata["totalCost"] as? Int ?? 0
        
        if let lastVisitedInterval = metadata["lastVisitedDate"] as? TimeInterval {
            planData.lastVisitedDate = Date(timeIntervalSince1970: lastVisitedInterval)
        }
        
        if let streamingUrlsData = metadata["streamingUrls"] as? [[String: String]] {
            planData.streamingUrls = streamingUrlsData.compactMap { dict in
                guard let service = dict["service"], let url = dict["url"] else { return nil }
                return StreamingService(service: service, url: url)
            }
        }
        
        return planData
    }
    
    func deletePlanData(planId: String) {
        // Delete from storage
        VisitPlanStorage.shared.deletePlan(planId: planId)
        
        // Delete from metadata
        var drafts = loadAllDraftPlansMetadata()
        drafts.removeValue(forKey: planId)
        saveDraftPlansMetadata(drafts)
        
        var plans = loadAllSavedPlansMetadata()
        plans.removeValue(forKey: planId)
        saveSavedPlansMetadata(plans)
    }
    
    // MARK: - Metadata Storage
    
    private func loadAllSavedPlansMetadata() -> [String: [String: Any]] {
        UserDefaults.standard.dictionary(forKey: "savedPlansMetadata") as? [String: [String: Any]] ?? [:]
    }
    
    private func saveSavedPlansMetadata(_ metadata: [String: [String: Any]]) {
        UserDefaults.standard.set(metadata, forKey: "savedPlansMetadata")
    }
    
    private func loadAllDraftPlansMetadata() -> [String: [String: Any]] {
        UserDefaults.standard.dictionary(forKey: "draftPlansMetadata") as? [String: [String: Any]] ?? [:]
    }
    
    private func saveDraftPlansMetadata(_ metadata: [String: [String: Any]]) {
        UserDefaults.standard.set(metadata, forKey: "draftPlansMetadata")
    }
    
    // MARK: - Migration from old format
    
    func migrateOldSavedPlans() {
        // Migrate from UserDefaultsHelper storage
        if let data = UserDefaultsHelper.shared.getData(forKey: "savedPlans"),
           let oldPlans = try? JSONDecoder().decode([VisitPlanData].self, from: data) {
            
            print("Migrating \(oldPlans.count) saved plans to new storage format...")
            
            for plan in oldPlans {
                savePlanData(plan)
            }
            
            // Remove old data after successful migration
            UserDefaults.standard.removeObject(forKey: "savedPlans")
            UserDefaultsHelper.shared.removeData(forKey: "savedPlans")
        }
        
        // Migrate draft plans
        if let userId = UserDefaults.standard.string(forKey: "userId") {
            let draftKey = "draftVisitPlans_\(userId)"
            if let data = UserDefaultsHelper.shared.getData(forKey: draftKey),
               let oldDrafts = try? JSONDecoder().decode([VisitPlanData].self, from: data) {
                
                print("Migrating \(oldDrafts.count) draft plans to new storage format...")
                
                for draft in oldDrafts {
                    savePlanData(draft)
                }
                
                // Remove old data
                UserDefaults.standard.removeObject(forKey: draftKey)
                UserDefaultsHelper.shared.removeData(forKey: draftKey)
            }
        }
    }
    
    // MARK: - Load all plans
    
    func loadAllSavedPlans() -> [VisitPlanData] {
        let metadata = loadAllSavedPlansMetadata()
        return metadata.compactMap { (planId, _) in
            loadPlanData(planId: planId, isDraft: false)
        }
    }
    
    func loadAllDraftPlans() -> [VisitPlanData] {
        let metadata = loadAllDraftPlansMetadata()
        return metadata.compactMap { (planId, _) in
            loadPlanData(planId: planId, isDraft: true)
        }
    }
}