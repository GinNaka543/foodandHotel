import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Terms of Service")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 10)
                    
                    Text("Last Updated: July 23, 2025")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Group {
                        Text("Article 1 (Application of Terms of Service)")
                            .font(.headline)
                        Text("These Terms of Service (hereinafter referred to as \"Terms\") set forth the conditions for the use of ANICOLLE! (hereinafter referred to as \"the App\") between users of the App (hereinafter referred to as \"Users\") and the operator.")
                            .font(.body)
                    }
                    
                    Group {
                        Text("Article 2 (User Registration)")
                            .font(.headline)
                        Text("1. Users shall register for use in accordance with the prescribed method after agreeing to these Terms.\n2. If false information is provided during registration, the registration may be cancelled.")
                            .font(.body)
                    }
                    
                    Group {
                        Text("Article 3 (Management of User ID and Password)")
                            .font(.headline)
                        Text("1. Users shall appropriately manage their User ID and password for the App at their own responsibility.\n2. The operator assumes no responsibility for any damages resulting from the use of User IDs and passwords by third parties.")
                            .font(.body)
                    }
                    
                    Group {
                        Text("Article 4 (Usage Fees)")
                            .font(.headline)
                        Text("1. The App can be used free of charge for 2 months from initial registration.\n2. After the free period ends, a usage fee of 600 yen (tax included) is required to continue using the App.\n3. If the usage fee is not paid, some or all functions of the App may be restricted.\n4. Usage fees once paid will not be refunded for any reason.")
                            .font(.body)
                    }
                    
                    Group {
                        Text("Article 5 (Prohibited Activities)")
                            .font(.headline)
                        Text("Users shall not engage in the following activities when using the App:\n• Activities that violate laws or public order and morals\n• Activities related to criminal acts\n• Activities that may interfere with the operation of the App\n• Activities that collect or accumulate personal information about other users\n• Activities that involve unauthorized access or attempts thereof\n• Activities impersonating other users\n• Activities that directly or indirectly provide benefits to antisocial forces in connection with the App")
                            .font(.body)
                    }
                    
                    Group {
                        Text("Article 6 (Suspension of App Services)")
                            .font(.headline)
                        Text("The operator may suspend or interrupt all or part of the App services without prior notice to users if any of the following circumstances are deemed to exist:\n• When performing maintenance, inspection, or updates of the computer system related to the App\n• When it becomes difficult to provide the App due to force majeure such as earthquakes, lightning, fire, power outages, or natural disasters\n• When computers or communication lines are stopped due to accidents")
                            .font(.body)
                    }
                    
                    Group {
                        Text("Article 7 (Copyright)")
                            .font(.headline)
                        Text("1. The copyright of content (text, images, videos, audio, etc.) provided within the App belongs to the operator or legitimate rights holders.\n2. Users may not use the App's content beyond the scope of personal use.")
                            .font(.body)
                    }
                    
                    Group {
                        Text("Article 8 (Disclaimer)")
                            .font(.headline)
                        Text("1. While every effort is made to ensure the accuracy of information posted on the App, the operator does not guarantee the accuracy, usefulness, or timeliness of the App's information.\n2. The operator assumes no responsibility for any damages incurred by users through the use of the App.")
                            .font(.body)
                    }
                    
                    Group {
                        Text("Article 9 (Collection and Sharing of Information)")
                            .font(.headline)
                        Text("1. The App may collect text information about users' favorite anime and voice actor characters registered by users, and use it to improve services and provide sharing functions with other users.\n2. By using the App, users are deemed to have consented to the above information collection and sharing.\n3. Other personal information will be handled appropriately in accordance with the separately established Privacy Policy.")
                            .font(.body)
                    }
                    
                    Group {
                        Text("Article 10 (Usage Method)")
                            .font(.headline)
                        Text("When changing devices, user text information will be saved, but images will not be saved. After logging in on a new device, images will need to be uploaded again.")
                            .font(.body)
                    }
                    
                    Group {
                        Text("Article 11 (Privacy Policy)")
                            .font(.headline)
                        Text("Personal information obtained through the use of the App will be handled appropriately in accordance with the separately established Privacy Policy.")
                            .font(.body)
                    }
                    
                    Group {
                        Text("Article 12 (Changes to Terms of Service)")
                            .font(.headline)
                        Text("The operator may change these Terms without notifying users when deemed necessary. The revised Terms shall take effect when posted within the App.")
                            .font(.body)
                    }
                    
                    Group {
                        Text("Article 13 (Governing Law and Jurisdiction)")
                            .font(.headline)
                        Text("1. These Terms shall be governed by Japanese law.\n2. Any disputes arising in connection with the App shall be subject to the exclusive jurisdiction of the court having jurisdiction over the location of the operator's head office.")
                            .font(.body)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    LanguageButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("close", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    TermsOfServiceView()
}