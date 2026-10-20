import SwiftUI
import AppKit
import NotchCraftCore

@main struct NotchCraftApp:App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body:some Scene {
        WindowGroup("NotchCraft",id:"workspace") {
            WorkspaceView().environment(delegate.store).background(WindowReader { delegate.attach($0) })
        }
        .defaultSize(width:1420,height:900).windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing:.newItem) {
                Button(L("new.start")) { delegate.store.showNewTask=true }.keyboardShortcut("n").disabled(!delegate.store.isConnected || delegate.store.isDemo)
                Button(L("notch.open")) { delegate.openWorkspace() }.keyboardShortcut("o",modifiers:[.command,.shift])
            }
            CommandGroup(replacing:.appSettings) { Button(L("common.settings")) { delegate.store.showSettings=true }.keyboardShortcut(",") }
        }
        Settings { SettingsPanel().environment(delegate.store) }
    }
}
@MainActor final class AppDelegate:NSObject,NSApplicationDelegate,NSWindowDelegate {
    let store=WorkspaceStore()
    private var notch:NotchController?
    private weak var mainWindow:NSWindow?
    func applicationDidFinishLaunching(_ notification:Notification) {
        NSApp.setActivationPolicy(.regular)
        notch=NotchController(store:store)
        store.onOpenWorkspace={ [weak self] in self?.openWorkspace() }
        store.onCollapse={ [weak self] in self?.mainWindow?.orderOut(nil); self?.store.workspaceVisible=false; self?.notch?.show() }
        store.onPin={ [weak self] pinned in self?.mainWindow?.level=pinned ? .floating:.normal }
        store.onNotchVisibility={ [weak self] visible in if visible { self?.notch?.show() } else { self?.notch?.hide() } }
        notch?.show()
        if CommandLine.arguments.contains("--stress-demo") { store.finishWelcome(); store.setDemo(true,residentCount:24) }
        if CommandLine.arguments.contains("--demo") { store.finishWelcome(); store.setDemo(true) }
        if CommandLine.arguments.contains("--live-smoke") {
            store.finishWelcome()
            Task {
                await store.connect()
                let result:[String:Any] = ["connected":store.isConnected,"sessionCount":store.sessions.count,"quotaAvailable":!store.quota.isNull,"modelTurnsStarted":0]
                if let data=try? JSONSerialization.data(withJSONObject:result,options:.sortedKeys),let path=ProcessInfo.processInfo.environment["NOTCHCRAFT_SMOKE_OUTPUT"] { try? data.write(to:URL(fileURLWithPath:path)) }
                NSApp.terminate(nil)
            }
        }
    }
    func attach(_ window:NSWindow) {
        guard mainWindow !== window else { return }; mainWindow=window
        window.delegate=self; window.title="NotchCraft"; window.backgroundColor = .black
        window.isMovableByWindowBackground=true; window.titlebarAppearsTransparent=true
        window.minSize=CGSize(width:1100,height:730)
        window.standardWindowButton(.closeButton)?.isHidden=true
        window.standardWindowButton(.miniaturizeButton)?.isHidden=true
        window.standardWindowButton(.zoomButton)?.isHidden=true
    }
    func openWorkspace() { mainWindow?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true); store.workspaceVisible=true }
    func windowShouldClose(_ sender:NSWindow) -> Bool { sender.orderOut(nil); store.workspaceVisible=false; return false }
    func windowDidChangeOcclusionState(_ notification:Notification) { store.workspaceVisible=mainWindow?.occlusionState.contains(.visible) == true }
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows:Bool) -> Bool { openWorkspace(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification:Notification) { store.shutdown(); notch?.teardown() }
}
struct WindowReader:NSViewRepresentable {
    let onWindow:(NSWindow)->Void
    func makeNSView(context:Context)->WindowReaderView { let view=WindowReaderView(); view.onWindow=onWindow; return view }
    func updateNSView(_ view:WindowReaderView,context:Context) {}
}
final class WindowReaderView:NSView {
    var onWindow:((NSWindow)->Void)?
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); if let window { onWindow?(window) } }
}
struct WindowControls:View {
    var body:some View {
        HStack(spacing:8) {
            Button { NSApp.keyWindow?.performClose(nil) } label:{ Circle().fill(Color(hex:0xEC6A5F)).frame(width:10,height:10) }.help(L("common.close"))
            Button { NSApp.keyWindow?.miniaturize(nil) } label:{ Circle().fill(Color(hex:0xE9B64E)).frame(width:10,height:10) }.help(L("notch.hide"))
            Button { NSApp.keyWindow?.toggleFullScreen(nil) } label:{ Circle().fill(Color(hex:0x61BC62)).frame(width:10,height:10) }.help(L("notch.open"))
        }.buttonStyle(.plain).padding(.trailing,4)
    }
}
