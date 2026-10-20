import Foundation
import Testing
import NotchCraftCore
@testable import NotchCraft

@MainActor @Test func stdioLifecycleRoutesApprovalAndCancellation() async throws {
    let source = try #require(Bundle.module.url(forResource:"fake-codex",withExtension:"py",subdirectory:"Fixtures"))
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
    try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
    defer { try? FileManager.default.removeItem(at:folder) }
    let executable=folder.appendingPathComponent("codex")
    try FileManager.default.copyItem(at:source,to:executable)
    try FileManager.default.setAttributes([.posixPermissions:0o700],ofItemAtPath:executable.path)
    let adapter=CodexAdapter(executable:executable)
    defer { adapter.disconnect() }
    let stream=adapter.subscribeEvents()
    try await adapter.connect()
    #expect(adapter.isConnected)
    let histories=try await adapter.listSessions()
    #expect(histories.count == 1)
    #expect(histories.first?.owned == false)
    #expect(try await adapter.getUsage()["rateLimits"]["primary"]["usedPercent"].int == 25)
    let consumer=Task { @MainActor in
        var received:[AgentEvent]=[]
        for await event in stream {
            received.append(event)
            if let permission=event.permissionRequest { try adapter.respondToPermission(permission,allow:false) }
            if event.eventType == .taskCancelled { break }
        }
        return received
    }
    let session=try await adapter.startTask(prompt:"Fixture input",project:folder,allowProjectWrites:false)
    #expect(session.owned)
    let received=try await consumer.value
    #expect(received.contains { $0.activityType == .testing })
    #expect(received.contains { $0.eventType == .approvalRequested })
    #expect(adapter.getPermissionRequests().isEmpty)
    await #expect(throws:AdapterError.self) { try await adapter.cancelTask(sessionID:"external-history",taskID:"x") }
    adapter.disconnect()
    #expect(!adapter.isConnected)
}
@MainActor @Test func unavailableExecutableFailsCleanly() async {
    let transport=RPCTransport()
    #expect(throws:(any Error).self) { try transport.start(executable:URL(fileURLWithPath:"/notchcraft-nonexistent/codex")) }
    #expect(!transport.isRunning)
    await #expect(throws:AdapterError.self) { try await transport.request("initialize") }
    transport.stop()
}
/// Opt in explicitly. Only reads metadata/quota; never creates a thread or a model turn.
@MainActor @Test(.enabled(if:ProcessInfo.processInfo.environment["NOTCHCRAFT_LIVE_TEST"] == "1"))
func installedCodexReadOnlySmoke() async throws {
    let adapter=CodexAdapter()
    defer { adapter.disconnect() }
    try await adapter.connect()
    let sessions=try await adapter.listSessions()
    #expect(sessions.allSatisfy { !$0.owned })
    let quota=try? await adapter.getUsage()
    print("Codex read-only smoke: connected=true sessions=\(sessions.count) quotaAvailable=\(quota != nil) modelTurnsStarted=0")
}
