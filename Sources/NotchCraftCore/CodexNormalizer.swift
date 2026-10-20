import Foundation

/// Deliberately discards user messages, reasoning text, tool output and assistant response bodies.
public enum CodexNormalizer {
    public static func events(from message: JSONValue, receivedAt: Date = Date()) -> [AgentEvent] {
        let params = message["params"]
        guard let method = message["method"].string, let session = params["threadId"].string, !session.isEmpty else { return [] }
        let task = params["turnId"].string ?? params["turn"]["id"].string
        var type: EventType
        var activity: ActivityType = .research
        var usage: UsageMetrics?
        var summary: String?
        var identity: String?
        switch method {
        case "turn/started": type = .taskStarted; identity = task
        case "turn/completed":
            switch params["turn"]["status"].string {
            case "completed": type = .taskCompleted
            case "interrupted": type = .taskCancelled
            case "failed": type = .taskFailed
            default: return []
            }
            identity = task
        case "item/started", "item/completed":
            let item = params["item"]
            guard let tool = item["type"].string,
                  !["userMessage", "agentMessage", "hookPrompt"].contains(tool) else { return [] }
            type = method == "item/started" ? .toolStarted : .toolCompleted
            activity = .from(tool: tool, command: item["command"].string ?? "")
            summary = tool; identity = item["id"].string
        case "thread/tokenUsage/updated":
            let total = params["tokenUsage"]["total"]
            type = .usageUpdated
            usage = UsageMetrics(inputTokens: total["inputTokens"].int, outputTokens: total["outputTokens"].int,
                                 cachedInputTokens: total["cachedInputTokens"].int, source: "Codex App Server · thread/tokenUsage/updated", measuredAt: receivedAt)
        case "turn/plan/updated": type = .toolStarted; activity = .farming; summary = "plan"
        case "error":
            // A retryable stream error does not prove the task has failed.
            return []
        default: return []
        }
        let eventID = identity.map { "codex:\(session):\(method):\($0)" } ?? UUID().uuidString
        return [AgentEvent(eventID: eventID, providerID: "codex", adapterID: "codex.app-server", agentID: session,
                           sessionID: session, taskID: task, eventType: type, activityType: activity,
                           timestamp: receivedAt, source: .appServer, usage: usage, summary: summary)]
    }
    public static func permission(from message: JSONValue) -> PermissionRequest? {
        guard let method = message["method"].string,
              ["item/commandExecution/requestApproval", "item/fileChange/requestApproval"].contains(method),
              let id = message["id"].string ?? message["id"].int.map(String.init),
              let session = message["params"]["threadId"].string, !session.isEmpty,
              let task = message["params"]["turnId"].string, !task.isEmpty else { return nil }
        return PermissionRequest(id: id, providerID: "codex", adapterID: "codex.app-server", sessionID: session,
                                 taskID: task, title: method.contains("commandExecution") ? "approval.command" : "approval.files",
                                 detail: String((message["params"]["command"].string ?? message["params"]["reason"].string ?? "").prefix(8_000)))
    }
}
