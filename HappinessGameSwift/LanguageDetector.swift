import Foundation

enum DetectedLanguage {
    case japanese
    case korean
    case chinese
    case english
    case other
}

class LanguageDetector {
    static let shared = LanguageDetector()
    
    private init() {}
    
    /// タイトルから言語を判定する
    func detectLanguage(from text: String) -> DetectedLanguage {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return .other }
        
        // 韓国語の判定（ハングル）- 最優先で判定
        let koreanRegex = try! NSRegularExpression(pattern: "[\\uAC00-\\uD7AF\\u1100-\\u11FF\\u3130-\\u318F]")
        let koreanMatches = koreanRegex.numberOfMatches(in: cleanText, range: NSRange(cleanText.startIndex..., in: cleanText))
        
        if koreanMatches > 0 {
            return .korean
        }
        
        // 日本語固有文字の判定（ひらがな・カタカナ）
        let hiraganaRegex = try! NSRegularExpression(pattern: "[\\u3040-\\u309F]")
        let katakanaRegex = try! NSRegularExpression(pattern: "[\\u30A0-\\u30FF]")
        let hiraganaMatches = hiraganaRegex.numberOfMatches(in: cleanText, range: NSRange(cleanText.startIndex..., in: cleanText))
        let katakanaMatches = katakanaRegex.numberOfMatches(in: cleanText, range: NSRange(cleanText.startIndex..., in: cleanText))
        
        // ひらがな・カタカナがあれば間違いなく日本語
        if hiraganaMatches > 0 || katakanaMatches > 0 {
            return .japanese
        }
        
        // 漢字の判定
        let chineseRegex = try! NSRegularExpression(pattern: "[\\u4E00-\\u9FFF]")
        let chineseMatches = chineseRegex.numberOfMatches(in: cleanText, range: NSRange(cleanText.startIndex..., in: cleanText))
        
        // 英語（ラテン文字）の判定
        let englishRegex = try! NSRegularExpression(pattern: "[a-zA-Z]")
        let englishMatches = englishRegex.numberOfMatches(in: cleanText, range: NSRange(cleanText.startIndex..., in: cleanText))
        
        let totalLength = cleanText.count
        let chineseRatio = Double(chineseMatches) / Double(totalLength)
        let englishRatio = Double(englishMatches) / Double(totalLength)
        
        // 漢字のみで構成されている場合の判定
        if chineseMatches > 0 && englishMatches == 0 {
            // 日本語でよく使われる漢字や組み合わせを確認
            let japaneseCommonPatterns = [
                "の", "と", "は", "が", "を", "に", "で", "から", "まで", "へ",
                "学園", "学校", "高校", "中学", "小学", "大学", "先生", "生徒",
                "物語", "王子", "姫", "魔法", "勇者", "冒険", "恋愛", "友情",
                "青春", "日常", "学生", "部活", "同級生", "先輩", "後輩"
            ]
            
            let hasJapanesePattern = japaneseCommonPatterns.contains { pattern in
                cleanText.contains(pattern)
            }
            
            if hasJapanesePattern {
                return .japanese
            }
            
            // 中国語特有のパターンがある場合は中国語と判定
            let chineseCommonPatterns = ["之", "的", "是", "在", "有", "个", "我", "你", "他", "她", "们"]
            let hasChinesePattern = chineseCommonPatterns.contains { pattern in
                cleanText.contains(pattern)
            }
            
            if hasChinesePattern {
                return .chinese
            }
            
            // パターンで判定できない場合、漢字が多ければ中国語、少なければ日本語と仮定
            return chineseRatio > 0.8 ? .chinese : .japanese
        }
        
        // 英語の判定
        if englishRatio > 0.7 {
            return .english
        }
        
        // その他の場合
        return .other
    }
    
    /// 現在のアプリの言語設定を取得
    func getCurrentAppLanguage() -> DetectedLanguage {
        // LocalizationManagerから実際のアプリ言語を取得
        let currentLanguage = LocalizationManager.shared.currentLanguage
        
        switch currentLanguage {
        case .japanese:
            return .japanese
        case .korean:
            return .korean
        case .simplifiedChinese:
            return .chinese
        case .english:
            return .english
        case .french, .german, .italian, .spanish, .portuguese:
            return .other
        }
    }
    
    /// タイトルが現在の言語設定に適合するかチェック
    func isTitleMatchingCurrentLanguage(_ title: String) -> Bool {
        let detectedLanguage = detectLanguage(from: title)
        let currentLanguage = getCurrentAppLanguage()
        
        // 同じ言語の場合は表示
        if detectedLanguage == currentLanguage {
            return true
        }
        
        // "other" の場合は表示（言語判定できない場合）
        if detectedLanguage == .other {
            return true
        }
        
        // 日本語設定で中国語（漢字のみ）の場合は表示
        if currentLanguage == .japanese && detectedLanguage == .chinese {
            return true
        }
        
        // 中国語設定で日本語（漢字を含む）の場合も表示
        if currentLanguage == .chinese && detectedLanguage == .japanese {
            return true
        }
        
        return false
    }
    
    /// デバッグ用：タイトルと判定結果を出力
    func debugLanguageDetection(title: String) {
        let detected = detectLanguage(from: title)
        let current = getCurrentAppLanguage()
        let shouldShow = isTitleMatchingCurrentLanguage(title)
        let localizationLang = LocalizationManager.shared.currentLanguage.rawValue
        let localeLang: String
        if #available(iOS 16, *) {
            localeLang = Locale.current.language.languageCode?.identifier ?? "unknown"
        } else {
            #if compiler(>=5.5)
            localeLang = Locale.current.languageCode ?? "unknown"
            #else
            localeLang = Locale.current.languageCode ?? "unknown"
            #endif
        }
        
        // print("🔍 Language Detection Debug:")
        print("  Title: \"\(title)\"")
        print("  Detected: \(detected)")
        print("  Current App Language: \(current)")
        print("  LocalizationManager Language: \(localizationLang)")
        print("  Locale Language: \(localeLang)")
        print("  Should Show: \(shouldShow)")
        print("---")
    }
}