import SwiftUI

struct InitialCurrencySelectionView: View {
    @Binding var isPresented: Bool
    @Binding var selectedCurrency: String
    let onCurrencySelected: () -> Void
    @StateObject private var currencyManager = CurrencyManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with confirm button
                HStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                        onCurrencySelected()
                    }) {
                        Text(NSLocalizedString("confirm", comment: "Confirm"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(20)
                    }
                    .opacity(selectedCurrency.isEmpty ? 0.5 : 1.0)
                    .disabled(selectedCurrency.isEmpty)
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }
                
                VStack(spacing: 12) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.purple)
                        .padding(.top, 20)
                    
                    Text(NSLocalizedString("please_select_currency", comment: "Please select currency"))
                        .font(.system(size: 20, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 20)
                }
                
                // Currency list
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(currencyManager.availableCurrencies, id: \.self) { currency in
                            Button(action: {
                                selectedCurrency = currency
                            }) {
                                HStack {
                                    Text(getCurrencyFlag(for: currency))
                                        .font(.system(size: 32))
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(currency)
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(.primary)
                                            
                                            Text("(\(getCurrencySymbol(for: currency)))")
                                                .font(.system(size: 16))
                                                .foregroundColor(.gray)
                                        }
                                        
                                        Text(getCurrencyName(for: currency))
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedCurrency == currency {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.blue)
                                    } else {
                                        Image(systemName: "circle")
                                            .font(.system(size: 24))
                                            .foregroundColor(.gray.opacity(0.3))
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                            }
                            
                            if currency != currencyManager.availableCurrencies.last {
                                Divider()
                                    .padding(.leading, 84)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Spacer()
                
                // Cancel button
                Button(action: {
                    isPresented = false
                }) {
                    Text(NSLocalizedString("cancel", comment: "Cancel"))
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .padding(.vertical, 16)
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private func getCurrencyFlag(for currency: String) -> String {
        switch currency {
        case "GBP": return "🇬🇧"
        case "USD": return "🇺🇸"
        case "EUR": return "🇪🇺"
        case "KRW": return "🇰🇷"
        case "CNY": return "🇨🇳"
        case "JPY": return "🇯🇵"
        case "AUD": return "🇦🇺"
        case "CAD": return "🇨🇦"
        case "CHF": return "🇨🇭"
        case "HKD": return "🇭🇰"
        case "SGD": return "🇸🇬"
        case "TWD": return "🇹🇼"
        default: return "🌍"
        }
    }
    
    private func getCurrencySymbol(for currency: String) -> String {
        switch currency {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "KRW": return "₩"
        case "CNY": return "¥"
        case "JPY": return "¥"
        case "AUD": return "A$"
        case "CAD": return "C$"
        case "CHF": return "Fr"
        case "HKD": return "HK$"
        case "SGD": return "S$"
        case "TWD": return "NT$"
        default: return ""
        }
    }
    
    private func getCurrencyName(for currency: String) -> String {
        switch currency {
        case "GBP": return NSLocalizedString("British Pound", comment: "British Pound")
        case "USD": return NSLocalizedString("US Dollar", comment: "US Dollar")
        case "EUR": return NSLocalizedString("Euro", comment: "Euro")
        case "KRW": return NSLocalizedString("Korean Won", comment: "Korean Won")
        case "CNY": return NSLocalizedString("Chinese Yuan", comment: "Chinese Yuan")
        case "JPY": return NSLocalizedString("Japanese Yen", comment: "Japanese Yen")
        case "AUD": return NSLocalizedString("Australian Dollar", comment: "Australian Dollar")
        case "CAD": return NSLocalizedString("Canadian Dollar", comment: "Canadian Dollar")
        case "CHF": return NSLocalizedString("Swiss Franc", comment: "Swiss Franc")
        case "HKD": return NSLocalizedString("Hong Kong Dollar", comment: "Hong Kong Dollar")
        case "SGD": return NSLocalizedString("Singapore Dollar", comment: "Singapore Dollar")
        case "TWD": return NSLocalizedString("Taiwan Dollar", comment: "Taiwan Dollar")
        default: return ""
        }
    }
}

struct InitialCurrencySelectionView_Previews: PreviewProvider {
    static var previews: some View {
        InitialCurrencySelectionView(
            isPresented: .constant(true),
            selectedCurrency: .constant("JPY"),
            onCurrencySelected: {}
        )
    }
}