import Foundation
import CoreGraphics
import Testing
@testable import NotchCraftCore

private func quotaJSON(_ text:String) throws -> JSONValue { try JSONDecoder().decode(JSONValue.self,from:Data(text.utf8)) }
@Test func quotaDistinguishesUsedFromRemainingAndKeepsWeeklyPeriod() throws {
    let input=try quotaJSON(#"{"rateLimits":{"limitId":"codex","primary":{"usedPercent":47,"windowDurationMins":300,"resetsAt":1900000000},"secondary":{"usedPercent":7,"windowDurationMins":10080,"resetsAt":1900003600}}}"#)
    let snapshot=AccountQuotaSnapshot(response:input,receivedAt:Date(timeIntervalSince1970:1800000000))
    let bucket=try #require(snapshot.buckets.first)
    #expect(bucket.windows[0].usedPercent == 47)
    #expect(bucket.windows[0].remainingPercent == 53)
    #expect(bucket.windows[0].period == .hours(5))
    #expect(bucket.windows[1].remainingPercent == 93)
    #expect(bucket.windows[1].period == .weeks(1))
}
@Test func quotaKeepsDifferentLimitBucketsSeparateWithoutDuplicatingLegacy() throws {
    let input=try quotaJSON(#"{"rateLimits":{"limitId":"codex","primary":{"usedPercent":99}},"rateLimitsByLimitId":{"codex":{"limitId":"codex","primary":{"usedPercent":47}},"review":{"limitId":"review","limitName":"Code review","primary":{"usedPercent":12}}}}"#)
    let snapshot=AccountQuotaSnapshot(response:input,receivedAt:Date())
    #expect(snapshot.buckets.count == 2)
    #expect(snapshot.buckets.first(where:{$0.id == "codex"})?.windows.first?.usedPercent == 47)
    #expect(snapshot.buckets.first(where:{$0.id == "review"})?.name == "Code review")
}
@Test func quotaDoesNotTurnMissingOrInvalidFieldsIntoZero() throws {
    let input=try quotaJSON(#"{"rateLimits":{"primary":{"usedPercent":null},"secondary":{"usedPercent":-2}}}"#)
    #expect(AccountQuotaSnapshot(response:input,receivedAt:Date()).buckets.isEmpty)
    let explicit=try quotaJSON(#"{"rateLimits":{"primary":{"remainingPercent":61,"windowDurationMins":10080}}}"#)
    #expect(AccountQuotaSnapshot(response:explicit,receivedAt:Date()).buckets.first?.windows.first?.remainingPercent == 61)
    #expect(QuotaPeriod(minutes:nil) == .unknown)
    #expect(QuotaPeriod(minutes:1440) == .days(1))
}
@Test func quotaExpirationAndPushUpdatesNeverInventAReset() throws {
    let input=try quotaJSON(#"{"rateLimits":{"limitId":"codex","primary":{"usedPercent":47,"resetsAt":1800000005}}}"#)
    let snapshot=AccountQuotaSnapshot(response:input,receivedAt:Date(timeIntervalSince1970:1800000000))
    #expect(snapshot.isStale(at:Date(timeIntervalSince1970:1800000006)))
    let updated=try quotaJSON(#"{"rateLimits":{"limitId":"codex","primary":{"usedPercent":49}}}"#)
    let merged=snapshot.merging(response:updated,receivedAt:Date(timeIntervalSince1970:1800000006))
    #expect(merged.buckets.first?.windows.first?.remainingPercent == 51)
}
@Test func notchInformationIsBelowBothMenuBarAndPhysicalCamera() {
    let screen=CGRect(x:1920,y:120,width:1512,height:982)
    let visible=CGRect(x:1920,y:120,width:1512,height:950)
    let geometry=NotchGeometry(screenFrame:screen,visibleFrame:visible,topInset:32,leftAreaMaxX:2580,rightAreaMinX:2772)
    #expect(geometry.collapsedFrame.maxY <= screen.maxY - 32)
    #expect(geometry.expandedFrame.maxY <= visible.maxY)
    #expect(geometry.collapsedFrame.height >= 32)
    #expect(geometry.collapsedFrame.midX == 2676)
    let external=NotchGeometry(screenFrame:screen,visibleFrame:visible,topInset:0)
    #expect(external.collapsedFrame.maxY <= visible.maxY)
}
@Test func workMotionsMatchActivityAndHaveDifferentPoses() {
    #expect(WorkerMotion.kind(for:.farming,status:.working) == .planting)
    #expect(WorkerMotion.kind(for:.mining,status:.working) == .mining)
    #expect(WorkerMotion.kind(for:.monitoring,status:.working) == .patrolling)
    #expect(WorkerMotion.kind(for:.research,status:.working) == .reading)
    let motions:[WorkerMotionKind]=[.planting,.mining,.patrolling,.reading,.hammering]
    let poses=motions.map { WorkerMotion.pose(kind:$0,elapsed:0.8) }
    #expect(Set(poses.map { $0.rightArm }).count >= 4)
}
@Test func workMotionStopsWhenNotWorkingOrReduced() {
    for state in [AgentStatus.unknown,.idle,.waitingApproval,.failed,.cancelled,.completed] {
        let kind=WorkerMotion.kind(for:.mining,status:state)
        #expect(WorkerMotion.pose(kind:kind,elapsed:0.2) == WorkerMotion.pose(kind:kind,elapsed:3))
    }
    #expect(WorkerMotion.pose(kind:.planting,elapsed:0.2,reduced:true) == WorkerMotion.pose(kind:.planting,elapsed:2.4,reduced:true))
    #expect(WorkerMotion.pose(kind:.planting,elapsed:1.9,reduced:true).seedProgress == nil)
}
@Test func plantingSeedsMiningContactAndPatrolStrideActuallyOccur() {
    let times=stride(from:0.0,to:8.0,by:0.08)
    #expect(times.contains { WorkerMotion.pose(kind:.planting,elapsed:$0).seedProgress != nil })
    #expect(times.contains { WorkerMotion.pose(kind:.mining,elapsed:$0).impact > 0.5 })
    let early=WorkerMotion.pose(kind:.patrolling,elapsed:0.3)
    let later=WorkerMotion.pose(kind:.patrolling,elapsed:1.1)
    #expect(early.pathOffset != later.pathOffset)
    #expect(early.leftLeg != later.leftLeg)
    #expect(WorkerMotion.pose(kind:.reading,elapsed:3.8).pageTurn != WorkerMotion.pose(kind:.reading,elapsed:4.2).pageTurn)
}
