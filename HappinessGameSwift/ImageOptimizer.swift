import UIKit
import CoreGraphics
import ImageIO

// MARK: - Image Optimizer
final class ImageOptimizer {
    static let shared = ImageOptimizer()
    
    private let processingQueue = DispatchQueue(label: "com.happinessgame.imageprocessing", qos: .userInitiated)
    
    private init() {}
    
    // MARK: - Image Compression
    
    func optimizeImage(_ image: UIImage, for purpose: ImagePurpose) async -> Data? {
        await withCheckedContinuation { continuation in
            processingQueue.async {
                let optimized = self.processImage(image, for: purpose)
                continuation.resume(returning: optimized)
            }
        }
    }
    
    private func processImage(_ image: UIImage, for purpose: ImagePurpose) -> Data? {
        let config = purpose.configuration
        
        // Resize if needed
        let resizedImage: UIImage
        if let maxSize = config.maxSize {
            resizedImage = resizeImage(image, maxSize: maxSize) ?? image
        } else {
            resizedImage = image
        }
        
        // Compress
        switch config.format {
        case .jpeg:
            return resizedImage.jpegData(compressionQuality: config.quality)
        case .png:
            return resizedImage.pngData()
        case .heic:
            return compressToHEIC(resizedImage, quality: config.quality)
        }
    }
    
    private func resizeImage(_ image: UIImage, maxSize: CGSize) -> UIImage? {
        let size = image.size
        
        // Calculate scale to fit within maxSize
        let widthScale = maxSize.width / size.width
        let heightScale = maxSize.height / size.height
        let scale = min(widthScale, heightScale)
        
        // Don't upscale
        if scale >= 1.0 { return image }
        
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        // Use CoreGraphics for better performance
        guard let cgImage = image.cgImage else { return nil }
        
        let bitsPerComponent = cgImage.bitsPerComponent
        let bytesPerRow = cgImage.bytesPerRow
        let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = cgImage.bitmapInfo
        
        guard let context = CGContext(
            data: nil,
            width: Int(newSize.width),
            height: Int(newSize.height),
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(origin: .zero, size: newSize))
        
        guard let resizedCGImage = context.makeImage() else { return nil }
        return UIImage(cgImage: resizedCGImage, scale: 1.0, orientation: image.imageOrientation)
    }
    
    private func compressToHEIC(_ image: UIImage, quality: CGFloat) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        
        guard let mutableData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(
                mutableData,
                "public.heic" as CFString,
                1,
                nil
              ) else { return nil }
        
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else { return nil }
        
        return mutableData as Data
    }
    
    // MARK: - Thumbnail Generation
    
    func generateThumbnail(from imageData: Data, size: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            processingQueue.async {
                let thumbnail = self.createThumbnail(from: imageData, size: size)
                continuation.resume(returning: thumbnail)
            }
        }
    }
    
    private func createThumbnail(from imageData: Data, size: CGSize) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height),
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Batch Processing
    
    func processBatch(_ images: [(UIImage, ImagePurpose)]) async -> [Data?] {
        await withTaskGroup(of: (Int, Data?).self) { group in
            for (index, (image, purpose)) in images.enumerated() {
                group.addTask {
                    let data = await self.optimizeImage(image, for: purpose)
                    return (index, data)
                }
            }
            
            var results = [Data?](repeating: nil, count: images.count)
            for await (index, data) in group {
                results[index] = data
            }
            
            return results
        }
    }
}

// MARK: - Image Purpose Configuration

enum ImagePurpose {
    case profilePicture
    case artworkFull
    case artworkThumbnail
    case videoThumbnail
    case bannerImage
    
    var configuration: ImageConfiguration {
        switch self {
        case .profilePicture:
            return ImageConfiguration(
                maxSize: CGSize(width: 400, height: 400),
                format: .jpeg,
                quality: 0.85
            )
        case .artworkFull:
            return ImageConfiguration(
                maxSize: CGSize(width: 1920, height: 1920),
                format: .jpeg,
                quality: 0.9
            )
        case .artworkThumbnail:
            return ImageConfiguration(
                maxSize: CGSize(width: 300, height: 300),
                format: .jpeg,
                quality: 0.7
            )
        case .videoThumbnail:
            return ImageConfiguration(
                maxSize: CGSize(width: 480, height: 270),
                format: .jpeg,
                quality: 0.75
            )
        case .bannerImage:
            return ImageConfiguration(
                maxSize: CGSize(width: 1200, height: 400),
                format: .jpeg,
                quality: 0.85
            )
        }
    }
}

struct ImageConfiguration {
    let maxSize: CGSize?
    let format: ImageFormat
    let quality: CGFloat
}

enum ImageFormat {
    case jpeg
    case png
    case heic
}

// MARK: - Memory-Efficient Image Loading

extension UIImage {
    static func loadOptimized(from url: URL, maxSize: CGSize? = nil) -> UIImage? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        
        let options: [CFString: Any]
        if let maxSize = maxSize {
            options = [
                kCGImageSourceThumbnailMaxPixelSize: max(maxSize.width, maxSize.height),
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true
            ]
        } else {
            options = [
                kCGImageSourceShouldCache: false
            ]
        }
        
        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    func resized(to targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

// MARK: - Image Memory Management

class ImageMemoryManager {
    static let shared = ImageMemoryManager()
    
    private var memoryWarningObserver: NSObjectProtocol?
    
    private init() {
        setupMemoryWarningObserver()
    }
    
    private func setupMemoryWarningObserver() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.handleMemoryWarning()
        }
    }
    
    private func handleMemoryWarning() {
        // Clear all image caches
        ImageCache.shared.clearMemoryCache()
        
        // Force garbage collection of image data
        URLCache.shared.removeAllCachedResponses()
        
        // Notify other components
        NotificationCenter.default.post(name: .imageMemoryWarning, object: nil)
    }
    
    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

extension Notification.Name {
    static let imageMemoryWarning = Notification.Name("imageMemoryWarning")
}