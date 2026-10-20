import Foundation
import NotchCraftCore

struct AdapterCapabilities: Sendable {
    var sessionHistory = false
    var liveEvents = false
    var usage = false
    var approvals = false
    var cancel = false
    var resume = false
    var scope: String
}
struct AdapterDetection: Identifiable, Sendable {
    let id: String
    let name: String
    let executable: URL?
    let integration: String
    var isInstalled: Bool { executable != nil }
}
struct ProviderSession: Identifiable, Sendable, Equatable {
    let id: String
    var name: String
    var provider: String = "Codex"
    var model: String?
    var cwd: String
    var updatedAt: Date
    var owned = false
}
@MainActor protocol AgentAdapter: AnyObject {
    func detect() -> AdapterDetection
    func connect() async throws
    func disconnect()
    func getCapabilities() -> AdapterCapabilities
    func listSessions() async throws -> [ProviderSession]
    func subscribeEvents() -> AsyncStream<AgentEvent>
    func getUsage() async throws -> JSONValue
    func getPermissionRequests() -> [PermissionRequest]
    func respondToPermission(_ request: PermissionRequest, allow: Bool) throws
    func cancelTask(sessionID: String, taskID: String) async throws
    func resumeTask(sessionID: String) async throws
}
enum AdapterError: LocalizedError {
    case unavailable, disconnected, timeout, invalidMessage, remote(Int), unsupported, invalidInput, noProject
    var errorDescription: String? {
        switch self {
        case .unavailable: L("error.cliMissing")
        case .disconnected: L("error.disconnected")
        case .timeout: L("error.timeout")
        case .invalidMessage: L("error.protocol")
        case .remote(let code): L("error.server") + " (\(code))"
        case .unsupported: L("error.unsupported")
        case .invalidInput: L("error.input")
        case .noProject: L("error.project")
        }
    }
}
enum ExecutableLocator {
    static func find(_ name: String) -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let standard = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
        let user = [".local/bin", ".cargo/bin", ".opencode/bin", ".npm-global/bin"].map { home.appendingPathComponent($0).path }
        let paths = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init) + standard + user
        return paths.map { URL(fileURLWithPath: $0).appendingPathComponent(name) }.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
    static func detections() -> [AdapterDetection] {
        [("codex", "Codex", "integration.codex"), ("claude", "Claude Code", "integration.hooks"),
         ("gemini", "Gemini CLI", "integration.hooks"), ("opencode", "OpenCode", "integration.server")].map {
            AdapterDetection(id: $0.0, name: $0.1, executable: find($0.0), integration: $0.2)
        }
    }
}
