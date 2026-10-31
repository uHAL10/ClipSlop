#if DEBUG
import Foundation
import Testing
@testable import ClipSlop

@Suite("Xcode editor preview")
@MainActor
struct PopupEditorPreviewTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"))
    func previewIsIsolatedAndInteractive() throws {
        #expect(Constants.isPreview)
        #expect(Constants.Engine.rootDirectory.deletingLastPathComponent().path == Constants.previewDirectory.path)
        #expect(Constants.appSupportDirectory.deletingLastPathComponent().path == Constants.previewDirectory.path)
        #expect(Constants.userDefaults !== UserDefaults.standard)

        let originalCollapsed = UserDefaults.standard.object(forKey: "promptLibraryCollapsed") as? Bool
        let state = PopupEditorPreview.makeState()
        state.settings.promptLibraryCollapsed.toggle()
        #expect((UserDefaults.standard.object(forKey: "promptLibraryCollapsed") as? Bool) == originalCollapsed)

        let folder = try #require(state.currentPrompts.first { node in
            node.isFolder && (node.children?.contains { $0.isPrompt && $0.systemPrompt != nil } ?? false)
        })
        state.navigateInto(folder)
        let prompt = try #require(state.currentPrompts.first { $0.isPrompt && $0.systemPrompt != nil })
        let input = state.currentDisplayText
        state.navigateInto(prompt)
        #expect(state.currentSession?.steps.last?.promptName == prompt.name)
        #expect(state.currentDisplayText == "Preview: \(prompt.name)\n\n\(input)")
        #expect(!state.isProcessing)

        state.promptSearchState.activate()
        state.promptSearchState.query = prompt.name
        #expect(state.promptSearchState.results.contains { $0.node.id == prompt.id })
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"))
    func normalRunUsesStandardPreferences() {
        #expect(!Constants.isPreview)
        #expect(Constants.userDefaults === UserDefaults.standard)
    }
}
#endif
