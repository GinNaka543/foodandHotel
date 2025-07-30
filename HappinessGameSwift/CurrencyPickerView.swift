import SwiftUI

struct CurrencyPickerView: View {
    @Binding var isPresented: Bool
    @StateObject private var currencyManager = CurrencyManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(NSLocalizedString("select_currency", comment: "Select Currency"))
                        .font(.system(size: 20, weight: .bold))
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                // Currency list
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(currencyManager.availableCurrencies, id: \.self) { currency in
                            Button(action: {
                                currencyManager.selectedCurrency = currency
                                isPresented = false
                            }) {
                                HStack {
                                    Text(getCurrencyFlag(for: currency))
                                        .font(.system(size: 24))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(currency)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                        Text(getCurrencyName(for: currency))
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    if currencyManager.selectedCurrency == currency {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                            }
                            
                            if currency != currencyManager.availableCurrencies.last {
                                Divider()
                                    .padding(.leading, 64)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Spacer()
                
                // Additional currencies note
                VStack(spacing: 8) {
                    Text(NSLocalizedString("currency_note", comment: "Currency Note"))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    Text(NSLocalizedString("supported_currencies", comment: "Supported currencies: JPY, USD, EUR, GBP, KRW, CNY, AUD, CAD, CHF, HKD, SGD, TWD"))
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 20)
            }
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

struct CurrencyPickerView_Previews: PreviewProvider {
    static var previews: some View {
        CurrencyPickerView(isPresented: .constant(true))
    }
}