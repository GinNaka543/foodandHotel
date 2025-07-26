import Foundation
import SwiftUI

// サポートする言語
enum AppLanguage: String, CaseIterable {
    case japanese = "ja"
    case english = "en"
    case french = "fr"
    case german = "de"
    case korean = "ko"
    case simplifiedChinese = "zh-Hans"
    case italian = "it"
    case spanish = "es"
    case portuguese = "pt"
    
    var displayName: String {
        switch self {
        case .japanese: return "日本語"
        case .english: return "English"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .korean: return "한국어"
        case .simplifiedChinese: return "简体中文"
        case .italian: return "Italiano"
        case .spanish: return "Español"
        case .portuguese: return "Português"
        }
    }
    
    var flag: String {
        switch self {
        case .japanese: return "🇯🇵"
        case .english: return "🇺🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .korean: return "🇰🇷"
        case .simplifiedChinese: return "🇨🇳"
        case .italian: return "🇮🇹"
        case .spanish: return "🇪🇸"
        case .portuguese: return "🇵🇹"
        }
    }
}

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "selectedLanguage")
            Bundle.setLanguage(currentLanguage.rawValue)
        }
    }
    
    init() {
        // 保存された言語設定を読み込む
        if let savedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage"),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
            Bundle.setLanguage(language.rawValue)
        } else {
            // デバイスの言語設定から初期言語を決定
            let deviceLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            
            // デバイスの言語がサポートされているか確認
            if let matchedLanguage = AppLanguage.allCases.first(where: { 
                $0.rawValue == deviceLanguage || 
                $0.rawValue.hasPrefix(deviceLanguage) ||
                deviceLanguage.hasPrefix($0.rawValue)
            }) {
                self.currentLanguage = matchedLanguage
            } else {
                // デフォルトは英語
                self.currentLanguage = .english
            }
            Bundle.setLanguage(currentLanguage.rawValue)
        }
    }
    
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
    }
}

// Bundle拡張で言語切り替えを実装
extension Bundle {
    private static var bundle: Bundle!
    
    static func setLanguage(_ language: String) {
        defer {
            object_setClass(Bundle.main, AliasBundle.self)
        }
        
        objc_setAssociatedObject(
            Bundle.main,
            &kBundleKey,
            language,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
    
    private struct kBundleKey {
        // Intentionally left blank
    }
}

class AliasBundle: Bundle {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let path = Bundle.main.path(
            forResource: currentLanguage,
            ofType: "lproj"
        ) else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        
        guard let bundle = Bundle(path: path) else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
    
    private var currentLanguage: String {
        return objc_getAssociatedObject(self, &kBundleKey) as? String ?? "en"
    }
    
    private struct kBundleKey {
        // Intentionally left blank
    }
}