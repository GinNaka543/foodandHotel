import Foundation
import UIKit
import SwiftUI
import os.log

// MARK: - Performance Monitor
final class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    
    private let logger = Logger(subsystem: "com.happinessgame", category: "Performance")
    private var metrics: [String: PerformanceMetric] = [:]
    private let metricsQueue = DispatchQueue(label: "com.happinessgame.performance", attributes: .concurrent)
    
    // Memory tracking
    private var memoryWarningCount = 0
    private var peakMemoryUsage: Float = 0
    
    private init() {
        startMonitoring()
    }
    
    // MARK: - Public Methods
    
    func trackEvent(_ event: PerformanceEvent, metadata: [String: Any]? = nil) {
        let metric = PerformanceMetric(
            event: event,
            timestamp: Date(),
            duration: nil,
            metadata: metadata
        )
        
        metricsQueue.async(flags: .barrier) {
            self.metrics[event.rawValue] = metric
        }
        
        logger.debug("Performance event: \(event.rawValue)")
    }
    
    func startTracking(_ event: PerformanceEvent) -> PerformanceTracker {
        return PerformanceTracker(event: event)
    }
    
    func getReport() -> PerformanceReport {
        metricsQueue.sync {
            PerformanceReport(
                memoryUsage: getCurrentMemoryUsage(),
                peakMemoryUsage: peakMemoryUsage,
                memoryWarnings: memoryWarningCount,
                metrics: metrics
            )
        }
    }
    
    // MARK: - Memory Monitoring
    
    private func startMonitoring() {
        // Monitor memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Periodic memory check
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            self.checkMemoryUsage()
        }
    }
    
    @objc private func handleMemoryWarning() {
        memoryWarningCount += 1
        logger.warning("Memory warning #\(self.memoryWarningCount)")
        
        // Track memory warning event
        trackEvent(.memoryWarning, metadata: [
            "count": memoryWarningCount,
            "currentMemory": getCurrentMemoryUsage()
        ])
    }
    
    private func checkMemoryUsage() {
        let current = getCurrentMemoryUsage()
        if current > peakMemoryUsage {
            peakMemoryUsage = current
        }
        
        // Log if memory usage is high
        if current > 200 { // MB
            logger.warning("High memory usage: \(current) MB")
        }
    }
    
    private func getCurrentMemoryUsage() -> Float {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return Float(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        }
        
        return 0
    }
}

// MARK: - Performance Tracker
class PerformanceTracker {
    private let event: PerformanceEvent
    private let startTime: CFAbsoluteTime
    
    init(event: PerformanceEvent) {
        self.event = event
        self.startTime = CFAbsoluteTimeGetCurrent()
    }
    
    func end(metadata: [String: Any]? = nil) {
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        var finalMetadata = metadata ?? [:]
        finalMetadata["duration"] = duration
        
        PerformanceMonitor.shared.trackEvent(event, metadata: finalMetadata)
        
        if duration > 1.0 {
            Logger().warning("Slow operation: \(self.event.rawValue) took \(duration)s")
        }
    }
}

// MARK: - Supporting Types
enum PerformanceEvent: String {
    // App lifecycle
    case appLaunch = "app_launch"
    case appEnterBackground = "app_enter_background"
    case appEnterForeground = "app_enter_foreground"
    
    // Image operations
    case imageLoad = "image_load"
    case imageSave = "image_save"
    case thumbnailGeneration = "thumbnail_generation"
    case imageCompression = "image_compression"
    
    // Network operations
    case networkRequest = "network_request"
    case networkResponse = "network_response"
    case cacheHit = "cache_hit"
    case cacheMiss = "cache_miss"
    
    // UI operations
    case viewLoad = "view_load"
    case listScroll = "list_scroll"
    case modalPresentation = "modal_presentation"
    
    // Data operations
    case dataLoad = "data_load"
    case dataSave = "data_save"
    case migration = "migration"
    
    // Memory events
    case memoryWarning = "memory_warning"
    case cacheCleared = "cache_cleared"
}

struct PerformanceMetric {
    let event: PerformanceEvent
    let timestamp: Date
    let duration: TimeInterval?
    let metadata: [String: Any]?
}

struct PerformanceReport {
    let memoryUsage: Float
    let peakMemoryUsage: Float
    let memoryWarnings: Int
    let metrics: [String: PerformanceMetric]
    
    var summary: String {
        """
        Performance Report:
        - Current Memory: \(String(format: "%.1f", memoryUsage)) MB
        - Peak Memory: \(String(format: "%.1f", peakMemoryUsage)) MB
        - Memory Warnings: \(memoryWarnings)
        - Tracked Events: \(metrics.count)
        """
    }
}

// MARK: - Debug View
struct PerformanceDebugView: View {
    @State private var report = PerformanceMonitor.shared.getReport()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Monitor")
                .font(.headline)
            
            HStack {
                Label("Memory", systemImage: "memorychip")
                Spacer()
                Text("\(String(format: "%.1f", report.memoryUsage)) MB")
                    .foregroundColor(report.memoryUsage > 200 ? .red : .primary)
            }
            
            HStack {
                Label("Peak", systemImage: "arrow.up")
                Spacer()
                Text("\(String(format: "%.1f", report.peakMemoryUsage)) MB")
            }
            
            HStack {
                Label("Warnings", systemImage: "exclamationmark.triangle")
                Spacer()
                Text("\(report.memoryWarnings)")
                    .foregroundColor(report.memoryWarnings > 0 ? .orange : .primary)
            }
            
            Divider()
            
            Text("Recent Events")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ForEach(Array(report.metrics.values.sorted { $0.timestamp > $1.timestamp }.prefix(5)), id: \.event.rawValue) { metric in
                HStack {
                    Text(metric.event.rawValue)
                        .font(.caption2)
                    Spacer()
                    if let duration = metric.metadata?["duration"] as? TimeInterval {
                        Text("\(Int(duration * 1000))ms")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
        .onReceive(timer) { _ in
            report = PerformanceMonitor.shared.getReport()
        }
    }
}

// MARK: - View Extensions for Performance Tracking
extension View {
    func trackPerformance(_ event: PerformanceEvent) -> some View {
        self.onAppear {
            PerformanceMonitor.shared.trackEvent(event)
        }
    }
    
    func measurePerformance(_ event: PerformanceEvent) -> some View {
        self.modifier(PerformanceMeasureModifier(event: event))
    }
}

struct PerformanceMeasureModifier: ViewModifier {
    let event: PerformanceEvent
    @State private var tracker: PerformanceTracker?
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                tracker = PerformanceMonitor.shared.startTracking(event)
            }
            .onDisappear {
                tracker?.end()
            }
    }
}