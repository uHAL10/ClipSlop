import AppKit

@MainActor
enum ClipboardService {
    static func getText() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    static func setText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Copy HTML content — puts rendered HTML + plain text on pasteboard.
    static func setHTMLContent(_ html: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(html, forType: .string)
        let wrappedHTML = html.contains("<meta charset") ? html
            : "<html><head><meta charset=\"utf-8\"></head><body>\(html)</body></html>"
        if let htmlData = wrappedHTML.data(using: .utf8) {
            pb.setData(htmlData, forType: .html)
        }
    }

    static func setRichText(_ markdown: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(markdown, forType: .string)
        if let htmlData = MarkdownConverter.styledHTML(from: markdown).data(using: .utf8) {
            pb.setData(htmlData, forType: .html)
        }
        if let rtfData = MarkdownConverter.rtfData(from: markdown) {
            pb.setData(rtfData, forType: .rtf)
        }
    }

    static func simulatePaste() {
        // Small delay to let the popup dismiss first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let source = CGEventSource(stateID: .combinedSessionState)
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // V key
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            keyDown?.flags = .maskCommand
            keyUp?.flags = .maskCommand
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
    }
}
