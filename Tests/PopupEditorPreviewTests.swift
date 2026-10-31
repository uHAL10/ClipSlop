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

        state.selectHistoryStep(at: -1)
        state.navigateInto(prompt)
        #expect(state.currentSession?.steps.count == 2)
        #expect(state.currentSession?.steps.last?.sourceStepID == nil)
        #expect(state.currentSession?.steps.last?.inputText == input)

        state.promptSearchState.activate()
        state.promptSearchState.query = prompt.name
        #expect(state.promptSearchState.results.contains { $0.node.id == prompt.id })
    }

@Test(.enabled(if: ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"))
func promptSavesDraftFromSelectedHistory() throws {
    let state = AppState()
    state.currentSession = TransformationSession(originalText: "original")
        .addingStep(promptName: "first", outputText: "previous")
        .addingStep(promptName: "later", outputText: "later")
    state.selectHistoryStep(at: 0)
    state.editingText = "draft"

    state.applyPrompt(name: "prompt", systemPrompt: "instruction")

    let steps = try #require(state.currentSession?.steps)
    #expect(steps.count == 4)
    #expect(steps[2].inputText == "previous")
    #expect(steps[2].outputText == "draft")
    #expect(steps[2].sourceStepID == steps[0].id)
    #expect(steps[3].inputText == "draft")
    #expect(steps[3].sourceStepID == steps[2].id)
    #expect(steps[3].outputText == "Preview: prompt\n\ndraft")
    #expect(!state.hasUnappliedEdit)
}

    @Test(.enabled(if: ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"))
    func normalRunUsesStandardPreferences() {
        #expect(!Constants.isPreview)
        #expect(Constants.userDefaults === UserDefaults.standard)
    }
}
#endif
