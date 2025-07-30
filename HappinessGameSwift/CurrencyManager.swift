import Foundation

class CurrencyManager: ObservableObject {
    static let shared = CurrencyManager()
    
    @Published var selectedCurrency: String = UserDefaults.standard.string(forKey: "selectedCurrency") ?? "JPY" {
        didSet {
            UserDefaults.standard.set(selectedCurrency, forKey: "selectedCurrency")
        }
    }
    
    private init() {}
    
    // Available currencies - includes major world currencies
    let availableCurrencies = ["JPY", "USD", "EUR", "GBP", "KRW", "CNY", "AUD", "CAD", "CHF", "HKD", "SGD", "TWD"]
    
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
        case "AUD": return "A$"
        case "CAD": return "C$"
        case "CHF": return "Fr"
        case "HKD": return "HK$"
        case "SGD": return "S$"
        case "TWD": return "NT$"
        default: return "¥"
        }
    }
    
    func formatPrice(_ amount: Int) -> String {
        let convertedAmount = convertFromYen(amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = selectedCurrency
        formatter.currencySymbol = currencySymbol
        
        // For Asian currencies, show no decimal places
        if selectedCurrency == "JPY" || selectedCurrency == "CNY" || selectedCurrency == "KRW" || selectedCurrency == "TWD" {
            formatter.maximumFractionDigits = 0
        }
        
        return formatter.string(from: NSNumber(value: convertedAmount)) ?? "\(currencySymbol)\(convertedAmount)"
    }
    
    func formatPriceWithoutSymbol(_ amount: Int) -> String {
        let convertedAmount = convertFromYen(amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        
        // For Asian currencies, show no decimal places
        if selectedCurrency == "JPY" || selectedCurrency == "CNY" || selectedCurrency == "KRW" || selectedCurrency == "TWD" {
            formatter.maximumFractionDigits = 0
        } else {
            formatter.maximumFractionDigits = 2
        }
        
        return formatter.string(from: NSNumber(value: convertedAmount)) ?? "\(convertedAmount)"
    }
    
    func convertFromYen(_ yenAmount: Int) -> Double {
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
        case "AUD":
            return Double(yenAmount) * 0.0102 // 1 JPY ≈ 0.0102 AUD
        case "CAD":
            return Double(yenAmount) * 0.0091 // 1 JPY ≈ 0.0091 CAD
        case "CHF":
            return Double(yenAmount) * 0.0058 // 1 JPY ≈ 0.0058 CHF
        case "HKD":
            return Double(yenAmount) * 0.052 // 1 JPY ≈ 0.052 HKD
        case "SGD":
            return Double(yenAmount) * 0.0089 // 1 JPY ≈ 0.0089 SGD
        case "TWD":
            return Double(yenAmount) * 0.215 // 1 JPY ≈ 0.215 TWD
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
        case "AUD":
            return Int(amount / 0.0102)
        case "CAD":
            return Int(amount / 0.0091)
        case "CHF":
            return Int(amount / 0.0058)
        case "HKD":
            return Int(amount / 0.052)
        case "SGD":
            return Int(amount / 0.0089)
        case "TWD":
            return Int(amount / 0.215)
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
        case "AUD":
            return NSLocalizedString("Australian Dollar", comment: "Australian Dollar")
        case "CAD":
            return NSLocalizedString("Canadian Dollar", comment: "Canadian Dollar")
        case "CHF":
            return NSLocalizedString("Swiss Franc", comment: "Swiss Franc")
        case "HKD":
            return NSLocalizedString("Hong Kong Dollar", comment: "Hong Kong Dollar")
        case "SGD":
            return NSLocalizedString("Singapore Dollar", comment: "Singapore Dollar")
        case "TWD":
            return NSLocalizedString("Taiwan Dollar", comment: "Taiwan Dollar")
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
        case "AUD": return "🇦🇺"
        case "CAD": return "🇨🇦"
        case "CHF": return "🇨🇭"
        case "HKD": return "🇭🇰"
        case "SGD": return "🇸🇬"
        case "TWD": return "🇹🇼"
        default: return "🌍"
        }
    }
}