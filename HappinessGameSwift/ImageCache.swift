import UIKit
import SwiftUI

// MARK: - Image Cache Manager
final class ImageCache {
    static let shared = ImageCache()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCacheURL: URL
    private let ioQueue = DispatchQueue(label: "com.happinessgame.imagecache", attributes: .concurrent)
    
    // Cache size limits - Further reduced for better memory management
    private let maxMemoryCost = 10 * 1024 * 1024 // 10MB
    private let maxDiskSize = 50 * 1024 * 1024 // 50MB
    
    private init() {
        // Configure memory cache
        memoryCache.totalCostLimit = maxMemoryCost
        memoryCache.countLimit = 30 // Max 30 images in memory
        
        // Setup disk cache directory
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = cacheDir.appendingPathComponent("ImageCache")
        
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        
        // Clean old cache on startup
        cleanOldCache()
        
        // Listen for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    // MARK: - Public Methods
    
    func image(for key: String) -> UIImage? {
        let cacheKey = NSString(string: key)
        
        // Check memory cache first
        if let cachedImage = memoryCache.object(forKey: cacheKey) {
            return cachedImage
        }
        
        // Check disk cache
        let fileURL = diskCacheURL.appendingPathComponent(key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key)
        
        if let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            // Store in memory cache for quick access
            let cost = data.count
            memoryCache.setObject(image, forKey: cacheKey, cost: cost)
            return image
        }
        
        return nil
    }
    
    func store(_ image: UIImage, for key: String) {
        let cacheKey = NSString(string: key)
        
        ioQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Compress image to reduce memory usage
            let compressedData = self.compressImage(image)
            let cost = compressedData?.count ?? 0
            
            // Store in memory cache
            self.memoryCache.setObject(image, forKey: cacheKey, cost: cost)
            
            // Store on disk
            if let data = compressedData {
                let fileURL = self.diskCacheURL.appendingPathComponent(key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key)
                try? data.write(to: fileURL)
            }
        }
    }
    
    func removeImage(for key: String) {
        let cacheKey = NSString(string: key)
        memoryCache.removeObject(forKey: cacheKey)
        
        let fileURL = diskCacheURL.appendingPathComponent(key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key)
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }
    
    func clearAllCache() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: diskCacheURL)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
    
    func reduceMemoryLimit(to bytes: Int) {
        memoryCache.totalCostLimit = bytes
    }
    
    func reduceCountLimit(to count: Int) {
        memoryCache.countLimit = count
    }
    
    // MARK: - Private Methods
    
    private func compressImage(_ image: UIImage) -> Data? {
        // Calculate optimal compression based on image size
        let maxDimension: CGFloat = 1280 // Max width/height - reduced from 1920
        let compressionQuality: CGFloat = 0.6 // Reduced from 0.8
        
        var resizedImage = image
        
        // Resize if needed
        if image.size.width > maxDimension || image.size.height > maxDimension {
            let scale = min(maxDimension / image.size.width, maxDimension / image.size.height)
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
        }
        
        // Try JPEG compression first
        if let jpegData = resizedImage.jpegData(compressionQuality: compressionQuality) {
            return jpegData
        }
        
        // Fallback to PNG
        return resizedImage.pngData()
    }
    
    private func cleanOldCache() {
        ioQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(
                    at: self.diskCacheURL,
                    includingPropertiesForKeys: [.contentAccessDateKey, .fileSizeKey],
                    options: []
                )
                
                var totalSize = 0
                var fileInfos: [(url: URL, accessDate: Date, size: Int)] = []
                
                for fileURL in fileURLs {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.contentAccessDateKey, .fileSizeKey])
                    if let accessDate = resourceValues.contentAccessDate,
                       let fileSize = resourceValues.fileSize {
                        totalSize += fileSize
                        fileInfos.append((url: fileURL, accessDate: accessDate, size: fileSize))
                    }
                }
                
                // Remove old files if cache is too large
                if totalSize > self.maxDiskSize {
                    // Sort by access date (oldest first)
                    fileInfos.sort { $0.accessDate < $1.accessDate }
                    
                    var currentSize = totalSize
                    for fileInfo in fileInfos {
                        if currentSize <= self.maxDiskSize * 3 / 4 { // Keep 75% of max size
                            break
                        }
                        
                        try FileManager.default.removeItem(at: fileInfo.url)
                        currentSize -= fileInfo.size
                    }
                }
                
                // Also remove files older than 30 days
                let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
                for fileInfo in fileInfos {
                    if fileInfo.accessDate < thirtyDaysAgo {
                        try? FileManager.default.removeItem(at: fileInfo.url)
                    }
                }
                
            } catch {
                print("Error cleaning cache: \(error)")
            }
        }
    }
    
    @objc private func handleMemoryWarning() {
        clearMemoryCache()
    }
}

// MARK: - SwiftUI Image View with Cache
struct CachedAsyncImage: View {
    let url: URL?
    let placeholder: Image
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    init(url: URL?, placeholder: Image = Image(systemName: "photo")) {
        self.url = url
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGray6))
            } else {
                placeholder
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        
        let cacheKey = url.absoluteString
        
        // Check cache first
        if let cachedImage = ImageCache.shared.image(for: cacheKey) {
            self.image = cachedImage
            return
        }
        
        // Load from network
        isLoading = true
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let data = data, let loadedImage = UIImage(data: data) {
                    self.image = loadedImage
                    ImageCache.shared.store(loadedImage, for: cacheKey)
                }
            }
        }.resume()
    }
}

// MARK: - Optimized Local Image Loading
struct OptimizedLocalImage: View {
    let path: String
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
            } else {
                Color.gray.opacity(0.3)
                    .overlay(
                        ProgressView()
                    )
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        // Check cache first
        if let cachedImage = ImageCache.shared.image(for: path) {
            self.image = cachedImage
            return
        }
        
        // Load asynchronously to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let imagePath = documentsPath.appendingPathComponent(path)
            
            if let image = UIImage(contentsOfFile: imagePath.path) {
                // Generate thumbnail for display
                let thumbnail = generateThumbnail(for: image, maxSize: CGSize(width: 800, height: 800))
                
                DispatchQueue.main.async {
                    self.image = thumbnail
                    ImageCache.shared.store(thumbnail, for: path)
                }
            }
        }
    }
    
    private func generateThumbnail(for image: UIImage, maxSize: CGSize) -> UIImage {
        let scale = min(maxSize.width / image.size.width, maxSize.height / image.size.height)
        
        // Don't upscale
        if scale >= 1.0 { return image }
        
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        return thumbnail
    }
}

// MARK: - Optimized Thumbnail View
struct OptimizedThumbnailView: View {
    let imageData: Data?
    let size: CGSize
    
    @State private var thumbnail: UIImage?
    
    init(imageData: Data?, size: CGSize = CGSize(width: 150, height: 150)) {
        self.imageData = imageData
        self.size = size
    }
    
    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: size.width, height: size.height)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.5)
                    )
            }
        }
        .task {
            await generateThumbnail()
        }
        .onDisappear {
            // Release thumbnail when view disappears
            thumbnail = nil
        }
    }
    
    private func generateThumbnail() async {
        guard let imageData = imageData,
              let originalImage = UIImage(data: imageData) else { return }
        
        await MainActor.run {
            self.thumbnail = ImageOptimizer.generateThumbnail(
                from: originalImage,
                targetSize: size
            )
        }
    }
}

// MARK: - Optimized Local File Image
struct OptimizedFileImage: View {
    let path: String
    let targetSize: CGSize
    
    @State private var image: UIImage?
    
    init(path: String, targetSize: CGSize = CGSize(width: 300, height: 300)) {
        self.path = path
        self.targetSize = targetSize
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(ProgressView())
            }
        }
        .task {
            await loadOptimizedImage()
        }
        .onChange(of: path) { _ in
            // Path changed, reload image
            image = nil
            Task {
                await loadOptimizedImage()
            }
        }
        .onDisappear {
            // Release image when view disappears
            image = nil
        }
    }
    
    private func loadOptimizedImage() async {
        // Check cache first
        let cacheKey = "\(path)_\(Int(targetSize.width))x\(Int(targetSize.height))"
        if let cachedImage = ImageCache.shared.image(for: cacheKey) {
            await MainActor.run {
                self.image = cachedImage
            }
            return
        }
        
        // Load from file system
        await Task.detached(priority: .userInitiated) {
            if let loadedImage = loadImageFromPath(path) {
                let optimized = ImageOptimizer.optimizeForDisplay(
                    loadedImage,
                    targetSize: targetSize
                )
                
                // Cache the optimized image
                ImageCache.shared.store(optimized, for: cacheKey)
                
                await MainActor.run {
                    self.image = optimized
                }
            }
        }.value
    }
    
    private func loadImageFromPath(_ path: String) -> UIImage? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let imagePath = documentsPath.appendingPathComponent(path)
        return UIImage(contentsOfFile: imagePath.path)
    }
}

// MARK: - Memory Efficient Grid
struct MemoryEfficientImageGrid<Item: Identifiable>: View {
    let items: [Item]
    let columns: Int
    let spacing: CGFloat
    let imageLoader: (Item) -> Data?
    let onTap: (Item) -> Void
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: spacing) {
                ForEach(items) { item in
                    OptimizedThumbnailView(
                        imageData: imageLoader(item),
                        size: CGSize(width: 150, height: 150)
                    )
                    .cornerRadius(12)
                    .onTapGesture {
                        onTap(item)
                    }
                }
            }
            .padding(spacing)
        }
    }
}

// MARK: - Extensions for ImageOptimizer
extension ImageOptimizer {
    static func generateThumbnail(from image: UIImage, targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    static func optimizeForDisplay(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let scale = min(targetSize.width / image.size.width, targetSize.height / image.size.height)
        
        // Don't upscale
        if scale >= 1.0 { return image }
        
        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}