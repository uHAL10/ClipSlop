import Foundation

/// Each run discovers only the bundled agent in a private, temporary workspace.
struct AGYWorkspace: Sendable {
    let directory: URL
    let arguments: [String]

    init() throws {
        let files = FileManager.default
        guard let source = Bundle.module.url(forResource: "AGYTextAgent", withExtension: "md") else {
            throw CocoaError(.fileNoSuchFile)
        }
        directory = files.temporaryDirectory
            .appendingPathComponent("clipslop-agy-\(UUID().uuidString)", isDirectory: true)
            .resolvingSymlinksInPath()
        try files.createDirectory(at: directory, withIntermediateDirectories: false,
                                  attributes: [.posixPermissions: 0o700])
        do {
            let agent = directory.appendingPathComponent(".agents/agents/clipslop-text", isDirectory: true)
            try files.createDirectory(at: agent, withIntermediateDirectories: true)
            try files.copyItem(at: source, to: agent.appendingPathComponent("agent.md"))
            let settings = try JSONEncoder().encode(["trustedWorkspaces": [directory.path]])
            arguments = ["--settings", String(decoding: settings, as: UTF8.self), "--agent", "clipslop-text"]
        } catch {
            try? files.removeItem(at: directory)
            throw error
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}
