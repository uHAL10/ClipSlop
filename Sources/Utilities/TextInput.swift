import AppKit

@MainActor
func isComposingText(_ responder: NSResponder?) -> Bool {
    (responder as? NSTextInputClient)?.hasMarkedText() ?? false
}
