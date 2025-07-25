import UIKit
import SwiftUI

// MARK: - Memory Optimization Extensions
extension UIImage {
    /// Resize image to reduce memory footprint
    func resizedForMemoryEfficiency(maxDimension: CGFloat = 1024) -> UIImage {
        let size = self.size
        
        // Don't resize if already small enough
        if size.width <= maxDimension && size.height <= maxDimension {
            return self
        }
        
        // Calculate new size maintaining aspect ratio
        let scale = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        // Use UIGraphicsImageRenderer for better performance
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { context in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return resized
    }
}

// MARK: - Memory Efficient Image View
struct MemoryEfficientAsyncImage: View {
    let url: URL?
    let maxDimension: CGFloat
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    init(url: URL?, maxDimension: CGFloat = 800) {
        self.url = url
        self.maxDimension = maxDimension
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color.gray.opacity(0.3)
            }
        }
        .task {
            await loadImage()
        }
        .onDisappear {
            // Release image when view disappears
            image = nil
        }
    }
    
    private func loadImage() async {
        guard let url = url else { return }
        
        isLoading = true
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let originalImage = UIImage(data: data) {
                // Resize image before storing to reduce memory
                let resized = originalImage.resizedForMemoryEfficiency(maxDimension: maxDimension)
                
                await MainActor.run {
                    self.image = resized
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Aggressive Memory Cleanup
extension AppOptimizationManager {
    func performAggressiveMemoryCleanup() {
        // Clear all image caches
        ImageCache.shared.clearAllCache()
        
        // Clear URL cache
        URLCache.shared.removeAllCachedResponses()
        URLCache.shared.memoryCapacity = 0
        URLCache.shared.diskCapacity = 0
        
        // Force garbage collection
        autoreleasepool {
            // This helps release autorelease objects
        }
        
        // Clear any temporary files
        clearTemporaryFiles()
        
        // Request memory warning to system
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
    }
    
    private func clearTemporaryFiles() {
        let tempDirectory = FileManager.default.temporaryDirectory
        do {
            let tempFiles = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            for file in tempFiles {
                try? FileManager.default.removeItem(at: file)
            }
        } catch {
            print("Failed to clear temp files: \(error)")
        }
    }
}

// MARK: - Memory Monitoring View Modifier
struct MemoryMonitoringModifier: ViewModifier {
    @State private var memoryTimer: Timer?
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                startMemoryMonitoring()
            }
            .onDisappear {
                stopMemoryMonitoring()
            }
    }
    
    private func startMemoryMonitoring() {
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            let memoryUsage = PerformanceMonitor.shared.getReport().memoryUsage
            
            if memoryUsage > 150 {
                print("⚠️ High memory usage detected: \(memoryUsage)MB - Performing cleanup")
                AppOptimizationManager.shared.performAggressiveMemoryCleanup()
            }
        }
    }
    
    private func stopMemoryMonitoring() {
        memoryTimer?.invalidate()
        memoryTimer = nil
    }
}

extension View {
    func withMemoryMonitoring() -> some View {
        self.modifier(MemoryMonitoringModifier())
    }
}

// MARK: - Low Memory Mode
class LowMemoryMode: ObservableObject {
    static let shared = LowMemoryMode()
    
    @Published var isEnabled = false
    
    private init() {
        // Check device memory
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(physicalMemory) / 1_073_741_824
        
        // Enable low memory mode for devices with 3GB or less
        if memoryGB <= 3 {
            isEnabled = true
            print("Low memory mode enabled for device with \(String(format: "%.1f", memoryGB))GB RAM")
        }
        
        // Listen for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        isEnabled = true
        AppOptimizationManager.shared.performAggressiveMemoryCleanup()
    }
}