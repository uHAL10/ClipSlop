#if DEBUG
import SwiftUI

struct PopupEditorPreview: View {
    @State private var appState = Self.makeState()

    static func makeState() -> AppState {
        precondition(Constants.isPreview, "PopupEditorPreview requires Xcode's preview environment")

        AppSettings.shared.useDefaultPrompts = true
        let state = AppState()
        state.settings.promptLibraryCollapsed = false
        state.currentSession = TransformationSession(originalText: """
            お疲れさまです。

            次回の打ち合わせに向けて、資料をまとめました。
            ご確認をお願いします。
            """)
        state.activeEditorMode = .plainText
        state.originalViewMode = .plainText
        state.promptSearchState.promptStore = state.promptStore
        return state
    }

    var body: some View {
        PopupContentView(appState: appState)
            .frame(width: 950, height: 520)
    }
}
#endif
