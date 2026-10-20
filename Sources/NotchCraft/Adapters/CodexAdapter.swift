import Foundation
import NotchCraftCore

@MainActor final class CodexAdapter: AgentAdapter {
    private let transport = RPCTransport()
    private let executableOverride: URL?
    init(executable: URL? = nil) { executableOverride = executable }
    private var gate = PermissionGate()
    private var requestIDs: [String: JSONValue] = [:]
    private var itemDetails: [String: String] = [:]
    private(set) var owned: Set<String> = []
    private var continuation: AsyncStream<AgentEvent>.Continuation?
    var onDisconnect: (() -> Void)?
    var onOutput: ((String, String) -> Void)?
    var onQuotaUpdated: ((JSONValue) -> Void)?
    var onSessionCreated: ((ProviderSession) -> Void)?
    var onUnsupportedRequest: ((String) -> Void)?
    var isConnected: Bool { transport.isRunning }
    func detect() -> AdapterDetection { ExecutableLocator.detections()[0] }
    func getCapabilities() -> AdapterCapabilities {
        AdapterCapabilities(sessionHistory: true, liveEvents: true, usage: true, approvals: true, cancel: true, resume: false, scope: "connection.owned")
    }
    func connect() async throws {
        guard let executable = executableOverride ?? detect().executable else { throw AdapterError.unavailable }
        transport.onMessage = { [weak self] message in self?.receive(message) }
        transport.onDisconnect = { [weak self] in
            self?.gate.removeAll(); self?.requestIDs.removeAll(); self?.owned.removeAll(); self?.itemDetails.removeAll(); self?.onDisconnect?()
        }
        try transport.start(executable: executable)
        do {
            _ = try await transport.request("initialize", params: .object([
                "clientInfo": .object(["name": .string("notchcraft"), "title": .string("NotchCraft"), "version": .string("0.1.1")]),
                "capabilities": .null
            ]))
            try transport.notify("initialized")
        } catch { transport.stop(); throw error }
    }
    func disconnect() { transport.stop(); gate.removeAll(); requestIDs.removeAll(); owned.removeAll(); itemDetails.removeAll() }
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
            "approvalPolicy": .string("untrusted"), "approvalsReviewer": .string("user")
        ]))
        guard let id = result["thread"]["id"].string else { throw AdapterError.invalidMessage }
        owned.insert(id)
        let session = ProviderSession(id: id, name: "Codex · \(id.prefix(8))", model: result["model"].string,
                                      cwd: project.path, updatedAt: Date(), owned: true)
        onSessionCreated?(session)
        continuation?.yield(AgentEvent(providerID: "codex", adapterID: "codex.app-server", agentID: id, sessionID: id,
                                       eventType: .sessionStarted, source: .appServer))
        _ = try await transport.request("turn/start", params: .object([
            "threadId": .string(id), "input": .array([.object(["type": .string("text"), "text": .string(prompt), "text_elements": .array([])])])
        ]))
        return session
    }
    private func receive(_ message: JSONValue) {
        if message["method"].string == "account/rateLimits/updated" { onQuotaUpdated?(message["params"]) }
        if message["method"].string == "item/started", let itemID = message["params"]["item"]["id"].string {
            let item = message["params"]["item"]
            if item["type"].string == "fileChange" {
                itemDetails[itemID] = item["changes"].array.prefix(40).compactMap { change in
                    guard let path = change["path"].string else { return nil }
                    return "\(change["kind"]["type"].string ?? "change"): \(path)"
                }.joined(separator: "\n")
            }
        }
        if message["method"].string == "item/completed", message["params"]["item"]["type"].string == "agentMessage",
           let session = message["params"]["threadId"].string, owned.contains(session),
           let text = message["params"]["item"]["text"].string {
            onOutput?(session, String(text.prefix(32_768)))
        }
        if message["method"].string == "turn/completed", let session = message["params"]["threadId"].string {
            for request in gate.pending.values where request.sessionID == session {
                gate.resolve(id: request.id); requestIDs.removeValue(forKey: request.id)
            }
        }
        if !message["id"].isNull, !message["method"].isNull {
            if var request = CodexNormalizer.permission(from: message), owned.contains(request.sessionID) {
                let p = message["params"]
                let context = [p["cwd"].string, p["reason"].string, p["networkApprovalContext"]["host"].string, p["grantRoot"].string, p["itemId"].string.flatMap { itemDetails[$0] }].compactMap { $0 }.filter { !$0.isEmpty }
                request.detail = String(([request.detail] + context).filter { !$0.isEmpty }.joined(separator: "\n").prefix(12_000))
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
            if let id = raw.string ?? raw.int.map(String.init) {
                if let request = gate.pending[id] {
                    continuation?.yield(AgentEvent(providerID: "codex", adapterID: "codex.app-server", agentID: request.sessionID,
                                                   sessionID: request.sessionID, taskID: request.taskID, eventType: .approvalResolved, source: .appServer))
                }
                gate.resolve(id: id); requestIDs.removeValue(forKey: id)
            }
        }
        if message["method"].string == "item/completed", let itemID = message["params"]["item"]["id"].string { itemDetails.removeValue(forKey: itemID) }
        for event in CodexNormalizer.events(from: message) where owned.contains(event.sessionID) { continuation?.yield(event) }
    }
}
