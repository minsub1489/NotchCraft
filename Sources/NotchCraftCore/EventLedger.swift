import Foundation

public enum EventDisposition: Equatable, Sendable { case applied, duplicate, outdated, invalid }
public struct EventLedger: Sendable {
    public private(set) var sessions: [String: SessionSnapshot] = [:]
    private var seen: Set<String> = []
    private var seenOrder: [String] = []
    private let acceptsDemo: Bool
    public init(acceptsDemo: Bool = false) { self.acceptsDemo = acceptsDemo }
    @discardableResult public mutating func apply(_ event: AgentEvent, now: Date = Date()) -> EventDisposition {
        guard event.schemaVersion == 1, !event.eventID.isEmpty, event.eventID.count <= 256,
              !event.sessionID.isEmpty, event.sessionID.count <= 256, !event.providerID.isEmpty,
              !event.adapterID.isEmpty, !event.agentID.isEmpty,
              event.timestamp.timeIntervalSince(now) <= 300,
              event.source != .demo || acceptsDemo else { return .invalid }
        guard !seen.contains(event.eventID) else { return .duplicate }
        seen.insert(event.eventID); seenOrder.append(event.eventID)
        if seenOrder.count > 10_000 { seen.remove(seenOrder.removeFirst()) }
        var session = sessions[event.sessionID] ?? SessionSnapshot(id: event.sessionID, providerID: event.providerID, lastUpdated: event.timestamp)
        guard session.providerID == event.providerID else { return .invalid }
        guard event.timestamp >= session.lastUpdated else { return .outdated }
        if let current = session.taskID, let incoming = event.taskID, current != incoming,
           ![EventType.taskStarted, .sessionStarted, .connected, .disconnected].contains(event.eventType) { return .outdated }
        if session.status.isTerminal, event.taskID == session.taskID,
           [.toolStarted, .toolCompleted, .activityChanged, .approvalRequested, .approvalResolved].contains(event.eventType) { return .outdated }
        session.lastUpdated = event.timestamp
        if let taskID = event.taskID { session.taskID = taskID }
        switch event.eventType {
        case .connected, .sessionStarted: session.status = .idle; session.activity = .resting
        case .disconnected: session.status = .unknown
        case .taskStarted: session.status = .working; session.activity = event.activityType
        case .toolStarted:
            session.status = .working; session.activity = event.activityType; session.toolCount += 1
        case .activityChanged: session.activity = event.activityType
        case .toolCompleted: break
        case .approvalRequested: session.status = .waitingApproval; session.activity = .approval
        case .approvalResolved: session.status = .working; session.activity = .research
        case .taskCompleted: session.status = .completed; session.activity = .storage
        case .taskFailed: session.status = .failed; session.activity = .repairing
        case .taskCancelled: session.status = .cancelled; session.activity = .resting
        case .usageUpdated: break
        }
        if let usage = event.usage { session.usage = usage }
        if event.eventType != .disconnected { session.lastConfirmedStatus = session.status }
        sessions[event.sessionID] = session
        return .applied
    }
    public mutating func markDisconnected(providerID: String) {
        for id in sessions.keys where sessions[id]?.providerID == providerID { sessions[id]?.status = .unknown }
    }
}
