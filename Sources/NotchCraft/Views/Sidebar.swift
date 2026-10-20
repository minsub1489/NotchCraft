import SwiftUI
import NotchCraftCore

struct WorkspaceSidebar: View {
    @Environment(WorkspaceStore.self) private var store
    var body: some View {
        VStack(spacing:0) {
            if let session=store.selectedSession { SessionDetail(session:session) }
            else {
                connection
                Divider().overlay(Theme.line)
                if !store.permissions.isEmpty && !store.isDemo {
                    ScrollView { VStack(spacing:12) { ForEach(store.permissions) { ApprovalCard(request:$0) } }.padding(18) }.frame(maxHeight:270)
                    Divider().overlay(Theme.line)
                }
                VStack(alignment:.leading,spacing:16) {
                    SectionLabel(title:L("sessions.title"),count:store.visibleSessions.count)
                    if store.visibleSessions.isEmpty {
                        Text(L("sessions.empty")).font(.system(size:11)).foregroundStyle(Theme.muted).padding(.vertical,18)
                    } else {
                        ScrollView {
                            LazyVStack(spacing:2) {
                                ForEach(Array(store.filteredSessions.prefix(8).enumerated()),id:\.element.id) { index,session in
                                    Button { store.selectedSessionID=session.id } label: { SessionRow(session:session,index:index) }.buttonStyle(.plain)
                                }
                            }
                        }.frame(maxHeight:.infinity)
                    }
                }.padding(18).frame(maxHeight:.infinity,alignment:.top)
                Divider().overlay(Theme.line)
                VStack(alignment:.leading,spacing:17) {
                    HStack { SectionLabel(title:L("activity.recent")); Button { store.tab = .activity } label: { Image(systemName:"arrow.up.right").font(.system(size:10)) }.buttonStyle(.plain).foregroundStyle(Theme.muted) }
                    if store.visibleEvents.isEmpty { Text(L("activity.empty")).font(.system(size:11)).foregroundStyle(Theme.muted).padding(.vertical,10) }
                    ForEach(Array(store.visibleEvents.prefix(4))) { event in ActivityRow(event:event) }
                }.padding(18).frame(minHeight:190,alignment:.top)
                Spacer(minLength:0)
                Button { store.setDemo(!store.isDemo) } label: { Label(L(store.isDemo ? "demo.disable":"demo.enable"),systemImage:store.isDemo ? "antenna.radiowaves.left.and.right":"sparkles").frame(maxWidth:.infinity) }
                    .buttonStyle(QuietButton()).padding(18)
            }
        }.background(Theme.surface)
    }
    private var connection: some View {
        VStack(alignment:.leading,spacing:15) {
            SectionLabel(title:L("connection.title"),count:store.isConnected ? 1:0)
            HStack(spacing:10) {
                PixelAvatar(index:0,size:36)
                VStack(alignment:.leading,spacing:4) {
                    Text("Codex").font(.system(size:13,weight:.medium))
                    HStack(spacing:5) { Circle().fill(store.isConnected ? Theme.green:Theme.muted).frame(width:4,height:4); Text(L(store.isConnected ? "connection.connected":"connection.offline")).font(.system(size:10)).foregroundStyle(Theme.muted) }
                }
                Spacer()
                Button {
                    if store.isConnected { store.showSettings=true } else { Task { await store.connect() } }
                } label: {
                    if store.isConnecting { ProgressView().controlSize(.small).frame(width:18,height:18) }
                    else { Image(systemName:store.isConnected ? "ellipsis":"link").font(.system(size:13)) }
                }.buttonStyle(IconButton()).disabled(store.isConnecting).help(L("connection.connect"))
            }
        }.padding(18)
    }
}
struct SessionRow: View {
    @Environment(WorkspaceStore.self) private var store
    let session:ProviderSession
    let index:Int
    private var snapshot:SessionSnapshot? { store.activeLedger.sessions[session.id] }
    var body: some View {
        HStack(alignment:.top,spacing:10) {
            PixelAvatar(index:index,size:33)
            VStack(alignment:.leading,spacing:5) {
                HStack { Text(session.name).font(.system(size:11,weight:.medium)).lineLimit(1); Spacer(minLength:2); Circle().fill(Theme.status(snapshot?.status ?? .unknown)).frame(width:5,height:5) }
                Text(L(snapshot.map { "activity."+$0.activity.rawValue } ?? "status.unknown")).font(.system(size:10)).foregroundStyle(Theme.muted).lineLimit(1)
                HStack { Text(L("status."+(snapshot?.status.rawValue ?? "unknown"))); Spacer(); if let tools=snapshot?.toolCount,tools>0 { Image(systemName:"hammer"); Text(String(tools)).monospacedDigit() } }
                    .font(.system(size:9)).foregroundStyle(Theme.status(snapshot?.status ?? .unknown))
            }
        }.padding(.vertical,11).contentShape(Rectangle())
    }
}
struct ActivityRow: View {
    let event:AgentEvent
    var body: some View {
        HStack(alignment:.top,spacing:10) {
            Text(event.timestamp,format:.dateTime.hour().minute()).font(.system(size:9,design:.monospaced)).foregroundStyle(Theme.muted).frame(width:34,alignment:.leading)
            RoundedRectangle(cornerRadius:1).fill(event.source == .demo ? Theme.amber:Theme.green).frame(width:4,height:4).padding(.top,4)
            VStack(alignment:.leading,spacing:4) {
                Text(event.source == .demo ? "DEMO":event.providerID.uppercased()).font(.system(size:9,weight:.semibold,design:.monospaced)).foregroundStyle(Theme.text.opacity(0.85))
                Text(L("event."+event.eventType.rawValue)).font(.system(size:10)).foregroundStyle(Theme.muted).lineLimit(2)
            }
            Spacer(minLength:0)
        }
    }
}
struct ApprovalCard: View {
    @Environment(WorkspaceStore.self) private var store
    let request:PermissionRequest
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            Label(L("approval.title"),systemImage:"hand.raised").font(.system(size:11,weight:.medium)).foregroundStyle(Theme.amber)
            Text(L(request.title)).font(.system(size:12,weight:.medium))
            Text("\(request.sessionID.prefix(8)) / \(request.taskID.prefix(8))").font(.system(size:9,design:.monospaced)).foregroundStyle(Theme.muted)
            if !request.detail.isEmpty { ScrollView { Text(request.detail).font(.system(size:10,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) }.frame(maxHeight:85) }
            Text(L("approval.note")).font(.system(size:9)).foregroundStyle(Theme.muted)
            HStack {
                Button(L("approval.deny")) { store.respond(request,allow:false) }.buttonStyle(QuietButton())
                Spacer()
                Button(L("approval.allow")) { store.respond(request,allow:true) }.buttonStyle(QuietButton(prominent:true))
            }
        }.padding(12).background(Theme.amber.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius:9)).overlay(RoundedRectangle(cornerRadius:9).strokeBorder(Theme.amber.opacity(0.2)))
    }
}
struct SessionDetail: View {
    @Environment(WorkspaceStore.self) private var store
    let session:ProviderSession
    @State private var confirmCancel=false
    var snapshot:SessionSnapshot? { store.activeLedger.sessions[session.id] }
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:22) {
                HStack { Text(L("sessions.detail")).font(.system(size:12,weight:.semibold)); Spacer(); Button { store.selectedSessionID=nil } label: { Image(systemName:"xmark") }.buttonStyle(IconButton()).help(L("common.close")) }
                HStack(spacing:12) { PixelAvatar(index:store.visibleSessions.firstIndex(where:{$0.id == session.id}) ?? 0,size:48); VStack(alignment:.leading,spacing:6) { Text(session.name).font(.system(size:15,weight:.semibold)).lineLimit(2); Tag(text:L("status."+(snapshot?.status.rawValue ?? "unknown")),color:Theme.status(snapshot?.status ?? .unknown)) } }
                VStack(alignment:.leading,spacing:17) {
                    DetailField(title:L("session.model"),value:session.model ?? L("usage.unavailable"))
                    DetailField(title:L("session.project"),value:session.cwd.isEmpty ? L("usage.unavailable"):URL(fileURLWithPath:session.cwd).lastPathComponent)
                    DetailField(title:L("session.source"),value:L(session.owned ? "connection.owned":"connection.history"))
                    DetailField(title:L("session.lastSeen"),value:(snapshot?.lastUpdated ?? session.updatedAt).formatted(date:.abbreviated,time:.standard))
                    DetailField(title:L("session.id"),value:session.id,mono:true)
                    DetailField(title:L("session.tools"),value:snapshot.map { String($0.toolCount) } ?? L("usage.unavailable"))
                }
                Divider().overlay(Theme.line)
                Text(L("usage.title")).font(.system(size:12,weight:.medium))
                HStack { UsageSmall(title:L("usage.input"),value:snapshot?.usage?.inputTokens); Spacer(); UsageSmall(title:L("usage.output"),value:snapshot?.usage?.outputTokens) }
                Text(snapshot?.usage?.source ?? L("usage.noData")).font(.system(size:9)).foregroundStyle(Theme.muted)
                if let output = store.sessionOutputs[session.id] {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L("session.result")).font(.system(size:12, weight:.medium))
                        Text(L("session.resultNote")).font(.system(size:9)).foregroundStyle(Theme.muted)
                        Text(output).font(.system(size:11)).lineSpacing(4).textSelection(.enabled)
                    }
                }
                ForEach(store.permissions.filter { $0.sessionID == session.id }) { ApprovalCard(request:$0) }
                Text(L(session.owned ? "session.noProgress":"session.noControl")).font(.system(size:10)).foregroundStyle(Theme.muted).lineSpacing(4)
                Button { confirmCancel=true } label: { Label(L("session.cancel"),systemImage:"stop.fill").frame(maxWidth:.infinity) }.buttonStyle(QuietButton())
                    .disabled(!session.owned || ![.working,.waitingApproval].contains(snapshot?.status ?? .unknown) || store.isDemo)
                if !session.cwd.isEmpty { Button { NSWorkspace.shared.open(URL(fileURLWithPath:session.cwd)) } label: { Label(L("session.openProject"),systemImage:"folder").frame(maxWidth:.infinity) }.buttonStyle(QuietButton()) }
            }.padding(18)
        }.confirmationDialog(L("confirm.cancel"),isPresented:$confirmCancel) {
            Button(L("session.cancel"),role:.destructive) { Task { await store.cancel(session) } }
        }
    }
}
struct DetailField: View {
    let title:String; let value:String; var mono=false
    var body: some View { VStack(alignment:.leading,spacing:6) { Text(title).font(.system(size:10)).foregroundStyle(Theme.muted); Text(value).font(.system(size:11,design:mono ? .monospaced:.default)).textSelection(.enabled).lineLimit(3) } }
}
struct UsageSmall: View {
    let title:String; let value:Int?
    var body: some View { VStack(alignment:.leading,spacing:8) { Text(title).font(.system(size:10)).foregroundStyle(Theme.muted); Text(value.map { $0.formatted() } ?? "—").font(.system(size:20,weight:.medium,design:.monospaced)) } }
}
