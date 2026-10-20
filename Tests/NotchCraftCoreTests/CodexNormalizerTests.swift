import Foundation
import Testing
@testable import NotchCraftCore

private func json(_ text: String) throws -> JSONValue { try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8)) }
@Test func normalizerUsesActualToolAndStableEventIDs() throws {
    let message = try json(#"{"method":"item/started","params":{"threadId":"s","turnId":"t","item":{"id":"i","type":"commandExecution","command":"swift test"}}}"#)
    let first = CodexNormalizer.events(from: message)
    #expect(first.count == 1)
    #expect(first.first?.activityType == .testing)
    #expect(first.first?.eventID == CodexNormalizer.events(from: message).first?.eventID)
    #expect(first.first?.summary == "commandExecution")
}
@Test func normalizerDoesNotPersistPromptOrResponseText() throws {
    let message = try json(#"{"method":"item/completed","params":{"threadId":"s","turnId":"t","item":{"id":"i","type":"agentMessage","text":"PRIVATE RESPONSE"}}}"#)
    let events = CodexNormalizer.events(from: message)
    #expect(events.isEmpty)
}
@Test func usageUsesMeasuredCumulativeTotals() throws {
    let message = try json(#"{"method":"thread/tokenUsage/updated","params":{"threadId":"s","turnId":"t","tokenUsage":{"total":{"inputTokens":123,"outputTokens":45,"cachedInputTokens":10}}}}"#)
    let metrics = CodexNormalizer.events(from: message).first?.usage
    #expect(metrics?.totalTokens == 168)
    #expect(metrics?.billingUSD == nil)
}
@Test func interruptedTurnMapsToCancellation() throws {
    let message = try json(#"{"method":"turn/completed","params":{"threadId":"s","turn":{"id":"t","status":"interrupted"}}}"#)
    #expect(CodexNormalizer.events(from: message).first?.eventType == .taskCancelled)
}
@Test func requestsRequireTargetAndSupportedMethod() throws {
    let valid = try json(#"{"id":42,"method":"item/commandExecution/requestApproval","params":{"threadId":"s","turnId":"t","command":"swift test"}}"#)
    #expect(CodexNormalizer.permission(from: valid)?.id == "42")
    let unknown = try json(#"{"id":42,"method":"item/tool/requestUserInput","params":{"threadId":"s","turnId":"t"}}"#)
    #expect(CodexNormalizer.permission(from: unknown) == nil)
    let noTarget = try json(#"{"id":42,"method":"item/fileChange/requestApproval","params":{"threadId":"s"}}"#)
    #expect(CodexNormalizer.permission(from: noTarget) == nil)
}
