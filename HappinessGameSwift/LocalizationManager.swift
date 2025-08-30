import Foundation
import SwiftUI

// サポートする言語
enum AppLanguage: String, CaseIterable {
    case japanese = "ja"
    
    var displayName: String {
        switch self {
        case .japanese: return "日本語"
        }
    }
    
    var flag: String {
        switch self {
        case .japanese: return "🇯🇵"
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
        // 常に日本語に設定
        self.currentLanguage = .japanese
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: "selectedLanguage")
        
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
        return objc_getAssociatedObject(self, &bundleKey) as? String ?? "ja"
    }
}