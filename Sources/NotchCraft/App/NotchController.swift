import AppKit
import SwiftUI
import Observation
import NotchCraftCore

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
@MainActor @Observable final class NotchController {
    var expanded=false
    var geometry=NotchGeometry(screenFrame:.zero,visibleFrame:.zero,topInset:0)
    private var panel:NotchPanel?
    private var hoverTask:Task<Void,Never>?
    private var observers:[NSObjectProtocol]=[]
    private let store:WorkspaceStore
    init(store:WorkspaceStore) {
        self.store=store
        observers.append(NotificationCenter.default.addObserver(forName:NSApplication.didChangeScreenParametersNotification,object:nil,queue:.main) { [weak self] _ in Task { @MainActor in self?.reposition() } })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.didWakeNotification,object:nil,queue:.main) { [weak self] _ in Task { @MainActor in self?.reposition() } })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.activeSpaceDidChangeNotification,object:nil,queue:.main) { [weak self] _ in Task { @MainActor in self?.reposition() } })
    }
    func show() {
        guard store.showNotch else { return }
        if panel == nil {
            let window=NotchPanel(contentRect:.zero,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
            window.isOpaque=false; window.backgroundColor = .clear; window.hasShadow=false
            window.level=NSWindow.Level(rawValue:NSWindow.Level.statusBar.rawValue+1)
            window.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.stationary,.ignoresCycle]
            window.hidesOnDeactivate=false; window.isFloatingPanel=true; window.isReleasedWhenClosed=false
            window.acceptsMouseMovedEvents=true; window.animationBehavior = .none
            window.contentView=NSHostingView(rootView:NotchView(controller:self).environment(store))
            panel=window
        }
        reposition(); panel?.orderFrontRegardless()
    }
    func hide() { hoverTask?.cancel(); expanded=false; panel?.orderOut(nil) }
    func reposition() {
        guard let screen=NSScreen.screens.first(where:{$0.safeAreaInsets.top > 0}) ?? NSScreen.screens.first else { return }
        geometry=NotchGeometry(screenFrame:screen.frame,visibleFrame:screen.visibleFrame,topInset:screen.safeAreaInsets.top,
                               leftAreaMaxX:screen.auxiliaryTopLeftArea?.maxX,rightAreaMinX:screen.auxiliaryTopRightArea?.minX)
        resize()
    }
    func hover(_ inside:Bool) {
        hoverTask?.cancel()
        hoverTask=Task { [weak self] in
            do { try await Task.sleep(for:.milliseconds(inside ? 130:450)) } catch { return }
            guard let self else { return }
            if !inside, self.panel?.frame.contains(NSEvent.mouseLocation) == true { return }
            self.expanded=inside; self.resize()
        }
    }
    func openWorkspace() { hoverTask?.cancel(); expanded=false; resize(); store.onOpenWorkspace?() }
    private func resize() {
        guard let panel else { return }
        let frame=expanded ? geometry.expandedFrame:geometry.collapsedFrame
        if store.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { panel.setFrame(frame,display:true) }
        else { NSAnimationContext.runAnimationGroup { context in context.duration=0.22; context.timingFunction=CAMediaTimingFunction(name:.easeInEaseOut); panel.animator().setFrame(frame,display:true) } }
    }
    func teardown() {
        hide(); panel?.close(); panel=nil
        for observer in observers { NotificationCenter.default.removeObserver(observer); NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observers=[]
    }
}
struct NotchView:View {
    @Environment(WorkspaceStore.self) private var store
    let controller:NotchController
    var body:some View {
        VStack(spacing:0) {
            HStack(spacing:0) {
                HStack(spacing:7) { PixelAvatar(size:20); Text(String(store.activeCount)).font(.system(size:11,weight:.medium,design:.monospaced)) }.frame(width:88)
                if controller.geometry.hasNotch { Color.clear.frame(width:controller.geometry.cameraWidth,height:controller.geometry.topInset) }
                else { BrandMark().frame(width:20,height:20).frame(maxWidth:.infinity) }
                HStack(spacing:6) { Image(systemName:store.permissions.isEmpty ? "leaf.fill":"exclamationmark.bubble.fill").font(.system(size:11)); Circle().fill(store.isDemo ? Theme.amber:(store.isConnected ? Theme.green:Theme.muted)).frame(width:5,height:5) }.foregroundStyle(store.permissions.isEmpty ? Theme.muted:Theme.amber).frame(width:88)
            }.frame(height:max(38,controller.geometry.topInset+7)).contentShape(Rectangle()).onTapGesture { controller.openWorkspace() }
            if controller.expanded {
                VStack(spacing:13) {
                    HStack { Text("NotchCraft").font(.system(size:12,weight:.semibold,design:.rounded)); Spacer(); Tag(text:L(store.isDemo ? "mode.demo":"mode.live"),color:store.isDemo ? Theme.amber:Theme.green) }
                    ZStack(alignment:.bottom) {
                        Image(nsImage:WorldArtwork.image).resizable().interpolation(.none).scaledToFit().frame(height:110).clipped().accessibilityHidden(true)
                        HStack(spacing:20) {
                            ForEach(Array(store.visibleSessions.prefix(5).enumerated()),id:\.element.id) { index,session in
                                Button { store.selectedSessionID=session.id; controller.openWorkspace() } label: { VStack(spacing:4) { PixelAvatar(index:index,size:27); Text(String(session.name.prefix(8))).font(.system(size:8)).foregroundStyle(Theme.muted) } }.buttonStyle(.plain)
                            }
                        }.padding(.bottom,8)
                    }.frame(height:108)
                    HStack {
                        HStack(spacing:5) { Circle().fill(store.permissions.isEmpty ? Theme.green:Theme.amber).frame(width:4,height:4); Text(store.permissions.isEmpty ? (store.visibleSessions.isEmpty ? L("notch.empty") : "\(store.activeCount) " + L("status.working")):"\(store.permissions.count) " + L("approval.title")) }.font(.system(size:10)).foregroundStyle(Theme.muted)
                        Spacer()
                        Button { controller.openWorkspace() } label: { Label(L("notch.open"),systemImage:"arrow.up.right").font(.system(size:10,weight:.medium)) }.buttonStyle(.plain).foregroundStyle(Theme.text)
                    }
                }.padding(.horizontal,20).padding(.bottom,18)
            }
        }.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.top)
            .background(.black).clipShape(UnevenRoundedRectangle(bottomLeadingRadius:22,bottomTrailingRadius:22))
            .overlay(alignment:.bottom) { if controller.expanded { UnevenRoundedRectangle(bottomLeadingRadius:22,bottomTrailingRadius:22).strokeBorder(.white.opacity(0.08),lineWidth:1).allowsHitTesting(false) } }
            .foregroundStyle(Theme.text).preferredColorScheme(.dark).onHover { controller.hover($0) }
            .accessibilityElement(children:.contain).accessibilityLabel(L("notch.open"))
    }
}
