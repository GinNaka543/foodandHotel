import SwiftUI

struct ServerStatusView: View {
    @StateObject private var keepAlive = KeepAliveManager.shared
    @State private var serverStatus: String = "Checking..."
    @State private var isServerOnline: Bool = false
    @State private var lastCheckTime: Date?
    @State private var isChecking: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: isServerOnline ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(isServerOnline ? .green : .red)
                
                Text("Server Status")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            // Status Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Status:")
                        .fontWeight(.medium)
                    Text(serverStatus)
                        .foregroundColor(isServerOnline ? .green : .red)
                }
                
                if let lastCheck = lastCheckTime {
                    HStack {
                        Text("Last Check:")
                            .fontWeight(.medium)
                        Text(lastCheck, style: .time)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("Server URL:")
                        .fontWeight(.medium)
                    Text("happiness-game.onrender.com")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Actions
            VStack(spacing: 12) {
                Button(action: checkServerStatus) {
                    HStack {
                        if isChecking {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isChecking ? "Checking..." : "Check Now")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isChecking)
                
                Button(action: warmUpServer) {
                    HStack {
                        Image(systemName: "flame")
                        Text("Warm Up All Endpoints")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            
            // Info Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Keep-Alive Information")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                InfoRow(label: "Ping Interval", value: "14 minutes")
                InfoRow(label: "Background Mode", value: "Enabled")
                InfoRow(label: "Auto Recovery", value: "Active")
                
                Text("The app automatically pings the server every 14 minutes to prevent cold starts on Render.com's free tier.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Server Management")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkServerStatus()
        }
    }
    
    private func checkServerStatus() {
        isChecking = true
        
        keepAlive.checkServerStatus { isOnline, message in
            self.isServerOnline = isOnline
            self.serverStatus = message ?? (isOnline ? "Online" : "Offline")
            self.lastCheckTime = Date()
            self.isChecking = false
        }
    }
    
    private func warmUpServer() {
        keepAlive.warmUpEndpoints()
        
        // Show feedback
        serverStatus = "Warming up..."
        
        // Check status after warm-up
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            checkServerStatus()
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.system(size: 14))
    }
}

#Preview {
    NavigationView {
        ServerStatusView()
    }
}