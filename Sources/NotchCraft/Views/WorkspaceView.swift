import SwiftUI
import SpriteKit
import NotchCraftCore

struct WorkspaceView: View {
    @Environment(WorkspaceStore.self) private var store
    var body: some View {
        @Bindable var store = store
        VStack(spacing:0) {
            header
            Rectangle().fill(Theme.line).frame(height:1)
            if store.isDemo {
                HStack(spacing:8) { Image(systemName:"sparkles"); Text(L("mode.demoNotice")); Spacer(); Button(L("demo.disable")) { store.setDemo(false) }.buttonStyle(.plain) }
                    .font(.system(size:11)).foregroundStyle(Theme.amber).padding(.horizontal,24).padding(.vertical,8).background(Theme.amber.opacity(0.055))
            }
            HStack(spacing:0) {
                Group {
                    switch store.tab {
                    case .world: WorldView()
                    case .agents: AgentsView()
                    case .activity: ActivityView()
                    case .usage: UsageView()
                    }
                }.frame(maxWidth:.infinity,maxHeight:.infinity)
                Rectangle().fill(Theme.line).frame(width:1)
                WorkspaceSidebar().frame(width:300)
            }
            Rectangle().fill(Theme.line).frame(height:1)
            footer
        }
        .background(Theme.background).foregroundStyle(Theme.text).preferredColorScheme(.dark)
        .frame(minWidth:1100,minHeight:730)
        .id(store.language)
        .environment(\.locale, Locale(identifier: store.language))
        .sheet(isPresented:$store.showNewTask) { NewTaskView().environment(store) }
        .sheet(isPresented:$store.showSettings) { SettingsPanel().environment(store) }
        .sheet(isPresented:$store.showWelcome) { WelcomeView().environment(store).interactiveDismissDisabled() }
        .alert("NotchCraft",isPresented:Binding(get:{store.notice != nil},set:{if !$0 { store.notice=nil }})) {
            Button(L("common.done")) { store.notice=nil }
        } message: { Text(store.notice ?? "") }
    }
    private var header: some View {
        HStack(spacing:24) {
            WindowControls()
            HStack(spacing:10) {
                BrandMark().frame(width:31,height:31)
                VStack(alignment:.leading,spacing:2) {
                    Text("NotchCraft").font(.system(size:20,weight:.semibold,design:.rounded)).tracking(-0.6)
                    Text("AI AGENT WORKSPACE").font(.system(size:8,weight:.medium,design:.monospaced)).tracking(1.6).foregroundStyle(Theme.muted)
                }
            }.padding(.trailing,30)
            HStack(spacing:5) {
                ForEach(WorkspaceTab.allCases) { tab in
                    Button { store.tab=tab } label: {
                        HStack(spacing:7) { Image(systemName:tab.symbol).font(.system(size:12)); Text(L("nav."+tab.rawValue)).font(.system(size:12,weight:store.tab == tab ? .semibold:.regular)) }
                            .foregroundStyle(store.tab == tab ? Theme.text:Theme.muted).padding(.horizontal,14).padding(.vertical,9)
                            .background(store.tab == tab ? Color.white.opacity(0.065):.clear).clipShape(RoundedRectangle(cornerRadius:7))
                    }.buttonStyle(.plain).accessibilityLabel(L("nav."+tab.rawValue))
                }
            }
            Spacer(minLength:10)
            Button { store.isPinned.toggle() } label: { Image(systemName:store.isPinned ? "pin.fill":"pin") }.buttonStyle(IconButton()).help(L("notch.pin"))
            Button { store.showSettings=true } label: { Image(systemName:"slider.horizontal.3") }.buttonStyle(IconButton()).help(L("common.settings"))
            Button { store.showNewTask=true } label: { Label(L("new.start"),systemImage:"plus") }.buttonStyle(QuietButton(prominent:true)).disabled(!store.isConnected || store.isDemo)
        }.padding(.horizontal,24).frame(height:76)
    }
    private var footer: some View {
        HStack(spacing:8) {
            Image(systemName:"lock.shield").font(.system(size:10)); Text(L("footer.local"))
            Spacer()
            Circle().fill(store.isConnected ? Theme.green:Theme.muted).frame(width:5,height:5)
            Text(store.isDemo ? L("mode.demo"):(store.isConnected ? "CODEX · APP SERVER":L("connection.offline")))
            Text("/").foregroundStyle(Theme.line)
            Text("v0.1.1").fontDesign(.monospaced)
            Button { store.onCollapse?() } label: { Image(systemName:"chevron.up") }.buttonStyle(.plain).help(L("notch.hide"))
        }.font(.system(size:10)).foregroundStyle(Theme.muted).padding(.horizontal,24).frame(height:30)
    }
}
struct BrandMark: View {
    var body: some View {
        Canvas { c,s in
            func poly(_ p:[CGPoint],_ color:Color) { var path=Path(); path.addLines(p); path.closeSubpath(); c.fill(path,with:.color(color)) }
            let x=s.width/2,y=s.height/2
            poly([CGPoint(x:x,y:1),CGPoint(x:s.width-2,y:y*0.65),CGPoint(x:x,y:y*1.2),CGPoint(x:2,y:y*0.65)],Theme.green)
            poly([CGPoint(x:2,y:y*0.65),CGPoint(x:x,y:y*1.2),CGPoint(x:x,y:s.height-1),CGPoint(x:2,y:y*1.4)],Color(hex:0x60734C))
            poly([CGPoint(x:x,y:y*1.2),CGPoint(x:s.width-2,y:y*0.65),CGPoint(x:s.width-2,y:y*1.4),CGPoint(x:x,y:s.height-1)],Color(hex:0x8C9E72))
        }
    }
}
struct WorldView: View {
    @Environment(WorkspaceStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var scene=OfficeScene(size:WorldArtwork.size)
    @State private var lastFrame: NSImage?
    private var states:[String:SessionSnapshot] { store.activeLedger.sessions }
    var body: some View {
        VStack(spacing:0) {
            HStack(alignment:.top) {
                VStack(alignment:.leading,spacing:10) {
                    Text(L("world.eyebrow")).font(.system(size:9,weight:.medium,design:.monospaced)).tracking(2).foregroundStyle(Theme.muted)
                    Text(L("world.title")).font(.system(size:28,weight:.medium)).tracking(-1)
                    Text(L("world.subtitle")).font(.system(size:12)).foregroundStyle(Theme.muted)
                }
                Spacer()
                VStack(alignment:.trailing,spacing:11) {
                    Tag(text:L(store.isDemo ? "mode.demo":"mode.live"),color:store.isDemo ? Theme.amber:Theme.green)
                    TimelineView(.periodic(from:.now,by:60)) { context in
                        HStack(spacing:6) { Image(systemName:"moon.stars"); Text(context.date,style:.time).monospacedDigit() }
                            .font(.system(size:10)).foregroundStyle(Theme.muted)
                    }
                }
            }.padding(.horizontal,30).padding(.top,26).padding(.bottom,5)
            GeometryReader { geometry in
            ZStack(alignment:.bottom) {
                if store.workspaceVisible && scenePhase != .background {
                    OfficeSurface(scene:scene,framesPerSecond:store.lowPower ? 15:30)
                        .accessibilityLabel(L("nav.world"))
                        .accessibilityHint(L("world.pan"))
                } else {
                    Image(nsImage:lastFrame ?? WorldArtwork.image).resizable().interpolation(.none).scaledToFit().scaleEffect(1.25)
                        .accessibilityLabel(L("nav.world"))
                }
                VStack {
                    Spacer()
                    HStack {
                        if store.visibleSessions.isEmpty {
                            VStack(alignment:.leading,spacing:6) {
                                Text(L("world.empty")).font(.system(size:14,weight:.medium))
                                Text(L(store.isConnected ? "world.waiting":"world.emptyDetail")).font(.system(size:11)).foregroundStyle(Theme.muted)
                                HStack(spacing:8) {
                                    Button(L(store.isConnected ? "new.start":"connection.connect")) {
                                        if store.isConnected { store.showNewTask = true } else { Task { await store.connect() } }
                                    }.buttonStyle(QuietButton(prominent:true)).disabled(store.isConnecting)
                                    Button(L("demo.enable")) { store.setDemo(true) }.buttonStyle(QuietButton())
                                }.padding(.top,8)
                            }.padding(18).background(.black.opacity(0.88)).clipShape(RoundedRectangle(cornerRadius:10)).overlay(RoundedRectangle(cornerRadius:10).strokeBorder(Theme.line))
                        } else {
                            HStack(spacing:8) { Circle().fill(Theme.green).frame(width:5,height:5); Text("\(store.activeCount) / \(store.visibleSessions.count)").fontDesign(.monospaced); Text(L("status.working")) }
                                .font(.system(size:10)).foregroundStyle(Theme.muted).padding(10).background(.black.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius:6))
                        }
                        Spacer()
                        HStack(spacing:1) {
                            Button { scene.zoom(by:1.18) } label: { Image(systemName:"minus") }.help(L("world.zoom"))
                            Button { scene.resetView() } label: { Image(systemName:"viewfinder") }.help(L("world.reset"))
                            Button { scene.zoom(by:0.85) } label: { Image(systemName:"plus") }.help(L("world.zoom"))
                        }.buttonStyle(IconButton()).padding(3).background(.black.opacity(0.85)).clipShape(RoundedRectangle(cornerRadius:8))
                    }.padding(.horizontal,28).padding(.bottom,14)
                }
            }.frame(width:geometry.size.width,height:geometry.size.height)
            }.frame(maxWidth:.infinity,maxHeight:.infinity).clipped()
            HStack { Text(L("world.all")).font(.system(size:11,weight:.medium)); Spacer(); Text(L("world.pan")).font(.system(size:10)).foregroundStyle(Theme.muted) }
                .padding(.horizontal,28).padding(.bottom,12)
            HStack(spacing:10) {
                ForEach(WorldDistrict.all) { district in
                    Button { scene.focus(district) } label: { DistrictCard(district:district) }.buttonStyle(.plain)
                }
            }.padding(.horizontal,26).padding(.bottom,22)
        }
        .onAppear { scene.isPaused=false; scene.onSelect={store.selectedSessionID=$0}; sync() }
        .onDisappear { scene.isPaused=true }
        .onChange(of:states) { _,_ in sync() }
        .onChange(of:store.visibleSessions) { _,_ in
            sync()
            if !store.workspaceVisible { lastFrame = WorldArtwork.snapshot(sessions:store.visibleSessions,states:states) }
        }
        .onChange(of:store.selectedSessionID) { _,_ in sync() }
        .onChange(of:store.reduceMotion) { _,_ in sync() }
        .onChange(of:systemReduceMotion) { _,_ in sync() }
        .onChange(of:store.workspaceVisible) { _,visible in
            scene.isPaused = !visible
            if !visible { lastFrame = WorldArtwork.snapshot(sessions:store.visibleSessions,states:states) }
        }
    }
    private func sync() {
        scene.sync(sessions:store.visibleSessions,snapshots:states,selected:store.selectedSessionID,reduceMotion:store.reduceMotion || systemReduceMotion)
        if !store.workspaceVisible && lastFrame == nil { lastFrame = WorldArtwork.snapshot(sessions:store.visibleSessions,states:states) }
    }
}
struct DistrictCard: View {
    let district: WorldDistrict
    var body: some View {
        VStack(alignment:.leading,spacing:7) {
            Image(nsImage:WorldArtwork.thumbnail(district)).resizable().interpolation(.none).scaledToFill().frame(height:70).clipped()
                .background(Theme.surface).clipShape(RoundedRectangle(cornerRadius:6)).overlay(RoundedRectangle(cornerRadius:6).strokeBorder(Theme.line))
            Text(L("region."+district.id)).font(.system(size:11,weight:.medium)).lineLimit(1)
            Text(L("region."+district.id+".detail")).font(.system(size:9)).foregroundStyle(Theme.muted).lineLimit(1)
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
}
