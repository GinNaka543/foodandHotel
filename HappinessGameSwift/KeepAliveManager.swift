import Foundation
import UIKit
import BackgroundTasks

// MARK: - Keep-Alive Manager for Render.com Server
class KeepAliveManager: ObservableObject {
    static let shared = KeepAliveManager()
    
    private let baseURL = "https://happiness-game.onrender.com"
    private var pingTimer: Timer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private let pingInterval: TimeInterval = 840.0 // 14 minutes (Render.com has 15-minute timeout)
    private var lastPingTime: Date?
    
    // Background task identifier for BGTaskScheduler
    private let backgroundTaskIdentifier = "com.nakajima.HappinessGameSwift.keepalive"
    
    private init() {
        setupBackgroundTasks()
        setupNotificationObservers()
    }
    
    // MARK: - Public Methods
    
    /// Start the keep-alive service
    func startKeepAlive() {
        print("[KeepAlive] Starting keep-alive service")
        
        // Initial ping
        pingServer()
        
        // Setup regular ping timer
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { _ in
            self.pingServer()
        }
        
        // Schedule background refresh
        scheduleBackgroundRefresh()
    }
    
    /// Stop the keep-alive service
    func stopKeepAlive() {
        print("[KeepAlive] Stopping keep-alive service")
        pingTimer?.invalidate()
        pingTimer = nil
    }
    
    // MARK: - Private Methods
    
    /// Ping the server to keep it warm
    private func pingServer() {
        // Check if we should skip this ping (e.g., if we pinged recently)
        if let lastPing = lastPingTime, Date().timeIntervalSince(lastPing) < 60 {
            print("[KeepAlive] Skipping ping - too soon since last ping")
            return
        }
        
        guard let url = URL(string: "\(baseURL)/api/health") else { return }
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.waitsForConnectivity = true
        let session = URLSession(configuration: configuration)
        
        let task = session.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.lastPingTime = Date()
                
                if let error = error {
                    print("[KeepAlive] Ping failed: \(error.localizedDescription)")
                } else if let httpResponse = response as? HTTPURLResponse {
                    print("[KeepAlive] Ping successful - Status: \(httpResponse.statusCode)")
                    
                    // If server is healthy, schedule next background refresh
                    if httpResponse.statusCode == 200 {
                        self.scheduleBackgroundRefresh()
                    }
                }
            }
        }
        
        task.resume()
        print("[KeepAlive] Ping sent to server at \(Date())")
    }
    
    /// Ping server with completion handler
    private func pingServerWithCompletion(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/health") else {
            completion(false)
            return
        }
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 25.0
        configuration.waitsForConnectivity = true
        let session = URLSession(configuration: configuration)
        
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                print("[KeepAlive] Background ping failed: \(error.localizedDescription)")
                completion(false)
            } else if let httpResponse = response as? HTTPURLResponse {
                print("[KeepAlive] Background ping successful - Status: \(httpResponse.statusCode)")
                completion(httpResponse.statusCode == 200)
            } else {
                completion(false)
            }
        }
        
        task.resume()
    }
    
    // MARK: - Background Task Management
    
    private func setupBackgroundTasks() {
        // Register background task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 13 * 60) // 13 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("[KeepAlive] Background refresh scheduled")
        } catch {
            print("[KeepAlive] Failed to schedule background refresh: \(error)")
        }
    }
    
    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        print("[KeepAlive] Handling background refresh")
        
        // Schedule next background refresh
        scheduleBackgroundRefresh()
        
        // Create a background operation queue
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        // Create ping operation
        let pingOperation = BlockOperation {
            let semaphore = DispatchSemaphore(value: 0)
            var success = false
            
            self.pingServerWithCompletion { result in
                success = result
                semaphore.signal()
            }
            
            // Wait for completion (max 25 seconds)
            _ = semaphore.wait(timeout: .now() + 25)
            
            if success {
                print("[KeepAlive] Background ping completed successfully")
            }
        }
        
        // Set expiration handler
        task.expirationHandler = {
            queue.cancelAllOperations()
            print("[KeepAlive] Background task expired")
        }
        
        // Add operation and set completion
        pingOperation.completionBlock = {
            task.setTaskCompleted(success: !pingOperation.isCancelled)
        }
        
        queue.addOperation(pingOperation)
    }
    
    // MARK: - App Lifecycle Observers
    
    private func setupNotificationObservers() {
        // App will enter foreground
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        // App did enter background
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        // App will terminate
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc private func appWillEnterForeground() {
        print("[KeepAlive] App entering foreground")
        
        // End background task if active
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        
        // Restart regular pinging
        startKeepAlive()
    }
    
    @objc private func appDidEnterBackground() {
        print("[KeepAlive] App entering background")
        
        // Start background task to continue pinging
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        
        // Perform one immediate ping
        pingServer()
        
        // Schedule background refresh
        scheduleBackgroundRefresh()
    }
    
    @objc private func appWillTerminate() {
        print("[KeepAlive] App terminating")
        
        // Perform final ping
        pingServer()
        
        // Clean up
        stopKeepAlive()
    }
    
    private func endBackgroundTask() {
        print("[KeepAlive] Ending background task")
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
    
    // MARK: - Helper Methods
    
    /// Warm up multiple endpoints (useful for complex backends)
    func warmUpEndpoints() {
        let endpoints = [
            "/api/health",
            "/api/create-payment-intent",
            "/api/youtube-download"
        ]
        
        for endpoint in endpoints {
            guard let url = URL(string: "\(baseURL)\(endpoint)") else { continue }
            
            var request = URLRequest(url: url)
            request.httpMethod = endpoint.contains("youtube-download") ? "GET" : "HEAD"
            request.timeoutInterval = 10.0
            
            URLSession.shared.dataTask(with: request) { _, _, _ in
                // We don't care about the response, just warming up
            }.resume()
        }
        
        print("[KeepAlive] Warmed up \(endpoints.count) endpoints")
    }
    
    /// Get server status
    func checkServerStatus(completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/health") else {
            completion(false, "Invalid URL")
            return
        }
        
        let startTime = Date()
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            let responseTime = Date().timeIntervalSince(startTime)
            
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, error.localizedDescription)
                } else if let httpResponse = response as? HTTPURLResponse {
                    let statusMessage = "Status: \(httpResponse.statusCode), Response time: \(String(format: "%.2f", responseTime))s"
                    completion(httpResponse.statusCode == 200, statusMessage)
                } else {
                    completion(false, "Unknown error")
                }
            }
        }.resume()
    }
}

// MARK: - URL Session Extension for Keep-Alive
extension URLSession {
    /// Create a pre-warmed session for API calls
    static var keepAliveSession: URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = true
        
        // Keep connections alive
        configuration.httpShouldUsePipelining = true
        configuration.httpMaximumConnectionsPerHost = 2
        
        return URLSession(configuration: configuration)
    }
}