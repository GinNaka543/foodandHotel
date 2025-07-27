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
                    Text("Privacy Policy")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 10)
                    
                    Group {
                        PrivacySectionView(
                            title: "1. Information We Collect",
                            content: """
                            The App "ANICOLLE!" collects the following information:
                            
                            • User registration information (username, user ID)
                            • Content created within the app (character, anime records)
                            • Device information (device ID, OS version)
                            • App usage (login times, feature usage frequency)
                            • Payment information (payment info through Stripe, but credit card numbers are not stored)
                            
                            Note: We do not collect email addresses
                            """
                        )
                        
                        PrivacySectionView(
                            title: "2. Purpose of Information Use",
                            content: """
                            The collected information is used only for the following purposes:
                            
                            • Providing basic app functionality
                            • User authentication and account management
                            • Payment and point management
                            • Backing up character and anime information (for data recovery)
                            • App improvement and customer support
                            • Responding to legal requirements
                            
                            Note: Character and anime information you register is stored on servers solely for backup purposes, allowing data recovery in case of device failure or replacement.
                            """
                        )
                        
                        PrivacySectionView(
                            title: "3. Data Storage and Management",
                            content: """
                            • User-created content (character, anime information) is securely stored on Firebase servers for backup purposes
                            • This system allows data recovery without loss in the following cases:
                              - Device failure or loss
                              - App reinstallation
                              - Device replacement
                            • Authentication information, point information, and payment information are also managed on Firebase servers
                            • All communications are encrypted with HTTPS
                            • Users can delete their data at any time
                            • Backup data is stored linked to user accounts and cannot be accessed by other users
                            """
                        )
                        
                        PrivacySectionView(
                            title: "4. Information Disclosure to Third Parties",
                            content: """
                            We do not provide users' personal information to third parties except in the following cases:
                            
                            • When user consent is obtained
                            • When disclosure is required by law
                            • When necessary to protect life, body, or property
                            """
                        )
                        
                        PrivacySectionView(
                            title: "5. Security",
                            content: """
                            We implement the following measures to properly protect user information:
                            
                            • Encryption through HTTPS communication
                            • Secure authentication with Firebase Authentication
                            • Proper API key management
                            • Regular security updates
                            """
                        )
                        
                        PrivacySectionView(
                            title: "6. Cookies and Tracking",
                            content: """
                            • This app does not use cookies to improve user experience
                            • We do not track for advertising purposes
                            • App usage statistics are collected in anonymized form
                            • Collected character and anime information is not used for purposes other than backup and recovery
                            """
                        )
                        
                        PrivacySectionView(
                            title: "7. Data Backup and Recovery",
                            content: """
                            We provide the following backup features to protect your valuable data:
                            
                            • Automatic backup: Automatically saved to servers when registering or editing characters and anime
                            • Data recovery: Automatically restored from backup data upon login
                            • Purpose of backup:
                              - Data protection in case of device failure or loss
                              - Data recovery when app is deleted and reinstalled
                              - Data migration when changing devices
                            
                            Important: This backup data is used solely for protecting your data and is never used for other purposes (marketing, analysis, provision to third parties, etc.).
                            """
                        )
                        
                        PrivacySectionView(
                            title: "8. Children's Privacy",
                            content: """
                            This app is not intended for children under 13 years old. Those under 13 should obtain parental consent before use.
                            """
                        )
                        
                        PrivacySectionView(
                            title: "9. Changes to Privacy Policy",
                            content: """
                            We may change our privacy policy as necessary. In case of significant changes, we will notify users within the app.
                            """
                        )
                        
                        PrivacySectionView(
                            title: "10. Contact Us",
                            content: """
                            For privacy-related inquiries, please contact us at:
                            
                            Email: fneko543@gmail.com
                            """
                        )
                    }
                    
                    Text("Last Updated: July 24, 2025")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    LanguageButton()
                }
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
                            Text("Agree and Start Using the App")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        
                        Text("By agreeing to the Privacy Policy, you can start using the app")
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