import SwiftUI
import AppTrackingTransparency

struct TrackingPermissionView: View {
    @Binding var hasRequestedTracking: Bool
    @State private var trackingStatus: ATTrackingManager.AuthorizationStatus = .notDetermined
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "shield.checkered")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("トラッキングの許可")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("このアプリは、より良いサービスを提供するために、限定的なデータを収集します。")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading) {
                        Text("収集するデータ")
                            .fontWeight(.semibold)
                        Text("アプリの使用状況のみ")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(alignment: .top) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    VStack(alignment: .leading) {
                        Text("収集しないデータ")
                            .fontWeight(.semibold)
                        Text("広告用のトラッキング、個人を特定する情報")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
            
            Button(action: {
                requestTrackingPermission()
            }) {
                Text("続ける")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            
            Text("設定はいつでも変更できます")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 30)
        }
    }
    
    private func requestTrackingPermission() {
        ATTrackingManager.requestTrackingAuthorization { status in
            DispatchQueue.main.async {
                self.trackingStatus = status
                self.hasRequestedTracking = true
                UserDefaults.standard.set(true, forKey: "hasRequestedTracking")
            }
        }
    }
}

struct TrackingPermissionView_Previews: PreviewProvider {
    static var previews: some View {
        TrackingPermissionView(hasRequestedTracking: .constant(false))
    }
}