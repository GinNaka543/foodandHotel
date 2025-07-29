import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var hasAgreed: Bool
    let isInitialAgreement: Bool
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(NSLocalizedString("privacy_policy_title", comment: ""))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 10)
                    
                    Group {
                        PrivacySectionView(
                            title: NSLocalizedString("privacy_info_we_collect_title", comment: ""),
                            content: NSLocalizedString("privacy_info_we_collect_content", comment: "")
                        )
                        
                        PrivacySectionView(
                            title: NSLocalizedString("privacy_purpose_title", comment: ""),
                            content: NSLocalizedString("privacy_purpose_content", comment: "")
                        )
                        
                        PrivacySectionView(
                            title: NSLocalizedString("privacy_data_storage_title", comment: ""),
                            content: NSLocalizedString("privacy_data_storage_content", comment: "")
                        )
                        
                        PrivacySectionView(
                            title: NSLocalizedString("privacy_disclosure_title", comment: ""),
                            content: NSLocalizedString("privacy_disclosure_content", comment: "")
                        )
                        
                        PrivacySectionView(
                            title: NSLocalizedString("privacy_security_title", comment: ""),
                            content: NSLocalizedString("privacy_security_content", comment: "")
                        )
                        
                        PrivacySectionView(
                            title: NSLocalizedString("privacy_cookies_title", comment: ""),
                            content: NSLocalizedString("privacy_cookies_content", comment: "")
                        )
                        
                        PrivacySectionView(
                            title: NSLocalizedString("privacy_backup_title", comment: ""),
                            content: NSLocalizedString("privacy_backup_content", comment: "")
                        )
                        
                        PrivacySectionView(
                            title: NSLocalizedString("privacy_children_title", comment: ""),
                            content: NSLocalizedString("privacy_children_content", comment: "")
                        )
                        
                        PrivacySectionView(
                            title: NSLocalizedString("privacy_changes_title", comment: ""),
                            content: NSLocalizedString("privacy_changes_content", comment: "")
                        )
                        
                        PrivacySectionView(
                            title: NSLocalizedString("privacy_contact_title", comment: ""),
                            content: NSLocalizedString("privacy_contact_content", comment: "")
                        )
                    }
                    
                    Text(NSLocalizedString("privacy_last_updated", comment: ""))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isInitialAgreement {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(NSLocalizedString("close", comment: "")) {
                            dismiss()
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isInitialAgreement {
                    VStack(spacing: 16) {
                        Button(action: {
                            hasAgreed = true
                            UserDefaults.standard.set(true, forKey: "hasAgreedToPrivacyPolicy")
                            dismiss()
                        }) {
                            Text(NSLocalizedString("privacy_agree_and_start", comment: ""))
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        
                        Text(NSLocalizedString("privacy_agree_description", comment: ""))
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                }
            }
        }
    }
}

struct PrivacySectionView: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct PrivacyPolicyView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacyPolicyView(hasAgreed: .constant(false), isInitialAgreement: true)
    }
}