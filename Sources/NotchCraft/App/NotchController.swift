import AppKit
import SwiftUI
import Observation
import NotchCraftCore

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect:NSRect,to screen:NSScreen?) -> NSRect { frameRect }
}
@MainActor @Observable final class NotchController {
    var expanded=false
    var contentVisible=false
    var geometry=NotchGeometry(screenFrame:.zero,visibleFrame:.zero,topInset:0)
    private(set) var panel:NotchPanel?
    private var hoverTask:Task<Void,Never>?
    private var revealTask:Task<Void,Never>?
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
            window.level=NSWindow.Level(rawValue:max(NSWindow.Level.mainMenu.rawValue,NSWindow.Level.statusBar.rawValue)+2)
            window.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.stationary,.ignoresCycle]
            window.hidesOnDeactivate=false; window.isFloatingPanel=true; window.isReleasedWhenClosed=false
            window.acceptsMouseMovedEvents=true; window.animationBehavior = .none
            let hosting=NSHostingView(rootView:NotchView(controller:self).environment(store))
            hosting.sizingOptions=[]
            window.contentView=hosting; panel=window
        }
        reposition(); panel?.orderFrontRegardless()
    }
    func hide() { hoverTask?.cancel(); revealTask?.cancel(); contentVisible=false; expanded=false; panel?.orderOut(nil) }
    func reposition() {
        guard let screen=NSScreen.screens.first(where:{$0.safeAreaInsets.top > 0}) ?? NSScreen.screens.first else { return }
        geometry=NotchGeometry(screenFrame:screen.frame,visibleFrame:screen.visibleFrame,topInset:screen.safeAreaInsets.top,
                               leftAreaMaxX:screen.auxiliaryTopLeftArea?.maxX,rightAreaMinX:screen.auxiliaryTopRightArea?.minX)
        resize(animated:false)
    }
    func hover(_ inside:Bool) {
        hoverTask?.cancel()
        hoverTask=Task { [weak self] in
            do { try await Task.sleep(for:.milliseconds(inside ? 120:420)) } catch { return }
            guard let self else { return }
            if !inside, self.panel?.frame.contains(NSEvent.mouseLocation) == true { return }
            self.setExpanded(inside)
        }
    }
    func setExpanded(_ value:Bool) {
        guard expanded != value else { return }
        revealTask?.cancel(); contentVisible=false; expanded=value
        resize(animated:true)
        guard value else { return }
        if store.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { contentVisible=true; return }
        revealTask=Task { [weak self] in
            do { try await Task.sleep(for:.milliseconds(210)) } catch { return }
            guard let self,self.expanded else { return }
            withAnimation(.easeOut(duration:self.store.reduceMotion ? 0:0.14)) { self.contentVisible=true }
        }
    }
    func openWorkspace() { hoverTask?.cancel(); setExpanded(false); store.onOpenWorkspace?() }
    private func resize(animated:Bool) {
        guard let panel else { return }
        let frame=expanded ? geometry.expandedFrame:geometry.collapsedFrame
        if !animated || store.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { panel.setFrame(frame,display:true) }
        else { NSAnimationContext.runAnimationGroup { context in context.duration=0.20; context.timingFunction=CAMediaTimingFunction(name:.easeInEaseOut); panel.animator().setFrame(frame,display:true) } }
    }
    func teardown() {
        hide(); panel?.close(); panel=nil
        for observer in observers { NotificationCenter.default.removeObserver(observer); NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observers=[]
    }
}
/// Concave shoulders join the physical black housing; all actual controls remain below the menu bar.
struct NotchSilhouette:Shape {
    func path(in rect:CGRect) -> Path {
        let shoulder:CGFloat=10, radius:CGFloat=18
        var p=Path()
        p.move(to:CGPoint(x:0,y:0)); p.addLine(to:CGPoint(x:rect.width,y:0))
        p.addQuadCurve(to:CGPoint(x:rect.width-shoulder,y:shoulder),control:CGPoint(x:rect.width-shoulder,y:0))
        p.addLine(to:CGPoint(x:rect.width-shoulder,y:rect.height-radius))
        p.addQuadCurve(to:CGPoint(x:rect.width-shoulder-radius,y:rect.height),control:CGPoint(x:rect.width-shoulder,y:rect.height))
        p.addLine(to:CGPoint(x:shoulder+radius,y:rect.height))
        p.addQuadCurve(to:CGPoint(x:shoulder,y:rect.height-radius),control:CGPoint(x:shoulder,y:rect.height))
        p.addLine(to:CGPoint(x:shoulder,y:shoulder))
        p.addQuadCurve(to:.zero,control:CGPoint(x:shoulder,y:0)); p.closeSubpath()
        return p
    }
}
struct NotchView:View {
    @Environment(WorkspaceStore.self) private var store
    let controller:NotchController
    var body:some View {
        VStack(spacing:0) {
            Button { controller.openWorkspace() } label:{
                HStack(spacing:8) {
                    PixelAvatar(size:18)
                    if controller.expanded { Text("NotchCraft").font(.system(size:12,weight:.semibold,design:.rounded)) }
                    else { Text("\(store.activeCount) / \(store.visibleSessions.count)").font(.system(size:11,weight:.medium,design:.monospaced)); Text(L("status.working")).font(.system(size:10)).foregroundStyle(Theme.muted) }
                    Spacer(minLength:8)
                    if !store.permissions.isEmpty { Image(systemName:"exclamationmark.bubble.fill").foregroundStyle(Theme.amber) }
                    Circle().fill(store.isDemo ? Theme.amber:(store.isConnected ? Theme.green:Theme.muted)).frame(width:5,height:5)
                    Image(systemName:"chevron.down").font(.system(size:8,weight:.semibold)).foregroundStyle(Theme.muted)
                }.padding(.horizontal,24).frame(height:36).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel(L("notch.open"))
            if controller.expanded {
                VStack(spacing:9) {
                    ZStack(alignment:.bottom) {
                        Image(nsImage:WorldArtwork.image).resizable().interpolation(.none).scaledToFit().frame(height:108).accessibilityHidden(true)
                        HStack(spacing:20) {
                            ForEach(Array(store.visibleSessions.prefix(5).enumerated()),id:\.element.id) { index,session in
                                Button { store.selectedSessionID=session.id; controller.openWorkspace() } label:{ VStack(spacing:4) { PixelAvatar(index:index,size:25); Text(String(session.name.prefix(8))).font(.system(size:8)).foregroundStyle(Theme.muted) } }.buttonStyle(.plain)
                            }
                        }.padding(.bottom,6)
                    }.frame(height:108)
                    HStack {
                        Tag(text:L(store.isDemo ? "mode.demo":"mode.live"),color:store.isDemo ? Theme.amber:Theme.green)
                        Spacer()
                        Button { controller.openWorkspace() } label:{ Label(L(store.permissions.isEmpty ? "notch.open":"notch.approval"),systemImage:"arrow.up.right").font(.system(size:10,weight:.medium)) }.buttonStyle(.plain)
                    }
                }.padding(.horizontal,26).padding(.top,3).padding(.bottom,16).opacity(controller.contentVisible ? 1:0)
            }
        }.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.top)
            .background(.black,in:NotchSilhouette())
            .foregroundStyle(Theme.text).preferredColorScheme(.dark)
            .onHover { controller.hover($0) }
            .accessibilityElement(children:.contain)
    }
}
