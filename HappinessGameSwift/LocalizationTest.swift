import SwiftUI

struct LocalizationTestView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Current Language: \(Locale.current.languageCode ?? "unknown")")
                .font(.headline)
            
            Text("Logout Keys Test:")
                .font(.headline)
                .padding(.top)
            
            Group {
                Text("important_logout_notice:")
                Text(NSLocalizedString("important_logout_notice", comment: ""))
                    .foregroundColor(.blue)
                
                Text("save_info_below:")
                Text(NSLocalizedString("save_info_below", comment: ""))
                    .foregroundColor(.blue)
                
                Text("cannot_recover_without_info:")
                Text(NSLocalizedString("cannot_recover_without_info", comment: ""))
                    .foregroundColor(.blue)
                
                Text("take_screenshot_or_memo:")
                Text(NSLocalizedString("take_screenshot_or_memo", comment: ""))
                    .foregroundColor(.blue)
                
                Text("cannot_access_after_logout:")
                Text(NSLocalizedString("cannot_access_after_logout", comment: ""))
                    .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Localization Test")
    }
}

#Preview {
    LocalizationTestView()
}