import Foundation

public enum AgentStatus: String, Codable, CaseIterable, Sendable {
    case unknown, idle, working, waitingApproval, completed, failed, cancelled
    public var isTerminal: Bool { [.completed, .failed, .cancelled].contains(self) }
}
public enum EventType: String, Codable, Sendable {
    case connected = "agent.connected", disconnected = "agent.disconnected"
    case sessionStarted = "session.started", taskStarted = "task.started"
    case toolStarted = "tool.started", toolCompleted = "tool.completed"
    case approvalRequested = "approval.requested", approvalResolved = "approval.resolved"
    case taskCompleted = "task.completed", taskFailed = "task.failed", taskCancelled = "task.cancelled"
    case usageUpdated = "usage.updated"
}
public enum EventSource: String, Codable, Sendable { case appServer, localLog, demo }
public enum ActivityType: String, Codable, CaseIterable, Sendable {
    case farming, mining, building, crafting, testing, repairing, research, automation, meeting, monitoring, resting, approval, storage
    public static func from(tool: String, command: String = "") -> Self {
        switch tool {
        case "fileChange": return .building
        case "webSearch": return .mining
        case "plan": return .farming
        case "collabAgentToolCall": return .meeting
        case "commandExecution":
            let words = command.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
            if words.contains(where: ["test", "pytest", "vitest", "jest", "check"].contains) { return .testing }
            if words.contains(where: ["build", "compile", "make"].contains) { return .crafting }
            return .automation
        default: return .research
        }
    }
}
public enum Measurement: String, Codable, Sendable { case actual, estimated }
public struct UsageMetrics: Codable, Equatable, Sendable {
    public var inputTokens: Int?
    public var outputTokens: Int?
    public var cachedInputTokens: Int?
    public var billingUSD: Double?
    public var subscriptionUsedPercent: Double?
    public var resetsAt: Date?
    public var source: String
    public var measuredAt: Date
    public var measurement: Measurement
    public var period: String
    public var model: String?
    public var account: String?
    public var totalTokens: Int? {
        guard let inputTokens, let outputTokens, inputTokens >= 0, outputTokens >= 0 else { return nil }
        let (total, overflow) = inputTokens.addingReportingOverflow(outputTokens)
        return overflow ? nil : total
    }
    public init(inputTokens: Int? = nil, outputTokens: Int? = nil, cachedInputTokens: Int? = nil,
                source: String, measuredAt: Date, measurement: Measurement = .actual, period: String = "session") {
        self.inputTokens = inputTokens; self.outputTokens = outputTokens; self.cachedInputTokens = cachedInputTokens
        self.source = source; self.measuredAt = measuredAt; self.measurement = measurement; self.period = period
    }
}
public struct AgentEvent: Codable, Identifiable, Equatable, Sendable {
    public var id: String { eventID }
    public var eventID: String
    public var schemaVersion = 1
    public var providerID: String
    public var adapterID: String
    public var agentID: String
    public var sessionID: String
    public var taskID: String?
    public var parentTaskID: String?
    public var projectID: String?
    public var eventType: EventType
    public var activityType: ActivityType
    public var timestamp: Date
    public var source: EventSource
    public var usage: UsageMetrics?
    public var permissionRequest: PermissionRequest?
    public var summary: String?
    public init(eventID: String = UUID().uuidString, providerID: String, adapterID: String, agentID: String,
                sessionID: String, taskID: String? = nil, eventType: EventType, activityType: ActivityType = .resting,
                timestamp: Date = Date(), source: EventSource, usage: UsageMetrics? = nil,
                permissionRequest: PermissionRequest? = nil, summary: String? = nil) {
        self.eventID = eventID; self.providerID = providerID; self.adapterID = adapterID; self.agentID = agentID
        self.sessionID = sessionID; self.taskID = taskID; self.eventType = eventType; self.activityType = activityType
        self.timestamp = timestamp; self.source = source; self.usage = usage
        self.permissionRequest = permissionRequest; self.summary = summary
    }
}
public struct SessionSnapshot: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var providerID: String
    public var status: AgentStatus = .unknown
    public var lastConfirmedStatus: AgentStatus = .unknown
    public var activity: ActivityType = .resting
    public var taskID: String?
    public var lastUpdated: Date
    public var toolCount = 0
    public var usage: UsageMetrics?
}
public struct PermissionRequest: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var providerID: String
    public var adapterID: String
    public var sessionID: String
    public var taskID: String
    public var title: String
    public var detail: String
    public init(id: String, providerID: String, adapterID: String, sessionID: String, taskID: String, title: String, detail: String) {
        self.id = id; self.providerID = providerID; self.adapterID = adapterID; self.sessionID = sessionID
        self.taskID = taskID; self.title = title; self.detail = detail
    }
}
public enum PermissionError: Error, Equatable { case notOwned, targetMismatch, noLongerPending }
public struct PermissionGate: Sendable {
    public private(set) var pending: [String: PermissionRequest] = [:]
    public init() {}
    public mutating func register(_ request: PermissionRequest) { pending[request.id] = request }
    public func validate(id: String, sessionID: String, taskID: String, owned: Bool) throws -> PermissionRequest {
        guard owned else { throw PermissionError.notOwned }
        guard let request = pending[id] else { throw PermissionError.noLongerPending }
        guard request.sessionID == sessionID, request.taskID == taskID,
              request.providerID == "codex", request.adapterID == "codex.app-server" else { throw PermissionError.targetMismatch }
        return request
    }
    public mutating func resolve(id: String) { pending.removeValue(forKey: id) }
    public mutating func removeAll() { pending.removeAll() }
}

public struct UsageAggregate: Equatable, Sendable {
    public let inputTokens: Int?
    public let outputTokens: Int?
    public init(_ values: [UsageMetrics]) {
        func sum(_ key: KeyPath<UsageMetrics, Int?>) -> Int? {
            guard !values.isEmpty else { return nil }
            var total=0
            for value in values {
                guard let count=value[keyPath:key], count >= 0 else { return nil }
                let (next,overflow)=total.addingReportingOverflow(count)
                guard !overflow else { return nil }; total=next
            }
            return total
        }
        inputTokens=sum(\.inputTokens); outputTokens=sum(\.outputTokens)
    }
}
