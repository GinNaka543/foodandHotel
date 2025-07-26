import Foundation

class CurrencyManager {
    static let shared = CurrencyManager()
    
    private init() {}
    
    var currentLocale: Locale {
        return Locale.current
    }
    
    var currencyCode: String {
        return currentLocale.currencyCode ?? "JPY"
    }
    
    var currencySymbol: String {
        return currentLocale.currencySymbol ?? "¥"
    }
    
    func formatPrice(_ amount: Int) -> String {
        let convertedAmount = convertFromYen(amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = currentLocale
        
        return formatter.string(from: NSNumber(value: convertedAmount)) ?? "\(currencySymbol)\(convertedAmount)"
    }
    
    func formatPriceWithoutSymbol(_ amount: Int) -> String {
        let convertedAmount = convertFromYen(amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = currentLocale
        
        return formatter.string(from: NSNumber(value: convertedAmount)) ?? "\(convertedAmount)"
    }
    
    private func convertFromYen(_ yenAmount: Int) -> Int {
        // Base conversion rates (approximate)
        switch currencyCode {
        case "GBP":
            return Int(Double(yenAmount) * 0.0052) // 1 JPY ≈ 0.0052 GBP
        case "USD":
            return Int(Double(yenAmount) * 0.0067) // 1 JPY ≈ 0.0067 USD
        case "EUR":
            return Int(Double(yenAmount) * 0.0061) // 1 JPY ≈ 0.0061 EUR
        default:
            return yenAmount // Keep as JPY
        }
    }
    
    func getLocalizedCurrencyName() -> String {
        switch currencyCode {
        case "GBP":
            return NSLocalizedString("pounds", comment: "Pounds")
        case "USD":
            return NSLocalizedString("dollars", comment: "Dollars")
        case "EUR":
            return NSLocalizedString("euros", comment: "Euros")
        default:
            return NSLocalizedString("yen", comment: "Yen")
        }
    }
}