import SwiftUI

#if DEBUG
#Preview("Editor") {
    PopupEditorPreview()
}
#endif

struct PopupContentView: View {
    let appState: AppState
    @State private var promptListWidth: Double = Constants.userDefaults.object(forKey: "promptListWidth") as? Double ?? 240
    @State private var dragStartWidth: Double = 0
    @State private var showShortcutHints = false
    private let loc = Loc.shared

    private var libraryCollapsed: Bool {
        appState.settings.promptLibraryCollapsed && !appState.promptSearchState.isActive
    }

    var body: some View {
        HStack(spacing: 0) {
            if appState.currentSession != nil {
                HistorySidebarView(appState: appState)
                    .frame(width: 180)
                Divider()
            }

            // Main content (right side)
            VStack(spacing: 0) {
                if let error = appState.errorMessage {
                    errorView(error)
                } else if appState.shouldShowProcessingView {
                    ProcessingView(appState: appState)

                } else {
                    mainContentArea
                }
            }
        }
        .padding(.top, 1) // minimal gap below titlebar
        .overlay(alignment: .top) {
            Divider()
        }
        .frame(minWidth: 560, minHeight: 400)
        .background(.ultraThinMaterial.opacity(appState.settings.popupOpacity))
        .background(KeyEventHandler(appState: appState))
        .overlay {
            if appState.isShortcutsOverlayVisible {
                ShortcutsCheatSheetView(appState: appState)
            }
        }
    }

    // MARK: - Main Content Area

    private var mainContentArea: some View {
        GeometryReader { geo in
            // Space scrolls the widest scroll view, so the text area must stay wider.
            let maxPromptWidth = max(160, min(400, (geo.size.width - 8) / 2 - 1))
            let clampedWidth = min(max(160, promptListWidth), maxPromptWidth)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        // Find bar
                        if appState.findBarState.isVisible {
                            FindBarView(findBarState: appState.findBarState)
                            Divider()
                        }

                        textEditor
                        .frame(maxHeight: .infinity)
                        .pointerStyle(.horizontalText)

                        AdHocPromptBar(appState: appState)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Group {
                        Divider()
                            .frame(width: libraryCollapsed ? 1 : 8)
                            .overlay {
                                if !libraryCollapsed {
                                    Rectangle()
                                        .fill(.clear)
                                        .contentShape(Rectangle())
                                        .frame(width: 8)
                                        .gesture(
                                            DragGesture(minimumDistance: 0)
                                                .onChanged { value in
                                                    if dragStartWidth == 0 {
                                                        dragStartWidth = clampedWidth
                                                    }
                                                    promptListWidth = min(maxPromptWidth, max(160, dragStartWidth - value.translation.width))
                                                }
                                                .onEnded { _ in
                                                    Constants.userDefaults.set(promptListWidth, forKey: "promptListWidth")
                                                    dragStartWidth = 0
                                                }
                                        )
                                        .pointerStyle(.columnResize)
                                        .background(WindowDragBlocker())
                                }
                            }

                        if libraryCollapsed {
                            libraryToggle
                                .frame(width: 32)
                                .frame(maxHeight: .infinity, alignment: .top)
                        } else {
                            promptSidebar
                                .frame(width: clampedWidth)
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                Divider()
                actionsBar
            }
        }
    }

    @ViewBuilder
    private var textEditor: some View {
        Group {
            switch appState.activeEditorMode {
            case .plainText:
                MarkdownTextView(text: Bindable(appState).editingText,
                                 editorContext: plainTextEditorContext,
                                 findBarState: appState.findBarState,
                                 isEditable: !appState.isProcessing)
            case .html:
                HTMLEditorView(text: Bindable(appState).editingText,
                               isEditable: !appState.isProcessing,
                               findBarState: appState.findBarState)
            case .markdown:
                if appState.isProcessing {
                    switch appState.settings.markdownViewer {
                    case .rendered:
                        if appState.findBarState.isVisible {
                            HTMLEditorView(text: .constant(MarkdownConverter.html(from: appState.editingText)),
                                           isEditable: false, findBarState: appState.findBarState)
                        } else {
                            MarkdownPreviewView(markdown: appState.editingText)
                        }
                    case .colored:
                        MarkdownTextView(text: .constant(appState.editingText), editorContext: plainTextEditorContext,
                                         findBarState: appState.findBarState, highlighting: .markdown, isEditable: false)
                    case .styled:
                        MarkdownEngineView(text: .constant(appState.editingText), isEditable: false,
                                           findBarState: appState.findBarState)
                    }
                } else {
                    switch appState.settings.markdownEditor {
                    case .plain, .colored:
                        MarkdownEditorView(text: Bindable(appState).editingText,
                                           findBarState: appState.findBarState,
                                           highlightsMarkdown: appState.settings.markdownEditor == .colored)
                    case .styled:
                        MarkdownEngineView(text: Bindable(appState).editingText, findBarState: appState.findBarState)
                    }
                }
            }
        }
        .onChange(of: appState.activeEditorMode) { appState.findBarState.clearAndReSearch() }
    }

    private var promptSidebar: some View {
        VStack(spacing: 0) {
            if appState.promptSearchState.isActive {
                PromptSearchBar(searchState: appState.promptSearchState)
                PromptSearchList(appState: appState, searchState: appState.promptSearchState)
            } else {
                HStack(spacing: 4) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)

                            if appState.navigationPath.isEmpty {
                                Text(loc.t("popup.prompts"))
                                    .font(.caption.bold())
                            } else {
                                Button {
                                    appState.navigateToRoot()
                                } label: {
                                    Text(loc.t("popup.prompts"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)

                                ForEach(Array(appState.navigationPath.enumerated()), id: \.element.id) { i, node in
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    if i < appState.navigationPath.count - 1 {
                                        Button {
                                            appState.navigationPath = Array(appState.navigationPath.prefix(i + 1))
                                        } label: {
                                            Text(node.name)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        Text(node.name)
                                            .font(.caption.bold())
                                    }
                                }
                            }
                        }
                    }

                    if !appState.navigationPath.isEmpty {
                        Button {
                            appState.navigateBack()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(loc.t("popup.back"))
                    }

                    libraryToggle
                }
                .padding(.leading, 12)
                .padding(.vertical, 6)

                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 0) {
                        ForEach(appState.currentPrompts) { node in
                            PromptRow(node: node) {
                                appState.navigateInto(node)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var libraryToggle: some View {
        Button {
            appState.settings.promptLibraryCollapsed.toggle()
        } label: {
            Image(systemName: libraryCollapsed ? "chevron.left" : "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(loc.t("popup.hint.library")) (⌘L)")
        .background(WindowDragBlocker())
    }

    @State private var plainTextEditorContext = MarkdownEditorContext()
    // MARK: - Actions Bar

    private var actionsBar: some View {
        HStack(spacing: 10) {
            copyButton
                .allowsHitTesting(!Constants.isPreview)

            actionButton(loc.t("popup.open"), icon: "square.and.arrow.up", shortcut: "⌘O") {
                appState.openInTextEdit()
            }
            .allowsHitTesting(!Constants.isPreview)

            actionButton(loc.t("popup.hint.find"), icon: "magnifyingglass", shortcut: "⌘F") {
                appState.findBarState.show()
            }

            Spacer()

            Picker(loc.t("popup.display"), selection: Bindable(appState).activeEditorMode) {
                Text(loc.t("settings.general.behavior.editor_mode.plain")).tag(EditorMode.plainText)
                Text("HTML").tag(EditorMode.html)
                Text("Markdown").tag(EditorMode.markdown)
            }
            .frame(width: 175)
            .onChange(of: appState.activeEditorMode) { _, newMode in
                // Save display mode for original item when viewing it
                if appState.isViewingOriginal {
                    appState.originalDisplayMode = newMode
                }
            }

            Button {
                showShortcutHints.toggle()
            } label: {
                Image(systemName: "questionmark.circle")
            }
            .buttonStyle(.plain)
            .help(loc.t("shortcuts.title"))
            .accessibilityLabel(loc.t("shortcuts.title"))
            .popover(isPresented: $showShortcutHints, arrowEdge: .bottom) {
                shortcutsHint
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Shortcuts Hint

    @ViewBuilder
    private var shortcutsHint: some View {
        if appState.isAdHocPromptActive {
            VStack(alignment: .leading, spacing: 8) {
                shortcutHint("↩", loc.t("popup.hint.adhoc_run"))
                shortcutHint("⇧↩", loc.t("popup.hint.adhoc_newline"))
                shortcutHint("Esc", loc.t("popup.hint.adhoc_exit"))
            }
            .font(.caption)
            .padding(16)
        } else if appState.promptSearchState.isActive {
            VStack(alignment: .leading, spacing: 8) {
                shortcutHint("↑↓", loc.t("popup.hint.search_select"))
                shortcutHint("↩", loc.t("popup.hint.search_run"))
                shortcutHint("Esc", loc.t("popup.hint.search_exit"))
            }
            .font(.caption)
            .padding(16)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                shortcutHint("↑↓", loc.t("popup.hint.history"))
                shortcutHint("Space", loc.t("popup.hint.page_down"))
                shortcutHint("⇧Space", loc.t("popup.hint.page_up"))
                shortcutHint("/", loc.t("popup.hint.search"))
                shortcutHint("⌘K", loc.t("popup.hint.adhoc"))
                shortcutHint("⌘S", loc.t("misc.manual_edit"))

                if !appState.navigationPath.isEmpty {
                    shortcutHint("⌫", loc.t("popup.hint.back"))
                }

                shortcutHint("Esc", loc.t("popup.hint.close"))
                shortcutHint("⌘D", loc.t("popup.hint.display"))
                shortcutHint("⌘L", loc.t("popup.hint.library"))
                shortcutHint("⌘/", loc.t("popup.hint.shortcuts"))


                // Mnemonic hint
                Text(loc.t("popup.mnemonic_hint"))
                    .foregroundStyle(.tertiary)
            }
            .font(.caption)
            .padding(16)
        }
    }

    private func shortcutHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            Text(key)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Text(label)
                .foregroundStyle(.tertiary)
        }
    }

    private var copyButton: some View {
        let copied = appState.showCopiedFeedback
        let selCopied = appState.showSelectionCopiedFeedback
        let active = copied || selCopied
        let closeOnCopy = appState.settings.closeOnCopy
        let label = active
            ? loc.t(selCopied ? "popup.selection_copied" : "popup.copied")
            : loc.t(closeOnCopy ? "popup.copy_and_close" : "popup.copy")
        return HStack(spacing: 0) {
            Menu {
                if !closeOnCopy {
                    Button {
                        appState.copyAndDismiss()
                    } label: {
                        Text("\(loc.t("popup.copy_and_close"))  ⌘⌃C")
                    }
                }
                Button {
                    appState.pasteCurrentText()
                } label: {
                    Text("\(loc.t("popup.copy_close_paste"))  ⌘⌃V")
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .frame(width: 18)

            Button {
                if SelectionService.copySelection(in: NSApp.keyWindow) {
                    showSelectionCopied()
                } else if closeOnCopy {
                    appState.copyAndDismiss()
                } else {
                    appState.copyCurrentText()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: active ? "checkmark.circle.fill" : "doc.on.doc")
                    Text(label)
                    if !active {
                        Text("⌘C").foregroundStyle(.tertiary)
                    }
                }
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .tint(active ? .green : nil)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 0,
                bottomTrailingRadius: 5, topTrailingRadius: 5
            ))
        }
        .background(.quaternary, in: UnevenRoundedRectangle(
            topLeadingRadius: 5, bottomLeadingRadius: 5,
            bottomTrailingRadius: 0, topTrailingRadius: 0
        ))
        .fixedSize(horizontal: false, vertical: true)
        .animation(.easeInOut(duration: 0.2), value: active)
        .background(WindowDragBlocker())
    }

    private func showSelectionCopied() {
        appState.showSelectionCopiedFeedback = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            appState.showSelectionCopiedFeedback = false
        }
    }

    private func actionButton(
        _ label: String,
        icon: String,
        shortcut: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(label)
                Text(shortcut)
                    .foregroundStyle(.tertiary)
            }
            .font(.caption)
        }
        .buttonStyle(.bordered)
        .background(WindowDragBlocker())
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.orange)

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if let detail = appState.errorDetail {
                ScrollView {
                    Text(detail)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(maxHeight: 120)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 16)
            }

            HStack {
                Button(loc.t("popup.dismiss")) {
                    appState.clearError()
                }
                if appState.errorProviderType == .openAIChatGPT {
                    Button(loc.t("popup.sign_in_again")) {
                        appState.reauthenticateChatGPT()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(loc.t("popup.try_again")) {
                        appState.clearError()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

// MARK: - NSEvent-based key handler (works in NSPanel)

struct KeyEventHandler: NSViewRepresentable {
    let appState: AppState

    func makeNSView(context: Context) -> KeyEventView {
        let view = KeyEventView()
        view.appState = appState
        return view
    }

    func updateNSView(_ nsView: KeyEventView, context: Context) {
        nsView.appState = appState
    }

    class KeyEventView: NSView {
        var appState: AppState?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil, monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    guard let self, let appState = self.appState else { return event }
                    guard event.window === self.window else { return event }
                    guard !isComposingText(event.window?.firstResponder) else { return event }
                    return self.handleKey(event, appState: appState) ? nil : event
                }
            }
        }

        override func removeFromSuperview() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            super.removeFromSuperview()
        }

        // Key codes for physical keys (layout-independent)
        private enum KeyCode {
            static let a: UInt16 = 0
            static let s: UInt16 = 1
            static let d: UInt16 = 2
            static let c: UInt16 = 8
            static let v: UInt16 = 9
            static let o: UInt16 = 31
            static let n: UInt16 = 45
            static let z: UInt16 = 6
            static let f: UInt16 = 3
            static let g: UInt16 = 5
            static let k: UInt16 = 40
            static let l: UInt16 = 37
            static let slash: UInt16 = 44
            static let comma: UInt16 = 43
            static let escape: UInt16 = 53
            static let enter: UInt16 = 36
            static let delete: UInt16 = 51
            static let forwardDelete: UInt16 = 117
            static let space: UInt16 = 49
            static let upArrow: UInt16 = 126
            static let downArrow: UInt16 = 125
        }

        @MainActor
        private func handleKey(_ event: NSEvent, appState: AppState) -> Bool {
            let code = event.keyCode
            let flags = event.modifierFlags
            let hasCmd = flags.contains(.command)
            let hasControl = flags.contains(.control)

            if Constants.isPreview && hasCmd && [KeyCode.c, KeyCode.v, KeyCode.o, KeyCode.comma].contains(code) {
                return false
            }

            // Let global shortcuts (⌃⌘ combos) pass through to the
            // KeyboardShortcuts handler — don't intercept them here.
            if hasCmd && hasControl { return false }

            // --- Shortcuts cheat-sheet overlay ---
            // Swallow everything while visible so keys don't act behind it;
            // Esc or ⌘/ dismisses.
            if appState.isShortcutsOverlayVisible {
                if code == KeyCode.escape || (hasCmd && code == KeyCode.slash) {
                    appState.isShortcutsOverlayVisible = false
                }
                return true
            }

            // --- Ad-hoc instruction bar (⌘K) ---
            if hasCmd && code == KeyCode.k {
                appState.activateAdHocPrompt()
                return true
            }

            // Enter runs; Shift+Enter inserts a newline.
            if appState.isAdHocPromptActive {
                if code == KeyCode.escape {
                    appState.deactivateAdHocPrompt()
                    return true
                }
                if code == KeyCode.enter && !hasCmd && !flags.contains(.shift) {
                    appState.runAdHocPrompt()
                    return true
                }
                return false
            }

            // --- Prompt-search overlay ---
            // When the "/" search is active, only intercept the four
            // navigation keys; let every other key flow to the focused
            // TextField (so typing, Cmd+A/C/V, etc. all work normally).
            if appState.promptSearchState.isActive {
                if code == KeyCode.escape {
                    appState.promptSearchState.deactivate()
                    return true
                }
                if code == KeyCode.upArrow {
                    appState.promptSearchState.selectPrevious()
                    return true
                }
                if code == KeyCode.downArrow {
                    appState.promptSearchState.selectNext()
                    return true
                }
                if code == KeyCode.enter && !flags.contains(.command) {
                    appState.applySearchResult(at: appState.promptSearchState.clampedSelectedIndex)
                    return true
                }
                return false
            }

            // --- Find bar shortcuts (both modes) ---
            if hasCmd && code == KeyCode.f {
                appState.findBarState.show()
                return true
            }

            if hasCmd && code == KeyCode.g && appState.findBarState.isVisible {
                let hasShift = event.modifierFlags.contains(.shift)
                if hasShift {
                    appState.findBarState.previousMatch()
                } else {
                    appState.findBarState.nextMatch()
                }
                return true
            }

            // Esc: clear text selection first
            if code == KeyCode.escape && SelectionService.clearSelection(in: self.window) {
                return true
            }

            // Esc closes find bar next
            if code == KeyCode.escape && appState.findBarState.isVisible {
                appState.findBarState.dismiss()
                return true
            }

            if hasCmd && code == KeyCode.s {
                appState.saveEdit()
                return true
            }

            // --- Normal mode ---

            if code == KeyCode.escape {
                if appState.shouldShowProcessingView {
                    appState.cancelProcessing()
                } else if appState.errorMessage != nil {
                    appState.clearError()
                } else if !appState.navigationPath.isEmpty {
                    appState.navigateBack()
                } else if appState.settings.closeOnEscape {
                    appState.dismissPopup()
                }
                return true
            }

            if hasCmd && code == KeyCode.d {
                let hasShift = event.modifierFlags.contains(.shift)
                if hasShift {
                    // Cycle backward: Plain → Markdown → HTML → Plain
                    switch appState.activeEditorMode {
                    case .plainText: appState.activeEditorMode = .markdown
                    case .markdown: appState.activeEditorMode = .html
                    case .html: appState.activeEditorMode = .plainText
                    }
                } else {
                    // Cycle forward: Plain → HTML → Markdown → Plain
                    switch appState.activeEditorMode {
                    case .plainText: appState.activeEditorMode = .html
                    case .html: appState.activeEditorMode = .markdown
                    case .markdown: appState.activeEditorMode = .plainText
                    }
                }
                return true
            }

            if hasCmd && code == KeyCode.slash {
                appState.isShortcutsOverlayVisible = true
                return true
            }

            if hasCmd && code == KeyCode.l {
                appState.settings.promptLibraryCollapsed.toggle()
                return true
            }

            if hasCmd && code == KeyCode.o {
                appState.openInTextEdit()
                return true
            }

            if hasCmd && code == KeyCode.comma {
                appState.openSettings()
                return true
            }

            if let textView = self.window?.firstResponder as? NSTextView, textView.isEditable {
                return false
            }

            if hasCmd && code == KeyCode.a {
                appState.selectAllText()
                return true
            }

            if hasCmd && code == KeyCode.c {
                if SelectionService.copySelection(in: self.window) {
                    appState.showSelectionCopiedFeedback = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1.5))
                        appState.showSelectionCopiedFeedback = false
                    }
                    return true
                }
                if appState.settings.closeOnCopy {
                    appState.copyAndDismiss()
                } else {
                    appState.copyCurrentText()
                }
                return true
            }

            if hasCmd && code == KeyCode.v {
                appState.pasteCurrentText()
                return true
            }

            let isArrowUp = code == KeyCode.upArrow
            let isArrowDown = code == KeyCode.downArrow
            let hasShift = event.modifierFlags.contains(.shift)
            let isSpace = code == KeyCode.space

            if isArrowUp {
                appState.navigateHistoryNewer()
                return true
            }
            if isArrowDown {
                appState.navigateHistoryOlder()
                return true
            }

            if isSpace {
                scrollTextArea(up: hasShift, by: 300)
                return true
            }


            if code == KeyCode.delete || code == KeyCode.forwardDelete {
                if !appState.navigationPath.isEmpty {
                    appState.navigateBack()
                    return true
                }
                return false
            }

            // Don't process mnemonic keys when find bar has focus
            if appState.findBarState.isVisible {
                return false
            }

            // "/" activates the prompt-search overlay. Match by emitted
            // character (layout-independent enough for the search key) and
            // only when no modifiers are held so ⇧/ ("?") and ⌥/ remain
            // available as future mnemonics.
            let typed = event.charactersIgnoringModifiers ?? ""
            if typed == "/"
                && event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty
                && !appState.isProcessing
                && appState.errorMessage == nil {
                appState.promptSearchState.activate()
                return true
            }

            // Mnemonic key navigation
            let mods = MnemonicModifiers(eventFlags: event.modifierFlags)

            // Try character-based matching first, then keyCode-based as fallback.
            // This ensures mnemonics like ⇧. work on any keyboard layout.
            let charMatch: String
            if appState.settings.useKeyCodes {
                charMatch = keyCodeToCharacter(code) ?? ""
            } else {
                charMatch = event.characters?.lowercased() ?? ""
            }

            guard !appState.isProcessing else { return false }

            if !charMatch.isEmpty && appState.handleMnemonicKey(charMatch, modifiers: mods) {
                return true
            }

            // Fallback: try keyCode-based match (handles shifted keys on non-Latin layouts)
            if !appState.settings.useKeyCodes,
               let keyChar = keyCodeToCharacter(code),
               keyChar != charMatch,
               appState.handleMnemonicKey(keyChar, modifiers: mods) {
                return true
            }

            // Special key identifier matching (Tab, Enter, F-keys, Delete at root)
            if let specialID = keyCodeToIdentifier(code),
               appState.handleMnemonicKey(specialID, modifiers: mods) {
                return true
            }

            return false
        }

        private func scrollTextArea(up: Bool, by amount: CGFloat) {
            guard let scrollView = findFirstScrollView(in: self.window?.contentView) else { return }
            let clipView = scrollView.contentView
            let maxY = scrollView.documentView?.frame.height ?? 0
            var origin = clipView.bounds.origin
            if up {
                origin.y = max(0, origin.y - amount)
            } else {
                origin.y = min(max(0, maxY - clipView.bounds.height), origin.y + amount)
            }
            clipView.setBoundsOrigin(origin)
        }

        private func findFirstScrollView(in view: NSView?) -> NSScrollView? {
            guard let view else { return nil }
            var queue: [NSView] = [view]
            var scrollViews: [NSScrollView] = []
            while !queue.isEmpty {
                let current = queue.removeFirst()
                if let sv = current as? NSScrollView {
                    scrollViews.append(sv)
                }
                queue.append(contentsOf: current.subviews)
            }
            return scrollViews.max(by: { $0.frame.width < $1.frame.width })
        }
    }
}

// MARK: - Resize Handle (AppKit-based to block window dragging)

/// Divider drag handle. On macOS 15 NSHostingView owns the cursor through
/// SwiftUI's pointer-style system and re-applies the resolved style (arrow
/// for unstyled areas) on every mouse move — `NSCursor` push/pop from
/// tracking areas only flashes before being reset. Declaring the cursor via
/// `.pointerStyle` here makes SwiftUI itself show it, so it sticks.
struct ResizeHandle: View {
    @Binding var height: Double
    @Binding var dragStartHeight: Double
    var minHeight: Double = 80
    var maxHeight: Double = 400
    /// UserDefaults key the final height is persisted under; nil = session-only.
    var storageKey: String? = nil
    /// Base height for the first drag when `height` is still 0 — used by the
    /// ⌘K bar, whose height is content-driven until the user grabs the handle.
    var initialHeight: (() -> Double)?

    var body: some View {
        ResizeHandleRepresentable(
            height: $height,
            dragStartHeight: $dragStartHeight,
            minHeight: minHeight,
            maxHeight: maxHeight,
            storageKey: storageKey,
            initialHeight: initialHeight
        )
        .pointerStyle(.rowResize)
    }
}

private struct ResizeHandleRepresentable: NSViewRepresentable {
    @Binding var height: Double
    @Binding var dragStartHeight: Double
    var minHeight: Double
    var maxHeight: Double
    var storageKey: String?
    var initialHeight: (() -> Double)?

    private func configure(_ view: ResizeHandleNSView) {
        view.onDrag = { delta in
            if dragStartHeight == 0 {
                dragStartHeight = height > 0 ? height : (initialHeight?() ?? height)
            }
            // NSView y-axis is bottom-up: positive delta = mouse moved up = grow
            height = max(minHeight, min(maxHeight, dragStartHeight + delta))
        }
        view.onDragEnd = {
            if let storageKey {
                Constants.userDefaults.set(height, forKey: storageKey)
            }
            dragStartHeight = 0
        }
    }

    func makeNSView(context: Context) -> ResizeHandleNSView {
        let view = ResizeHandleNSView()
        configure(view)
        return view
    }

    func updateNSView(_ nsView: ResizeHandleNSView, context: Context) {
        configure(nsView)
    }
}

final class ResizeHandleNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { false }

    var onDrag: ((Double) -> Void)?
    var onDragEnd: (() -> Void)?

    private var dragOriginY: CGFloat = 0

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 8)
    }

    // `.pointerStyle(.rowResize)` on the representable handles hover; the
    // cursor rect covers AppKit-driven cursor updates (window activation,
    // returning from a drag) without a push/pop that SwiftUI would reset.
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeUpDown)
    }

    override func mouseDown(with event: NSEvent) {
        dragOriginY = event.locationInWindow.y
    }

    override func mouseDragged(with event: NSEvent) {
        let delta = Double(event.locationInWindow.y - dragOriginY)
        onDrag?(delta)
    }

    override func mouseUp(with event: NSEvent) {
        onDragEnd?()
    }
}
