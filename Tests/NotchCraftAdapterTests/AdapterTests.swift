import Foundation
import AppKit
import SpriteKit
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
    var pushedQuota:JSONValue = .null
    adapter.onQuotaUpdated = { pushedQuota=$0 }
    defer { adapter.disconnect() }
    let stream=adapter.subscribeEvents()
    try await adapter.connect()
    #expect(adapter.isConnected)
    let histories=try await adapter.listSessions()
    #expect(histories.count == 1)
    #expect(histories.first?.owned == false)
    #expect(try await adapter.getUsage()["rateLimits"]["primary"]["usedPercent"].int == 25)
    #expect(try await adapter.getUsage()["rateLimits"]["primary"]["usedPercent"].int == 26)
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
    let quota=AccountQuotaSnapshot(response:pushedQuota,receivedAt:Date())
    #expect(quota.buckets.first?.windows.first?.remainingPercent == 73)
    #expect(quota.buckets.first?.windows.last?.period == .weeks(1))
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

@MainActor @Test func voxelWorldRendersAndHandlesTwentyFourResidents() throws {
    let scene=OfficeScene(size:WorldArtwork.size)
    let view=SKView(frame:CGRect(origin:.zero,size:WorldArtwork.size))
    view.presentScene(scene)
    var ledger=EventLedger(acceptsDemo:true)
    let sessions=(0..<24).map { index in
        ProviderSession(id:"resident-\(index)",name:"DEMO \(index)",cwd:"",updatedAt:Date())
    }
    for session in sessions {
        _ = ledger.apply(AgentEvent(providerID:"demo",adapterID:"demo",agentID:session.id,sessionID:session.id,
                                    taskID:"task",eventType:.taskStarted,activityType:.building,source:.demo))
    }
    scene.sync(sessions:sessions,snapshots:ledger.sessions,selected:sessions.last?.id,reduceMotion:true)
    #expect(scene.childNode(withName:"//resident-23") != nil)
    let texture=try #require(view.texture(from:scene))
    let bitmap=NSBitmapImageRep(cgImage:texture.cgImage())
    var swatches=Set<String>()
    for x in stride(from:0,to:bitmap.pixelsWide,by:40) {
        for y in stride(from:0,to:bitmap.pixelsHigh,by:40) {
            if let c=bitmap.colorAt(x:x,y:y) { swatches.insert(c.description) }
        }
    }
    #expect(swatches.count > 20) // Actual rendered island has multiple materials, not a blank/gray surface.
    scene.sync(sessions:[],snapshots:[:],selected:nil,reduceMotion:true)
    #expect(scene.childNode(withName:"//resident-23") == nil)
    view.presentScene(nil)
}

@Test func weeklyUsageHasFriendlyLocalizedTitle() {
    #expect(quotaPeriodTitle(.weeks(1),language:"ko") == "1주일 사용량")
    #expect(quotaPeriodTitle(.hours(5),language:"ko") == "5시간 사용량")
    #expect(quotaPeriodTitle(.weeks(1),language:"en") == "1-week usage")
}
@MainActor @Test func workingResidentMovesLimbsAndStopsOnApproval() throws {
    let session=ProviderSession(id:"motion-test",name:"DEMO",cwd:"",updatedAt:Date())
    let worker=WorkerNode(index:0,session:session)
    worker.configure(activity:.mining,status:.working,taskID:"turn",reduced:false,selected:false)
    worker.render(elapsed:0.4)
    let arm=try #require(worker.childNode(withName:"//arm-right"))
    let before=arm.zRotation
    worker.render(elapsed:1.3)
    #expect(arm.zRotation != before)
    worker.configure(activity:.mining,status:.waitingApproval,taskID:"turn",reduced:false,selected:false)
    worker.render(elapsed:0.4); let waiting=arm.zRotation
    worker.render(elapsed:2.7)
    #expect(arm.zRotation == waiting)
    #expect(worker.childNode(withName:"//tool")?.isHidden == true)
    worker.configure(activity:.research,status:.working,taskID:"turn",reduced:false,selected:false)
    #expect(worker.childNode(withName:"//book")?.isHidden == false)
}
@MainActor @Test func notchPanelNativeFrameStaysBelowMenuBar() {
    _ = NSApplication.shared
    for screen in NSScreen.screens {
        let geometry=NotchGeometry(screenFrame:screen.frame,visibleFrame:screen.visibleFrame,topInset:screen.safeAreaInsets.top,
                                   leftAreaMaxX:screen.auxiliaryTopLeftArea?.maxX,rightAreaMinX:screen.auxiliaryTopRightArea?.minX)
        let panel=NotchPanel(contentRect:.zero,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.isReleasedWhenClosed=false
        panel.setFrame(geometry.collapsedFrame,display:false)
        #expect(abs(panel.frame.maxY-geometry.contentTopY) < 0.5)
        #expect(panel.frame.maxY <= screen.visibleFrame.maxY)
        panel.setFrame(geometry.expandedFrame,display:false)
        #expect(abs(panel.frame.maxY-geometry.contentTopY) < 0.5)
        #expect(panel.frame.size == geometry.expandedFrame.size)
        panel.close()
    }
}
