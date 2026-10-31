import Foundation
import Testing
@testable import ClipSlop

@Suite("AGY isolation")
struct AGYWorkspaceTests {
    @Test func workspaceContainsOnlyTheRestrictedAgent() throws {
        let workspace = try AGYWorkspace()
        defer { workspace.remove() }
        let agent = workspace.directory.appendingPathComponent(".agents/agents/clipslop-text/agent.md")
        let content = try String(contentsOf: agent, encoding: .utf8)
        for invariant in ["excludeDefaultComponents: true", "inheritCustomizations: false", "inheritMcp: false", "tools: []"] {
            #expect(content.contains(invariant))
        }
        let settings = try JSONDecoder().decode([String: [String]].self, from: Data(workspace.arguments[1].utf8))
        #expect(settings == ["trustedWorkspaces": [workspace.directory.path]])
        #expect(Array(workspace.arguments.suffix(2)) == ["--agent", "clipslop-text"])
        let permissions = try FileManager.default.attributesOfItem(atPath: workspace.directory.path)[.posixPermissions] as? Int
        #expect(permissions == 0o700)
        workspace.remove()
        #expect(!FileManager.default.fileExists(atPath: workspace.directory.path))
    }

    @Test(arguments: [false, true])
    func generationUsesThePrivateWorkspace(streaming: Bool) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let binary = root.appendingPathComponent("agy")
        try """
        #!/bin/sh
        test -f .agents/agents/clipslop-text/agent.md || exit 2
        printf '%s\\n' "$PWD" "$@"
        """.write(to: binary, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: binary.path)
        let config = AIProviderConfig(name: "test", providerType: .cliTool, baseURL: binary.path, modelID: "agy")
        let service = CLIToolService()
        var output = ""
        if streaming {
            for try await chunk in service.stream(text: "--help", systemPrompt: "", config: config) { output += chunk }
        } else {
            output = try await service.process(text: "--help", systemPrompt: "", config: config)
        }
        let lines = output.split(separator: "\n").map(String.init)
        let directory = try #require(lines.first)
        #expect(directory != NSHomeDirectory())
        #expect(URL(fileURLWithPath: directory).lastPathComponent.hasPrefix("clipslop-agy-"))
        let settingsIndex = try #require(lines.firstIndex(of: "--settings"))
        let settings = try JSONDecoder().decode([String: [String]].self, from: Data(lines[settingsIndex + 1].utf8))
        #expect(settings["trustedWorkspaces"] == [directory])
        #expect(lines.contains("--agent"))
        #expect(lines.contains("clipslop-text"))
        #expect(lines.contains("--print=--help"))
    }
}
