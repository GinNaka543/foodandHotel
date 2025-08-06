import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(NSLocalizedString("terms_of_service_title", comment: ""))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 10)
                    
                    Text(NSLocalizedString("terms_last_updated", comment: ""))
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Group {
                        Text(NSLocalizedString("terms_article_1_title", comment: ""))
                            .font(.headline)
                        Text(NSLocalizedString("terms_article_1_content", comment: ""))
                            .font(.body)
                    }
                    
                    Group {
                        Text(NSLocalizedString("terms_article_2_title", comment: ""))
                            .font(.headline)
                        Text(NSLocalizedString("terms_article_2_content", comment: ""))
                            .font(.body)
                    }
                    
                    Group {
                        Text(NSLocalizedString("terms_article_3_title", comment: ""))
                            .font(.headline)
                        Text(NSLocalizedString("terms_article_3_content", comment: ""))
                            .font(.body)
                    }
                    
                    Group {
                        Text(NSLocalizedString("terms_article_4_title", comment: ""))
                            .font(.headline)
                        Text(NSLocalizedString("terms_article_4_content", comment: ""))
                            .font(.body)
                    }
                    
                    Group {
                        Text(NSLocalizedString("terms_article_5_title", comment: ""))
                            .font(.headline)
                        Text(NSLocalizedString("terms_article_5_content", comment: ""))
                            .font(.body)
                    }
                    
                    Group {
                        Text(NSLocalizedString("terms_article_6_title", comment: ""))
                            .font(.headline)
                        Text(NSLocalizedString("terms_article_6_content", comment: ""))
                            .font(.body)
                    }
                    
                    Group {
                        Text(NSLocalizedString("terms_article_7_title", comment: ""))
                            .font(.headline)
                        Text(NSLocalizedString("terms_article_7_content", comment: ""))
                            .font(.body)
                    }
                    
                    Group {
                        Text(NSLocalizedString("terms_article_8_title", comment: ""))
                            .font(.headline)
                        Text(NSLocalizedString("terms_article_8_content", comment: ""))
                            .font(.body)
                    }
                    
                    Group {
                        Text(NSLocalizedString("terms_article_9_title", comment: ""))
                            .font(.headline)
                        Text(NSLocalizedString("terms_article_9_content", comment: ""))
                            .font(.body)
                    }
                    
                    Group {
                        Text(NSLocalizedString("terms_article_10_title", comment: ""))
                            .font(.headline)
                        Text(NSLocalizedString("terms_article_10_content", comment: ""))
                            .font(.body)
                    }
                    
                    Group {
                        Text(NSLocalizedString("terms_article_11_title", comment: ""))
                            .font(.headline)
                        Text(NSLocalizedString("terms_article_11_content", comment: ""))
                            .font(.body)
                    }
                    
                    Group {
                        Text(NSLocalizedString("terms_article_12_title", comment: ""))
                            .font(.headline)
                        Text(NSLocalizedString("terms_article_12_content", comment: ""))
                            .font(.body)
                    }
                    
                    Group {
                        Text(NSLocalizedString("terms_article_13_title", comment: ""))
                            .font(.headline)
                        Text(NSLocalizedString("terms_article_13_content", comment: ""))
                            .font(.body)
                    }
                    
                    // デバイス間同期の制限について
                    Group {
                        Text(NSLocalizedString("terms_article_14_title", comment: ""))
                            .font(.headline)
                            .padding(.top)
                        Text(NSLocalizedString("terms_article_14_content", comment: ""))
                            .font(.body)
                            .foregroundColor(.red)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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