import Foundation
import Network
import SwiftUI

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = false
    @Published var connectionType: NWInterface.InterfaceType?
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
                
                if path.status == .satisfied {
                    print("🌐 Network connected via \(self?.connectionType?.description ?? "unknown")")
                } else {
                    // print("❌ Network disconnected")
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
    
    // ネットワーク問題を診断する機能
    func diagnoseNetworkIssues() {
        // print("🔍 [Network Diagnostic] Starting network diagnosis...")
        
        let testURLs = [
            "https://www.google.com",
            "https://img.youtube.com/vi/test/default.jpg",
            "https://firestore.googleapis.com",
            "https://happiness-game.onrender.com"
        ]
        
        for urlString in testURLs {
            testConnection(to: urlString)
        }
    }
    
    private func testConnection(to urlString: String) {
        guard let url = URL(string: urlString) else {
            // print("❌ [Network Test] Invalid URL: \(urlString)")
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        request.httpMethod = "HEAD" // Use HEAD to minimize data transfer
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    // print("❌ [Network Test] \(urlString): \(error.localizedDescription)")
                    
                    // 特定のエラータイプをチェック
                    if let nsError = error as NSError? {
                        switch nsError.code {
                        case NSURLErrorNotConnectedToInternet:
                            print("   → No internet connection")
                        case NSURLErrorTimedOut:
                            print("   → Request timed out")
                        case NSURLErrorCannotFindHost:
                            print("   → Cannot find host")
                        case NSURLErrorCannotConnectToHost:
                            print("   → Cannot connect to host")
                        case NSURLErrorSecureConnectionFailed:
                            print("   → SSL/TLS connection failed")
                        default:
                            print("   → Error code: \(nsError.code)")
                        }
                    }
                } else if let httpResponse = response as? HTTPURLResponse {
                    // print("✅ [Network Test] \(urlString): HTTP \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
    
    // 接続再試行機能
    func retryConnection(completion: @escaping (Bool) -> Void) {
        // print("🔄 [Network] Retrying connection...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            completion(self.isConnected)
        }
    }
}

// Network interface type description
extension NWInterface.InterfaceType {
    var description: String {
        switch self {
        case .wifi:
            return "WiFi"
        case .cellular:
            return "Cellular"
        case .wiredEthernet:
            return "Ethernet"
        case .loopback:
            return "Loopback"
        case .other:
            return "Other"
        @unknown default:
            return "Unknown"
        }
    }
}

// Network status view for debugging
struct NetworkStatusView: View {
    @StateObject private var networkManager = NetworkManager.shared
    
    var body: some View {
        HStack {
            Circle()
                .fill(networkManager.isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            Text(networkManager.isConnected ? "Connected" : "Offline")
                .font(.caption)
                .foregroundColor(.gray)
            
            if let connectionType = networkManager.connectionType {
                Text("(\(connectionType.description))")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
    }
}