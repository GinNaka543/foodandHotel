import Foundation

class CurrencyManager: ObservableObject {
    static let shared = CurrencyManager()
    
    @Published var selectedCurrency: String = UserDefaults.standard.string(forKey: "selectedCurrency") ?? "JPY" {
        didSet {
            UserDefaults.standard.set(selectedCurrency, forKey: "selectedCurrency")
        }
    }
    
    private init() {}
    
    // Available currencies
    let availableCurrencies = ["JPY", "USD", "EUR", "GBP", "KRW", "CNY"]
    
    var currentLocale: Locale {
        return Locale(identifier: Locale.current.identifier)
    }
    
    var currencyCode: String {
        return selectedCurrency
    }
    
    var currencySymbol: String {
        switch selectedCurrency {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "KRW": return "₩"
        case "CNY": return "¥"
        case "JPY": return "¥"
        default: return "¥"
        }
    }
    
    func formatPrice(_ amount: Int) -> String {
        let convertedAmount = convertFromYen(amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = selectedCurrency
        formatter.currencySymbol = currencySymbol
        
        // For CNY and JPY, show no decimal places
        if selectedCurrency == "JPY" || selectedCurrency == "CNY" || selectedCurrency == "KRW" {
            formatter.maximumFractionDigits = 0
        }
        
        return formatter.string(from: NSNumber(value: convertedAmount)) ?? "\(currencySymbol)\(convertedAmount)"
    }
    
    func formatPriceWithoutSymbol(_ amount: Int) -> String {
        let convertedAmount = convertFromYen(amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        
        // For CNY and JPY, show no decimal places
        if selectedCurrency == "JPY" || selectedCurrency == "CNY" || selectedCurrency == "KRW" {
            formatter.maximumFractionDigits = 0
        } else {
            formatter.maximumFractionDigits = 2
        }
        
        return formatter.string(from: NSNumber(value: convertedAmount)) ?? "\(convertedAmount)"
    }
    
    private func convertFromYen(_ yenAmount: Int) -> Double {
        // Base conversion rates (approximate)
        switch currencyCode {
        case "GBP":
            return Double(yenAmount) * 0.0052 // 1 JPY ≈ 0.0052 GBP
        case "USD":
            return Double(yenAmount) * 0.0067 // 1 JPY ≈ 0.0067 USD
        case "EUR":
            return Double(yenAmount) * 0.0061 // 1 JPY ≈ 0.0061 EUR
        case "KRW":
            return Double(yenAmount) * 8.9 // 1 JPY ≈ 8.9 KRW
        case "CNY":
            return Double(yenAmount) * 0.049 // 1 JPY ≈ 0.049 CNY
        default:
            return Double(yenAmount) // Keep as JPY
        }
    }
    
    func convertToYen(_ amount: Double) -> Int {
        // Convert from selected currency to JPY for storage
        switch currencyCode {
        case "GBP":
            return Int(amount / 0.0052)
        case "USD":
            return Int(amount / 0.0067)
        case "EUR":
            return Int(amount / 0.0061)
        case "KRW":
            return Int(amount / 8.9)
        case "CNY":
            return Int(amount / 0.049)
        default:
            return Int(amount) // Already in JPY
        }
    }
    
    func getLocalizedCurrencyName() -> String {
        switch currencyCode {
        case "GBP":
            return NSLocalizedString("British Pound", comment: "British Pound")
        case "USD":
            return NSLocalizedString("US Dollar", comment: "US Dollar")
        case "EUR":
            return NSLocalizedString("Euro", comment: "Euro")
        case "KRW":
            return NSLocalizedString("Korean Won", comment: "Korean Won")
        case "CNY":
            return NSLocalizedString("Chinese Yuan", comment: "Chinese Yuan")
        default:
            return NSLocalizedString("Japanese Yen", comment: "Japanese Yen")
        }
    }
    
    func getCurrencyFlag() -> String {
        switch currencyCode {
        case "GBP": return "🇬🇧"
        case "USD": return "🇺🇸"
        case "EUR": return "🇪🇺"
        case "KRW": return "🇰🇷"
        case "CNY": return "🇨🇳"
        case "JPY": return "🇯🇵"
        default: return ""
        }
    }
}