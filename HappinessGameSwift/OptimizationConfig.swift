import Foundation
import SwiftUI
import UIKit
import CoreGraphics
import ImageIO

// MARK: - Optimization Configuration
struct OptimizationConfig {
    
    // MARK: - Image Settings
    struct ImageSettings {
        static let maxMemoryCacheSize = 50 * 1024 * 1024 // 50MB
        static let maxDiskCacheSize = 200 * 1024 * 1024 // 200MB
        static let maxImageDimension: CGFloat = 1920
        static let thumbnailSize = CGSize(width: 300, height: 300)
        static let profileImageSize = CGSize(width: 400, height: 400)
        static let jpegCompressionQuality: CGFloat = 0.8
        static let cacheExpirationDays = 30
    }
    
    // MARK: - Network Settings
    struct NetworkSettings {
        static let requestTimeout: TimeInterval = 30
        static let resourceTimeout: TimeInterval = 60
        static let maxConcurrentConnections = 6
        static let memoryCacheCapacity = 10 * 1024 * 1024 // 10MB
        static let diskCacheCapacity = 50 * 1024 * 1024 // 50MB
        static let retryCount = 2
        static let retryDelay: TimeInterval = 1.0
    }
    
    // MARK: - List Settings
    struct ListSettings {
        static let pageSize = 20
        static let prefetchThreshold = 5
        static let visibleItemBuffer = 30
        static let scrollDebounceInterval: TimeInterval = 0.1
    }
    
    // MARK: - Memory Settings
    struct MemorySettings {
        static let warningThreshold: Float = 200 // MB
        static let criticalThreshold: Float = 300 // MB
        static let cleanupInterval: TimeInterval = 60 // seconds
    }
    
    // MARK: - Animation Settings
    struct AnimationSettings {
        static let defaultDuration: TimeInterval = 0.3
        static let springResponse: Double = 0.5
        static let springDamping: Double = 0.8
        static let disableComplexAnimations = false
    }
}

// MARK: - App Optimization Manager
final class AppOptimizationManager {
    static let shared = AppOptimizationManager()
    
    private init() {
        setupOptimizations()
    }
    
    private func setupOptimizations() {
        // Configure image loading
        configureImageLoading()
        
        // Configure network settings
        configureNetworking()
        
        // Setup memory monitoring
        setupMemoryMonitoring()
        
        // Configure UI optimizations
        configureUIOptimizations()
    }
    
    private func configureImageLoading() {
        // Set image cache limits
        ImageCache.shared.clearMemoryCache()
        
        // Configure default image loading behavior
        // HEIC support is built-in on iOS 11+
    }
    
    private func configureNetworking() {
        // Configure URLSession
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = OptimizationConfig.NetworkSettings.requestTimeout
        config.timeoutIntervalForResource = OptimizationConfig.NetworkSettings.resourceTimeout
        config.httpMaximumConnectionsPerHost = OptimizationConfig.NetworkSettings.maxConcurrentConnections
        config.requestCachePolicy = .returnCacheDataElseLoad
        
        // Configure cache
        let cache = URLCache(
            memoryCapacity: OptimizationConfig.NetworkSettings.memoryCacheCapacity,
            diskCapacity: OptimizationConfig.NetworkSettings.diskCacheCapacity,
            diskPath: "NetworkCache"
        )
        config.urlCache = cache
        URLCache.shared = cache
    }
    
    private func setupMemoryMonitoring() {
        // Start performance monitoring
        _ = PerformanceMonitor.shared
        
        // Setup periodic cleanup
        Timer.scheduledTimer(withTimeInterval: OptimizationConfig.MemorySettings.cleanupInterval, repeats: true) { _ in
            self.performMemoryCleanup()
        }
    }
    
    private func configureUIOptimizations() {
        // Disable complex animations on low-end devices
        if UIDevice.current.userInterfaceIdiom == .phone {
            let modelName = UIDevice.current.modelName
            if modelName.contains("iPhone 6") || modelName.contains("iPhone 7") || modelName.contains("iPhone 8") {
                UIView.setAnimationsEnabled(false)
            }
        }
        
        // Configure table/collection view settings
        UITableView.appearance().estimatedRowHeight = 100
        UICollectionView.appearance().isPrefetchingEnabled = true
    }
    
    func performMemoryCleanup() {
        let memoryUsage = PerformanceMonitor.shared.getReport().memoryUsage
        
        if memoryUsage > OptimizationConfig.MemorySettings.warningThreshold {
            // Clear image memory cache
            ImageCache.shared.clearMemoryCache()
            
            // Clear network cache
            URLCache.shared.removeAllCachedResponses()
            
            // Post notification for other components
            NotificationCenter.default.post(name: .performMemoryCleanup, object: nil)
            
            // Log cleanup
            PerformanceMonitor.shared.trackEvent(.cacheCleared, metadata: [
                "trigger": "memory_threshold",
                "memoryBefore": memoryUsage
            ])
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let performMemoryCleanup = Notification.Name("performMemoryCleanup")
}

// MARK: - UIDevice Extension
extension UIDevice {
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}

// MARK: - SwiftUI View Modifiers for Optimization
extension View {
    func optimizedForPerformance() -> some View {
        self
            .drawingGroup() // Flatten view hierarchy
            .compositingGroup() // Reduce transparency calculations
    }
    
    func lazyLoad() -> some View {
        self.modifier(LazyLoadModifier())
    }
    
    func memoryEfficient() -> some View {
        self.modifier(MemoryEfficientModifier())
    }
}

struct LazyLoadModifier: ViewModifier {
    @State private var hasAppeared = false
    
    func body(content: Content) -> some View {
        Group {
            if hasAppeared {
                content
            } else {
                Color.clear
                    .onAppear {
                        hasAppeared = true
                    }
            }
        }
    }
}

struct MemoryEfficientModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .performMemoryCleanup)) { _ in
                // Force view to release resources
            }
    }
}

// MARK: - Optimized Animation
extension Animation {
    static var optimizedDefault: Animation {
        .easeInOut(duration: OptimizationConfig.AnimationSettings.defaultDuration)
    }
    
    static var optimizedSpring: Animation {
        .spring(
            response: OptimizationConfig.AnimationSettings.springResponse,
            dampingFraction: OptimizationConfig.AnimationSettings.springDamping
        )
    }
}

// MARK: - Safe Image Loading
struct SafeImageView: View {
    let imageName: String?
    let placeholder: Image
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    
    init(imageName: String?, placeholder: Image = Image(systemName: "photo")) {
        self.imageName = imageName
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let loadedImage = loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
            } else if isLoading {
                placeholder
                    .foregroundColor(.gray)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            } else {
                placeholder
                    .foregroundColor(.gray)
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let imageName = imageName, !imageName.isEmpty else { return }
        
        isLoading = true
        
        // Check cache first
        if let cached = ImageCache.shared.image(for: imageName) {
            await MainActor.run {
                self.loadedImage = cached
                self.isLoading = false
            }
            return
        }
        
        // Load from disk
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let imagePath = documentsPath.appendingPathComponent(imageName)
        
        // Load image with optimization
        await Task {
            var loadedImage: UIImage?
            
            // Try to load with CoreGraphics for better memory efficiency
            if let imageSource = CGImageSourceCreateWithURL(imagePath as CFURL, nil) {
                let options: [CFString: Any] = [
                    kCGImageSourceThumbnailMaxPixelSize: 800,
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceCreateThumbnailWithTransform: true
                ]
                
                if let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
                    loadedImage = UIImage(cgImage: cgImage)
                }
            }
            
            // Fallback to standard loading
            if loadedImage == nil {
                loadedImage = UIImage(contentsOfFile: imagePath.path)
            }
            
            if let image = loadedImage {
                ImageCache.shared.store(image, for: imageName)
                await MainActor.run {
                    self.loadedImage = image
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }.value
    }
}