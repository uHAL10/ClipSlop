import AppKit
import Testing
@testable import ClipSlop

@Suite("Japanese localization")
@MainActor
struct JapaneseLocalizationTests {
    @Test("Japanese can be selected and loads localized strings")
    func japaneseLoads() {
        let loc = Loc.shared
        let originalLanguage = loc.language
        let originalPreference = UserDefaults.standard.object(forKey: "appLanguage")
        defer {
            loc.language = originalLanguage
            if let originalPreference {
                UserDefaults.standard.set(originalPreference, forKey: "appLanguage")
            } else {
                UserDefaults.standard.removeObject(forKey: "appLanguage")
            }
        }

        #expect(AppLanguage(rawValue: "ja") == .ja)
        #expect(AppLanguage.ja.nativeName == "日本語")
        loc.language = .ja
        #expect(UserDefaults.standard.string(forKey: "appLanguage") == "ja")
        #expect(loc.t("settings.general.language") == "言語")
        #expect(loc.t("settings.prompts.delete_title", "テスト") == "「テスト」を削除しますか？")
        #expect(loc.t("popup.find.count", 2, 5) == "5 件中 2 件目")
        #expect(loc.t("settings.prompts.shortcut_conflict_message", "⌘A", "名前", "実行")
            == "⌘A は現在「名前」（実行）に割り当てられています。別のプロンプトの割り当てを置き換えますか、それともキャンセルしますか？")
    }

    @Test("Marked text is left to the input method")
    func markedText() {
        let textView = NSTextView()
        #expect(!isComposingText(nil))
        #expect(!isComposingText(textView))

        textView.setMarkedText("にほんご", selectedRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(isComposingText(textView))

        textView.unmarkText()
        #expect(!isComposingText(textView))
    }
}
