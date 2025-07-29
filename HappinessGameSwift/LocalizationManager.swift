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
        } else {
            // デバイスの言語設定から初期言語を決定
            let deviceLanguage = Locale.current.languageCode ?? "en"
            
            // デバイスの言語がサポートされているか確認
            if let matchedLanguage = AppLanguage.allCases.first(where: { 
                $0.rawValue == deviceLanguage || 
                $0.rawValue.hasPrefix(deviceLanguage) ||
                deviceLanguage.hasPrefix($0.rawValue)
            }) {
                self.currentLanguage = matchedLanguage
            } else {
                // デフォルトは日本語（このアプリは日本語ベース）
                self.currentLanguage = .japanese
            }
            
            // 初期言語を保存
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "selectedLanguage")
        }
        
        // Bundle言語設定を適用
        Bundle.setLanguage(currentLanguage.rawValue)
    }
    
    func setLanguage(_ language: AppLanguage, shouldRestart: Bool = true, completion: (() -> Void)? = nil) {
        currentLanguage = language
        
        // 初回起動時はアプリを再起動しない
        if shouldRestart && UserDefaults.standard.bool(forKey: "hasSelectedLanguage") {
            // アプリを再起動する代わりに、アプリ全体を更新
            NotificationCenter.default.post(name: Notification.Name("LanguageDidChange"), object: nil)
            
            // 少し遅延を入れてから完了を通知
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                completion?()
            }
        } else {
            completion?()
        }
    }
}

// Bundle拡張で言語切り替えを実装
private var bundleKey: UInt8 = 0

extension Bundle {
    private static var bundle: Bundle!
    
    static func setLanguage(_ language: String) {
        let setLanguageWork = {
            defer {
                object_setClass(Bundle.main, AliasBundle.self)
            }
            
            objc_setAssociatedObject(
                Bundle.main,
                &bundleKey,
                language,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
        
        // Execute on main thread if not already on it
        if Thread.isMainThread {
            setLanguageWork()
        } else {
            DispatchQueue.main.sync {
                setLanguageWork()
            }
        }
    }
}

class AliasBundle: Bundle, @unchecked Sendable {
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
        return objc_getAssociatedObject(self, &bundleKey) as? String ?? "en"
    }
}