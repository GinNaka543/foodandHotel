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
        
        print("[VisitPlanDataStorage] Saving plan - ID: \(planId), Title: \(plan.title), isDraft: \(plan.isDraft)")
        
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
            "streamingUrls": plan.streamingUrls.map { ["service": $0.name, "url": $0.url] },
            "hasThumbnail": plan.thumbnailData != nil
        ]
        
        if let thumbnailUrl = plan.thumbnailUrl {
            planDict["thumbnailUrl"] = thumbnailUrl
        }
        
        if let lastVisitedDate = plan.lastVisitedDate {
            planDict["lastVisitedDate"] = lastVisitedDate.timeIntervalSince1970
        }
        
        // Check if plan is being moved from draft to confirmed
        var drafts = loadAllDraftPlansMetadata()
        var plans = loadAllSavedPlansMetadata()
        
        // Always remove from both to prevent duplicates
        drafts.removeValue(forKey: planId)
        plans.removeValue(forKey: planId)
        
        // Save to appropriate storage based on plan type
        if plan.isDraft {
            // Save draft plans separately
            drafts[planId] = planDict
            saveDraftPlansMetadata(drafts)
            print("[VisitPlanDataStorage] Saved as draft. Total drafts: \(drafts.count)")
        } else {
            // Save regular plans (purchased or confirmed)
            plans[planId] = planDict
            saveSavedPlansMetadata(plans)
            print("[VisitPlanDataStorage] Saved as confirmed plan. Total plans: \(plans.count)")
            
            // Ensure it's removed from drafts when saving as non-draft
            if drafts.count > 0 {
                print("[VisitPlanDataStorage] Cleaning up drafts after saving confirmed plan")
                saveDraftPlansMetadata(drafts)
            }
        }
    }
    
    func loadPlanData(planId: String, isDraft: Bool = false) -> VisitPlanData? {
        print("[VisitPlanDataStorage] loadPlanData called - planId: \(planId), isDraft: \(isDraft)")
        
        // Load metadata
        let metadata: [String: Any]
        if isDraft {
            let drafts = loadAllDraftPlansMetadata()
            print("[VisitPlanDataStorage] Found \(drafts.count) draft metadata entries")
            guard let draft = drafts[planId] else { 
                print("[VisitPlanDataStorage] No draft metadata found for planId: \(planId)")
                return nil 
            }
            metadata = draft
        } else {
            let plans = loadAllSavedPlansMetadata()
            print("[VisitPlanDataStorage] Found \(plans.count) saved plan metadata entries")
            guard let plan = plans[planId] else { 
                print("[VisitPlanDataStorage] No saved plan metadata found for planId: \(planId)")
                return nil 
            }
            metadata = plan
        }
        
        print("[VisitPlanDataStorage] Metadata loaded for plan: \(metadata["title"] as? String ?? "Unknown")")
        
        // Load spots
        let spots = VisitPlanStorage.shared.loadPlan(planId: planId) ?? []
        print("[VisitPlanDataStorage] Loaded \(spots.count) spots from VisitPlanStorage")
        
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
        
        // Load thumbnail from VisitPlanStorage if available
        if let planMetadata = UserDefaults.standard.dictionary(forKey: "visit_plan_\(planId)"),
           planMetadata["hasPlanThumbnail"] as? Bool == true {
            planData.thumbnailData = VisitPlanStorage.shared.loadPlanThumbnail(planId: planId)
            print("[VisitPlanDataStorage] Loaded thumbnail from VisitPlanStorage for plan \(planId), size: \(planData.thumbnailData?.count ?? 0) bytes")
        } else if metadata["hasThumbnail"] as? Bool == true {
            // Fallback to loading from VisitPlanDataStorage location
            let thumbnailURL = planThumbnailURL(for: planId)
            planData.thumbnailData = try? Data(contentsOf: thumbnailURL)
            print("[VisitPlanDataStorage] Loaded thumbnail from VisitPlanDataStorage for plan \(planId), size: \(planData.thumbnailData?.count ?? 0) bytes")
        } else {
            print("[VisitPlanDataStorage] No thumbnail found for plan \(planId)")
        }
        
        // Load other properties
        planData.totalCost = metadata["totalCost"] as? Int ?? 0
        
        if let lastVisitedInterval = metadata["lastVisitedDate"] as? TimeInterval {
            planData.lastVisitedDate = Date(timeIntervalSince1970: lastVisitedInterval)
        }
        
        if let streamingUrlsData = metadata["streamingUrls"] as? [[String: String]] {
            planData.streamingUrls = streamingUrlsData.compactMap { dict in
                guard let service = dict["service"], let url = dict["url"] else { return nil }
                return StreamingService(name: service, url: url, icon: nil)
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
    
    // Convert a draft plan to a purchased plan
    func convertDraftToPurchased(planId: String) {
        print("[VisitPlanDataStorage] Converting draft \(planId) to purchased plan")
        
        // Load the draft
        if let draftData = loadPlanData(planId: planId, isDraft: true) {
            // Update the plan to be purchased and not a draft
            var purchasedPlan = draftData
            purchasedPlan.isPurchased = true
            purchasedPlan.isDraft = false
            
            // Save as purchased plan
            savePlanData(purchasedPlan)
            
            // Explicitly remove from drafts
            var drafts = loadAllDraftPlansMetadata()
            drafts.removeValue(forKey: planId)
            saveDraftPlansMetadata(drafts)
            
            print("[VisitPlanDataStorage] Successfully converted draft to purchased plan")
        } else {
            print("[VisitPlanDataStorage] Warning: Could not find draft plan to convert")
        }
    }
    
    // MARK: - Metadata Storage
    
    private func loadAllSavedPlansMetadata() -> [String: [String: Any]] {
        if let data = UserDefaultsHelper.shared.getData(forKey: "savedPlansMetadata"),
           let metadata = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] {
            return metadata
        }
        return [:]
    }
    
    private func saveSavedPlansMetadata(_ metadata: [String: [String: Any]]) {
        if let data = try? JSONSerialization.data(withJSONObject: metadata) {
            UserDefaultsHelper.shared.setData(data, forKey: "savedPlansMetadata")
        }
    }
    
    private func loadAllDraftPlansMetadata() -> [String: [String: Any]] {
        if let data = UserDefaultsHelper.shared.getData(forKey: "draftPlansMetadata"),
           let metadata = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] {
            return metadata
        }
        return [:]
    }
    
    private func saveDraftPlansMetadata(_ metadata: [String: [String: Any]]) {
        if let data = try? JSONSerialization.data(withJSONObject: metadata) {
            UserDefaultsHelper.shared.setData(data, forKey: "draftPlansMetadata")
        }
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
            // Also remove user-specific key if exists
            if let userId = UserDefaults.standard.string(forKey: "userId") {
                UserDefaults.standard.removeObject(forKey: "\(userId)_savedPlans")
            }
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
        // First, clean up any drafts that are also in saved plans
        cleanupDraftsThatAreSaved()
        
        let metadata = loadAllDraftPlansMetadata()
        return metadata.compactMap { (planId, _) in
            loadPlanData(planId: planId, isDraft: true)
        }
    }
    
    // Clean up drafts that have been converted to saved plans
    private func cleanupDraftsThatAreSaved() {
        var drafts = loadAllDraftPlansMetadata()
        let savedPlans = loadAllSavedPlansMetadata()
        
        var hasChanges = false
        for (planId, _) in drafts {
            if savedPlans[planId] != nil {
                print("[VisitPlanDataStorage] Removing draft \(planId) that exists in saved plans")
                drafts.removeValue(forKey: planId)
                hasChanges = true
            }
        }
        
        if hasChanges {
            saveDraftPlansMetadata(drafts)
            print("[VisitPlanDataStorage] Cleaned up \(savedPlans.count - drafts.count) drafts that were already saved")
        }
    }
    
    // MARK: - Data Cleanup Functions
    
    func cleanupDuplicatePlans() {
        print("[VisitPlanDataStorage] Starting duplicate cleanup...")
        
        // 重複を完全に削除する
        cleanupAllDuplicatePlansCompletely()
    }
    
    // 完全な重複削除機能
    func cleanupAllDuplicatePlansCompletely() {
        var plansMetadata = loadAllSavedPlansMetadata()
        var draftsMetadata = loadAllDraftPlansMetadata()
        
        print("[VisitPlanDataStorage] 🚨 AGGRESSIVE CLEANUP STARTED")
        print("[VisitPlanDataStorage] Found \(plansMetadata.count) plans before cleanup")
        
        // 購入されたプランを特定（同じタイトルで複数ある場合は1つだけ残す）
        var cleanPlans: [String: [String: Any]] = [:]
        var test3Plans: [(String, [String: Any])] = []
        
        // Test3プランを全て収集
        for (planId, planData) in plansMetadata {
            guard let title = planData["title"] as? String,
                  let isPurchased = planData["isPurchased"] as? Bool else {
                continue
            }
            
            if isPurchased && title == "Test3" {
                test3Plans.append((planId, planData))
            } else {
                // Test3以外のプランは全て保持
                cleanPlans[planId] = planData
            }
        }
        
        print("[VisitPlanDataStorage] Found \(test3Plans.count) Test3 duplicate plans")
        
        // Test3プランは最初の1つだけ保持
        if !test3Plans.isEmpty {
            let (firstId, firstData) = test3Plans[0]
            cleanPlans[firstId] = firstData
            print("[VisitPlanDataStorage] Keeping only first Test3 plan with ID: \(firstId)")
            
            // 残りのTest3プランを削除
            for i in 1..<test3Plans.count {
                let (planId, _) = test3Plans[i]
                print("[VisitPlanDataStorage] 🗑️ Deleting duplicate Test3 plan: \(planId)")
                // プランディレクトリも削除
                let planDir = planDirectory(for: planId)
                try? FileManager.default.removeItem(at: planDir)
            }
        }
        
        print("[VisitPlanDataStorage] Cleaned plans count: \(cleanPlans.count) (removed \(plansMetadata.count - cleanPlans.count) duplicates)")
        
        // クリーンなデータを保存
        saveSavedPlansMetadata(cleanPlans)
        
        // UserDefaultsを同期（UserDefaultsHelperが自動的に同期）
        
        // 不要なファイルも削除
        cleanupOrphanedPlanFiles(keepingPlanIds: Set(cleanPlans.keys))
        
        print("[VisitPlanDataStorage] ✅ AGGRESSIVE CLEANUP COMPLETE")
    }
    
    // 不要なプランファイルを削除
    private func cleanupOrphanedPlanFiles(keepingPlanIds: Set<String>) {
        do {
            let planDirs = try FileManager.default.contentsOfDirectory(at: visitPlansDirectory, 
                                                                      includingPropertiesForKeys: nil, 
                                                                      options: .skipsHiddenFiles)
            
            for planDir in planDirs {
                let planId = planDir.lastPathComponent
                if !keepingPlanIds.contains(planId) {
                    try FileManager.default.removeItem(at: planDir)
                    print("[VisitPlanDataStorage] Deleted orphaned plan directory: \(planId)")
                }
            }
        } catch {
            print("[VisitPlanDataStorage] Error cleaning up orphaned files: \(error)")
        }
    }
    
    func getStorageStatistics() -> (totalPlans: Int, totalDrafts: Int, duplicatePlans: Int, duplicateDrafts: Int) {
        let allPlans = loadAllSavedPlans()
        let allDrafts = loadAllDraftPlans()
        
        // Count unique IDs
        let uniquePlanIds = Set(allPlans.map { $0.id.uuidString })
        let uniqueDraftIds = Set(allDrafts.map { $0.id.uuidString })
        
        let duplicatePlans = allPlans.count - uniquePlanIds.count
        let duplicateDrafts = allDrafts.count - uniqueDraftIds.count
        
        return (allPlans.count, allDrafts.count, duplicatePlans, duplicateDrafts)
    }
}