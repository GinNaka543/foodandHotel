import Foundation
import Combine

// MARK: - Optimized Network Manager
final class OptimizedNetworkManager {
    static let shared = OptimizedNetworkManager()
    
    private let session: URLSession
    private let requestQueue = DispatchQueue(label: "com.nakajima.HappinessGameSwift.network", qos: .userInitiated, attributes: .concurrent)
    private var activeTasks: [UUID: URLSessionTask] = [:]
    private let taskLock = NSLock()
    
    // Request deduplication
    private var pendingRequests: [String: [(UUID, CheckedContinuation<Data, Error>)]] = [:]
    
    // Response cache
    private let responseCache = NSCache<NSString, CachedResponse>()
    
    private init() {
        // Configure optimized URLSession
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 10 * 1024 * 1024, // 10MB memory cache
            diskCapacity: 50 * 1024 * 1024,   // 50MB disk cache
            diskPath: "NetworkCache"
        )
        configuration.httpMaximumConnectionsPerHost = 6
        
        session = URLSession(configuration: configuration)
        
        // Configure response cache
        responseCache.countLimit = 100
        responseCache.totalCostLimit = 20 * 1024 * 1024 // 20MB
    }
    
    // MARK: - Public Methods
    
    func fetch(url: URL, cachePolicy: CachePolicy = .cacheFirst) async throws -> Data {
        let cacheKey = url.absoluteString
        
        // Check cache based on policy
        switch cachePolicy {
        case .cacheFirst, .cacheOnly:
            if let cached = getCachedResponse(for: cacheKey) {
                return cached.data
            }
            if cachePolicy == .cacheOnly {
                throw NetworkError.noCachedData
            }
        case .networkFirst:
            // Try network first, fall back to cache
            break
        case .networkOnly:
            // Skip cache completely
            break
        }
        
        // Deduplicate requests
        return try await withCheckedThrowingContinuation { continuation in
            let requestId = UUID()
            
            taskLock.lock()
            if var pending = pendingRequests[cacheKey] {
                // Request already in flight, add to waiting list
                pending.append((requestId, continuation))
                pendingRequests[cacheKey] = pending
                taskLock.unlock()
                return
            } else {
                // First request for this URL
                pendingRequests[cacheKey] = [(requestId, continuation)]
            }
            taskLock.unlock()
            
            // Create new request
            let task = session.dataTask(with: url) { [weak self] data, response, error in
                guard let self = self else { return }
                
                self.taskLock.lock()
                let pending = self.pendingRequests.removeValue(forKey: cacheKey) ?? []
                self.taskLock.unlock()
                
                if let error = error {
                    // Notify all waiting requests of error
                    for (_, continuation) in pending {
                        continuation.resume(throwing: error)
                    }
                } else if let data = data {
                    // Cache successful response
                    if cachePolicy != .networkOnly {
                        self.cacheResponse(data, for: cacheKey)
                    }
                    
                    // Notify all waiting requests of success
                    for (_, continuation) in pending {
                        continuation.resume(returning: data)
                    }
                } else {
                    // No data and no error
                    for (_, continuation) in pending {
                        continuation.resume(throwing: NetworkError.noData)
                    }
                }
            }
            
            taskLock.lock()
            activeTasks[requestId] = task
            taskLock.unlock()
            
            task.resume()
        }
    }
    
    func prefetch(urls: [URL]) {
        for url in urls {
            Task {
                try? await fetch(url: url, cachePolicy: .cacheFirst)
            }
        }
    }
    
    func cancelAllRequests() {
        taskLock.lock()
        let tasks = Array(activeTasks.values)
        activeTasks.removeAll()
        taskLock.unlock()
        
        tasks.forEach { $0.cancel() }
    }
    
    // MARK: - Cache Management
    
    private func getCachedResponse(for key: String) -> CachedResponse? {
        if let cached = responseCache.object(forKey: NSString(string: key)) {
            // Check if cache is still valid (24 hours)
            if Date().timeIntervalSince(cached.timestamp) < 24 * 60 * 60 {
                return cached
            } else {
                responseCache.removeObject(forKey: NSString(string: key))
            }
        }
        return nil
    }
    
    private func cacheResponse(_ data: Data, for key: String) {
        let cached = CachedResponse(data: data, timestamp: Date())
        responseCache.setObject(cached, forKey: NSString(string: key), cost: data.count)
    }
    
    func clearCache() {
        responseCache.removeAllObjects()
        session.configuration.urlCache?.removeAllCachedResponses()
    }
}

// MARK: - Supporting Types

enum CachePolicy {
    case cacheFirst   // Use cache if available, otherwise network
    case networkFirst // Try network first, fall back to cache
    case cacheOnly    // Only use cache, fail if not available
    case networkOnly  // Always use network, ignore cache
}

enum NetworkError: LocalizedError {
    case noCachedData
    case noData
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .noCachedData:
            return "No cached data available"
        case .noData:
            return "No data received"
        case .invalidResponse:
            return "Invalid response"
        }
    }
}

private class CachedResponse {
    let data: Data
    let timestamp: Date
    
    init(data: Data, timestamp: Date) {
        self.data = data
        self.timestamp = timestamp
    }
}

// MARK: - Optimized API Client
class OptimizedAPIClient {
    private let baseURL: String
    private let networkManager = OptimizedNetworkManager.shared
    
    init(baseURL: String = "https://happiness-game.onrender.com") {
        self.baseURL = baseURL
    }
    
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        cachePolicy: CachePolicy = .networkFirst
    ) async throws -> T {
        let url = URL(string: "\(baseURL)\(endpoint)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        if let parameters = parameters {
            if method == .get {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
                components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
                request.url = components.url
            } else {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }
        
        let data = try await networkManager.fetch(url: request.url!, cachePolicy: cachePolicy)
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("Decoding error: \(error)")
            throw error
        }
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}