import UIKit
import os.log

// MARK: - Memory Pressure Manager
final class MemoryPressureManager {
    static let shared = MemoryPressureManager()
    
    private let logger = Logger(subsystem: "com.nakajima.HappinessGameSwift", category: "MemoryPressure")
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    
    private init() {
        setupMemoryPressureMonitoring()
    }
    
    private func setupMemoryPressureMonitoring() {
        // Create dispatch source for memory pressure events
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        
        memoryPressureSource?.setEventHandler { [weak self] in
            let event = self?.memoryPressureSource?.data
            
            switch event {
            case .some(.warning):
                self?.handleMemoryWarning()
            case .some(.critical):
                self?.handleMemoryCritical()
            default:
                break
            }
        }
        
        memoryPressureSource?.resume()
    }
    
    private func handleMemoryWarning() {
        logger.warning("Memory pressure: WARNING")
        
        // Clear memory caches
        ImageCache.shared.clearMemoryCache()
        
        // Reduce URL cache
        URLCache.shared.memoryCapacity = 5 * 1024 * 1024 // 5MB
    }
    
    
    private func handleMemoryCritical() {
        logger.critical("Memory pressure: CRITICAL")
        
        // Emergency cleanup
        EmergencyCleanup.performEmergencyCleanup()
        
        // Clear all caches
        ImageCache.shared.clearAllCache()
        
        // Force garbage collection
        autoreleasepool {
            // This helps release autorelease objects
        }
        
        // Notify app to reduce memory usage
        NotificationCenter.default.post(name: .memoryPressureCritical, object: nil)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let memoryPressureCritical = Notification.Name("memoryPressureCritical")
}

// MARK: - Storage Extensions for Cache Clearing
extension VideoStorage {
    func clearThumbnailCache() {
        // Clear in-memory thumbnail cache if any
        // This is a placeholder - implement based on your actual caching strategy
    }
}

extension ArtworkStorage {
    func clearThumbnailCache() {
        // Clear in-memory thumbnail cache if any
        // This is a placeholder - implement based on your actual caching strategy
    }
}