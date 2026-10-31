import Testing
@testable import ClipSlop

@Suite("Manual edits")
@MainActor
struct ManualEditTests {
    @Test func draftsAndHistory() throws {
        let state = AppState()
        state.currentSession = TransformationSession(originalText: "original")
            .addingStep(promptName: "AI", outputText: "result")
        state.selectHistoryStep(at: -1)
        #expect(!state.hasUnappliedEdit)
        state.editingText = "changed"
        state.editingText = "original"
        #expect(!state.hasUnappliedEdit)
        state.editingText = "draft"
        #expect(state.hasUnappliedEdit)
        state.selectHistoryStep(at: 0)
        #expect(state.editingText == "result")
        #expect(!state.hasUnappliedEdit)
        state.selectHistoryStep(at: -1)
        #expect(state.editingText == "draft")
        state.saveEdit()
        let session = try #require(state.currentSession)
        #expect(session.steps.count == 2)
        #expect(session.steps.last?.inputText == "original")
        #expect(session.steps.last?.sourceStepID == nil)
        #expect(session.steps.last?.outputText == "draft")
        #expect(state.currentDisplayText == "draft")
        #expect(!state.hasUnappliedEdit)
        state.saveEdit()
        #expect(state.currentSession?.steps.count == 2)
    }

    @Test func branchesRetainSourceIdentity() throws {
        let original = TransformationSession(originalText: "same")
            .addingStep(promptName: "first", outputText: "same")
        let branched = original
            .addingStep(promptName: "from first", outputText: "one", sourceIndex: 0)
            .addingStep(promptName: "also from first", outputText: "two", sourceIndex: 0)
            .addingStep(promptName: "from original", outputText: "three", sourceIndex: -1)
        #expect(branched.steps.count == 4)
        #expect(branched.steps[1].sourceStepID == branched.steps[0].id)
        #expect(branched.steps[2].sourceStepID == branched.steps[0].id)
        #expect(branched.steps[3].sourceStepID == nil)
        let updated = branched.updatingStep(id: branched.steps[2].id, outputText: "done", isPending: false)
        #expect(updated.steps[2].sourceStepID == branched.steps[0].id)
    }

    @Test func emptyEditAndProcessing() {
        let state = AppState()
        state.currentSession = TransformationSession(originalText: "text")
        state.editingText = ""
        state.isProcessing = true
        state.saveEdit()
        #expect(state.currentSession?.steps.isEmpty == true)
        state.isProcessing = false
        state.saveEdit()
        #expect(state.currentSession?.steps.last?.outputText == "")
    }
}
