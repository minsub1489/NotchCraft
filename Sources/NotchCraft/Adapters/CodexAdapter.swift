import Foundation
import NotchCraftCore

@MainActor final class CodexAdapter: AgentAdapter {
    private let transport = RPCTransport()
    private var gate = PermissionGate()
    private var requestIDs: [String: JSONValue] = [:]
    private(set) var owned: Set<String> = []
    private var continuation: AsyncStream<AgentEvent>.Continuation?
    var onDisconnect: (() -> Void)?
    var onUnsupportedRequest: ((String) -> Void)?
    var isConnected: Bool { transport.isRunning }
    func detect() -> AdapterDetection { ExecutableLocator.detections()[0] }
    func getCapabilities() -> AdapterCapabilities {
        AdapterCapabilities(sessionHistory: true, liveEvents: true, usage: true, approvals: true, cancel: true, resume: false, scope: "connection.owned")
    }
    func connect() async throws {
        guard let executable = detect().executable else { throw AdapterError.unavailable }
        transport.onMessage = { [weak self] message in self?.receive(message) }
        transport.onDisconnect = { [weak self] in
            self?.gate.removeAll(); self?.requestIDs.removeAll(); self?.owned.removeAll(); self?.onDisconnect?()
        }
        try transport.start(executable: executable)
        do {
            _ = try await transport.request("initialize", params: .object([
                "clientInfo": .object(["name": .string("notchcraft"), "title": .string("NotchCraft"), "version": .string("0.1.0")]),
                "capabilities": .null
            ]))
            try transport.notify("initialized")
        } catch { transport.stop(); throw error }
    }
    func disconnect() { transport.stop(); gate.removeAll(); requestIDs.removeAll(); owned.removeAll() }
    func subscribeEvents() -> AsyncStream<AgentEvent> {
        AsyncStream(bufferingPolicy: .bufferingNewest(512)) { self.continuation = $0 }
    }
    func listSessions() async throws -> [ProviderSession] {
        let result = try await transport.request("thread/list", params: .object([
            "limit": .int(50), "sortKey": .string("updated_at"), "sortDirection": .string("desc"),
            "modelProviders": .array([]), "useStateDbOnly": .bool(true)
        ]))
        return result["data"].array.compactMap { thread in
            guard let id = thread["id"].string else { return nil }
            return ProviderSession(id: id, name: thread["name"].string ?? "Codex · \(id.prefix(8))",
                                   model: thread["model"].string, cwd: thread["cwd"].string ?? "",
                                   updatedAt: Date(timeIntervalSince1970: thread["updatedAt"].double ?? 0), owned: owned.contains(id))
        }
    }
    func getUsage() async throws -> JSONValue { try await transport.request("account/rateLimits/read") }
    func getPermissionRequests() -> [PermissionRequest] { Array(gate.pending.values) }
    func respondToPermission(_ request: PermissionRequest, allow: Bool) throws {
        _ = try gate.validate(id: request.id, sessionID: request.sessionID, taskID: request.taskID, owned: owned.contains(request.sessionID))
        guard let wireID = requestIDs[request.id] else { throw PermissionError.noLongerPending }
        try transport.respond(id: wireID, result: .object(["decision": .string(allow ? "accept" : "decline")]))
        gate.resolve(id: request.id); requestIDs.removeValue(forKey: request.id)
        continuation?.yield(AgentEvent(providerID: "codex", adapterID: "codex.app-server", agentID: request.sessionID,
                                       sessionID: request.sessionID, taskID: request.taskID, eventType: .approvalResolved, source: .appServer))
    }
    func cancelTask(sessionID: String, taskID: String) async throws {
        guard owned.contains(sessionID) else { throw AdapterError.unsupported }
        _ = try await transport.request("turn/interrupt", params: .object(["threadId": .string(sessionID), "turnId": .string(taskID)]))
    }
    func resumeTask(sessionID: String) async throws { throw AdapterError.unsupported }
    func startTask(prompt: String, project: URL, allowProjectWrites: Bool) async throws -> ProviderSession {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, prompt.utf8.count < 100_000,
              project.isFileURL, FileManager.default.fileExists(atPath: project.path) else { throw AdapterError.invalidInput }
        // Starting a turn happens only from the explicit new-task form.
        let result = try await transport.request("thread/start", params: .object([
            "cwd": .string(project.path), "sandbox": .string(allowProjectWrites ? "workspace-write" : "read-only"),
            "approvalPolicy": .string("on-request"), "approvalsReviewer": .string("user")
        ]))
        guard let id = result["thread"]["id"].string else { throw AdapterError.invalidMessage }
        owned.insert(id)
        let session = ProviderSession(id: id, name: "Codex · \(id.prefix(8))", model: result["model"].string,
                                      cwd: project.path, updatedAt: Date(), owned: true)
        continuation?.yield(AgentEvent(providerID: "codex", adapterID: "codex.app-server", agentID: id, sessionID: id,
                                       eventType: .sessionStarted, source: .appServer))
        _ = try await transport.request("turn/start", params: .object([
            "threadId": .string(id), "input": .array([.object(["type": .string("text"), "text": .string(prompt), "text_elements": .array([])])])
        ]))
        return session
    }
    private func receive(_ message: JSONValue) {
        if !message["id"].isNull, !message["method"].isNull {
            if let request = CodexNormalizer.permission(from: message), owned.contains(request.sessionID) {
                gate.register(request); requestIDs[request.id] = message["id"]
                continuation?.yield(AgentEvent(eventID: "codex:approval:\(request.id)", providerID: "codex", adapterID: "codex.app-server",
                                               agentID: request.sessionID, sessionID: request.sessionID, taskID: request.taskID,
                                               eventType: .approvalRequested, activityType: .approval, source: .appServer, permissionRequest: request))
            } else {
                onUnsupportedRequest?(message["method"].string ?? "unknown")
                try? transport.rejectUnsupported(id: message["id"])
            }
        }
        if message["method"].string == "serverRequest/resolved" {
            let raw = message["params"]["requestId"]
            if let id = raw.string ?? raw.int.map(String.init) { gate.resolve(id: id); requestIDs.removeValue(forKey: id) }
        }
        for event in CodexNormalizer.events(from: message) where owned.contains(event.sessionID) { continuation?.yield(event) }
    }
}
