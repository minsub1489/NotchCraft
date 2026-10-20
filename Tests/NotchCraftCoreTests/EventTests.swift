import Foundation
import CoreGraphics
import Testing
@testable import NotchCraftCore

private let epoch = Date(timeIntervalSince1970: 1_800_000_000)
private func event(_ type: EventType, id: String = UUID().uuidString, at offset: Double = 0,
                   session: String = "s1", task: String? = "t1", activity: ActivityType = .building) -> AgentEvent {
    AgentEvent(eventID: id, providerID: "codex", adapterID: "codex.app-server", agentID: session,
               sessionID: session, taskID: task, eventType: type, activityType: activity,
               timestamp: epoch.addingTimeInterval(offset), source: .appServer)
}

@Test func disconnectedAgentIsNeverWorking() {
    var ledger = EventLedger()
    #expect(ledger.apply(event(.connected), now: epoch) == .applied)
    #expect(ledger.sessions["s1"]?.status == .idle)
    _ = ledger.apply(event(.taskStarted, at: 1), now: epoch.addingTimeInterval(1))
    #expect(ledger.sessions["s1"]?.status == .working)
    _ = ledger.apply(event(.disconnected, at: 2), now: epoch.addingTimeInterval(2))
    #expect(ledger.sessions["s1"]?.status == .unknown)
    #expect(ledger.sessions["s1"]?.lastConfirmedStatus == .working)
}
@Test func duplicateAndOldEventsCannotRewindState() {
    var ledger = EventLedger()
    let start = event(.taskStarted, id: "start", at: 2)
    #expect(ledger.apply(start, now: epoch.addingTimeInterval(3)) == .applied)
    #expect(ledger.apply(start, now: epoch.addingTimeInterval(3)) == .duplicate)
    #expect(ledger.apply(event(.connected, at: 1), now: epoch.addingTimeInterval(3)) == .outdated)
    #expect(ledger.sessions["s1"]?.status == .working)
}
@Test func terminalTaskCannotBeRestartedByLateTool() {
    var ledger = EventLedger()
    _ = ledger.apply(event(.taskCompleted), now: epoch)
    #expect(ledger.apply(event(.toolStarted, at: 1), now: epoch.addingTimeInterval(1)) == .outdated)
    #expect(ledger.sessions["s1"]?.status == .completed)
    #expect(ledger.apply(event(.taskStarted, at: 2, task: "t2"), now: epoch.addingTimeInterval(2)) == .applied)
}
@Test func priorTaskCannotCompleteCurrentTask() {
    var ledger = EventLedger()
    _ = ledger.apply(event(.taskStarted, task: "new"), now: epoch)
    #expect(ledger.apply(event(.taskFailed, at: 1, task: "old"), now: epoch.addingTimeInterval(1)) == .outdated)
    #expect(ledger.sessions["s1"]?.taskID == "new")
}
@Test func invalidEventsAreRejected() {
    var ledger = EventLedger()
    #expect(ledger.apply(event(.taskStarted, session: ""), now: epoch) == .invalid)
    #expect(ledger.apply(event(.taskStarted, at: 400), now: epoch) == .invalid)
    var value = event(.connected)
    value.schemaVersion = 99
    #expect(ledger.apply(value, now: epoch) == .invalid)
}
@Test func approvalAndResumeFollowObservedEvents() {
    var ledger = EventLedger()
    for type in [EventType.taskStarted, .approvalRequested, .approvalResolved, .taskCompleted] {
        _ = ledger.apply(event(type), now: epoch)
    }
    #expect(ledger.sessions["s1"]?.status == .completed)
}
@Test func demoCannotContaminateLiveLedger() {
    var ledger = EventLedger()
    var value = event(.taskStarted)
    value.source = .demo
    #expect(ledger.apply(value, now: epoch) == .invalid)
    var demo = EventLedger(acceptsDemo: true)
    #expect(demo.apply(value, now: epoch) == .applied)
}
@Test func staleConnectionExpiresWithoutInventingCompletion() {
    var ledger = EventLedger()
    _ = ledger.apply(event(.taskStarted), now: epoch)
    ledger.markDisconnected(providerID: "codex")
    #expect(ledger.sessions["s1"]?.status == .unknown)
    #expect(ledger.sessions["s1"]?.lastUpdated == epoch)
}
@Test func twentyFourSessionsRemainDistinct() {
    var ledger = EventLedger()
    for i in 0..<24 { _ = ledger.apply(event(.taskStarted, session: "session-\(i)"), now: epoch) }
    #expect(ledger.sessions.count == 24)
    #expect(ledger.sessions.values.allSatisfy { $0.status == .working })
}
@Test func activityMappingIsBasedOnActualTool() {
    #expect(ActivityType.from(tool: "commandExecution", command: "swift test") == .testing)
    #expect(ActivityType.from(tool: "commandExecution", command: "npm run build") == .crafting)
    #expect(ActivityType.from(tool: "fileChange") == .building)
    #expect(ActivityType.from(tool: "webSearch") == .mining)
    #expect(ActivityType.from(tool: "reasoning") == .research)
    #expect(ActivityType.from(tool: "futureUnknownTool") == .research)
}
@Test func missingUsageRemainsUnknown() {
    let usage = UsageMetrics(source: "test", measuredAt: epoch)
    #expect(usage.totalTokens == nil)
    #expect(usage.billingUSD == nil)
    #expect(usage.subscriptionUsedPercent == nil)
    let measured = UsageMetrics(inputTokens: 100, outputTokens: 30, source: "app-server", measuredAt: epoch)
    #expect(measured.totalTokens == 130)
    #expect(measured.measurement == .actual)
}
@Test func permissionIsBoundToProviderSessionTaskAndOwnership() throws {
    let request = PermissionRequest(id: "r1", providerID: "codex", adapterID: "codex.app-server",
                                    sessionID: "s1", taskID: "t1", title: "Run command", detail: "swift test")
    var gate = PermissionGate()
    gate.register(request)
    #expect(throws: PermissionError.notOwned) { try gate.validate(id: "r1", sessionID: "s1", taskID: "t1", owned: false) }
    #expect(throws: PermissionError.targetMismatch) { try gate.validate(id: "r1", sessionID: "s2", taskID: "t1", owned: true) }
    #expect(throws: PermissionError.targetMismatch) { try gate.validate(id: "r1", sessionID: "s1", taskID: "t2", owned: true) }
    #expect(try gate.validate(id: "r1", sessionID: "s1", taskID: "t1", owned: true) == request)
    gate.resolve(id: "r1")
    #expect(throws: PermissionError.noLongerPending) { try gate.validate(id: "r1", sessionID: "s1", taskID: "t1", owned: true) }
}
@Test func boundedFramingSupportsPartialAndMultipleMessages() throws {
    var framer = LineFramer(maximumBytes: 20)
    #expect(try framer.append(Data("{\"id\":".utf8)).isEmpty)
    let frames = try framer.append(Data("1}\n{}\n".utf8))
    #expect(frames.map { String(decoding: $0, as: UTF8.self) } == ["{\"id\":1}", "{}"])
}
@Test func framingRejectsOversizeEvenWithoutNewline() {
    var framer = LineFramer(maximumBytes: 8)
    #expect(throws: FramingError.tooLarge) { try framer.append(Data(repeating: 65, count: 9)) }
}
@Test func geometryUsesActualCameraGapAndSupportsExternalScreen() {
    let frame = CGRect(x: 1920, y: 0, width: 1512, height: 982)
    let geometry = NotchGeometry(screenFrame: frame, visibleFrame: frame.insetBy(dx: 0, dy: 24),
                                 topInset: 32, leftAreaMaxX: 2580, rightAreaMinX: 2772)
    #expect(geometry.cameraWidth == 192)
    #expect(geometry.centerX == 2676)
    #expect(geometry.collapsedFrame.maxY == frame.maxY)
    let external = NotchGeometry(screenFrame: frame, visibleFrame: frame, topInset: 0)
    #expect(external.cameraWidth == 0)
    #expect(external.collapsedFrame.midX == frame.midX)
}
@Test func jsonValueRoundTripsWithoutLoss() throws {
    let value: JSONValue = .object(["id": .int(1), "ok": .bool(true), "items": .array([.null, .string("한글")])])
    #expect(try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value)) == value)
}
@Test func archivePersistsMetadataOnlyAndUsesBoundParameters() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
    defer { try? FileManager.default.removeItem(at: url) }
    do {
        let archive = try EventArchive(url: url)
        var value = event(.taskStarted, session: "s'; DROP TABLE events;--")
        value.summary = "도구 실행"
        try archive.record(value)
        try archive.record(value)
        #expect(try archive.recent(limit: 20).count == 1)
    }
    let reopened = try EventArchive(url: url)
    #expect(try reopened.recent(limit: 20).first?.summary == EventType.taskStarted.rawValue)
    try reopened.deleteAll()
    #expect(try reopened.recent(limit: 20).isEmpty)
}
