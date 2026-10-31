import SwiftUI

struct HistorySidebarView: View {
    let appState: AppState
    private let loc = Loc.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 2) {
                if let session = appState.currentSession {
                    // Newest steps first
                    ForEach(Array(session.steps.enumerated().reversed()), id: \.element.id) { index, step in
                        historyItem(
                            index: index,
                            label: step.promptName,
                            icon: "wand.and.stars",
                            preview: step.isPending ? loc.t("popup.processing") : step.outputText,
                            isSelected: isStepSelected(index, session: session),
                            isPending: step.isPending
                        )
                    }

                    // Original text at the bottom
                    VStack(spacing: 4) {
                        historyItem(
                            index: -1,
                            label: loc.t("popup.history.original"),
                            icon: "doc.text",
                            preview: session.originalText,
                            isSelected: appState.isViewingOriginal
                        )

                    }
                }
            }
            .padding(6)
        }
        .background(.background.opacity(0.3))
    }

    private func isStepSelected(_ index: Int, session: TransformationSession) -> Bool {
        if let selected = appState.selectedHistoryStepIndex {
            return selected == index
        }
        return index == session.steps.count - 1
    }

    private func historyItem(
        index: Int,
        label: String,
        icon: String,
        preview: String,
        isSelected: Bool,
        isPending: Bool = false
    ) -> some View {
        Button {
            appState.selectHistoryStep(at: index)
        } label: {
            HStack(spacing: 8) {
                if isPending {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16)
                } else {
                    Image(systemName: icon)
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .frame(width: 16)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .lineLimit(1)

                    Text(preview.prefix(50))
                        .font(.caption2)
                        .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if isSelected && appState.hasUnappliedEdit {
                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                        .accessibilityLabel(loc.t("misc.manual_edit"))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(isSelected ? Color.accentColor : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                if isSource(index) {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.blue, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if index >= 0 && !isPending {
                Button(role: .destructive) {
                    appState.removeHistoryStep(at: index)
                } label: {
                    Label(loc.t("popup.history.delete"), systemImage: "trash")
                }
            }
        }
    }

    private func isSource(_ index: Int) -> Bool {
        guard let session = appState.currentSession else { return false }
        let selected = appState.selectedHistoryStepIndex ?? (session.steps.count - 1)
        guard session.steps.indices.contains(selected) else { return false }
        let sourceID = session.steps[selected].sourceStepID
        if index == -1 { return sourceID == nil }
        return session.steps.indices.contains(index) && session.steps[index].id == sourceID
    }
}
