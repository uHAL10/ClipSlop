import AppKit
import Testing
@testable import ClipSlop

@Suite("Chat input focus")
@MainActor
struct ChatInputFocusTests {
    @Test func focusIsReportedBeforeTyping() {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let input = FocusReportingTextView(frame: window.contentView!.bounds)
        window.contentView?.addSubview(input)
        var focused = false
        input.onFocusChange = { focused = $0 }
        #expect(window.makeFirstResponder(input))
        #expect(focused)
        #expect(input.string.isEmpty)
        #expect(window.makeFirstResponder(nil))
        #expect(!focused)
        #expect(window.makeFirstResponder(input))
        #expect(focused)
    }
}
