import SwiftUI
import NotchCraftCore

struct AgentsView: View {
    @Environment(WorkspaceStore.self) private var store
    @State private var confirmDisconnect=false
    var body: some View {
        @Bindable var store=store
        ScrollView {
            VStack(alignment:.leading,spacing:26) {
                PanelHeading(title:L("agents.title"),subtitle:L("agents.subtitle"))
                LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:14) {
                    ForEach(Array(store.detections.enumerated()),id:\.element.id) { index,detection in
                        VStack(alignment:.leading,spacing:18) {
                            HStack { PixelAvatar(index:index,size:40); Spacer(); Tag(text:L(detection.isInstalled ? "agents.installed":"agents.missing"),color:detection.isInstalled ? Theme.green:Theme.muted) }
                            Text(detection.name).font(.system(size:18,weight:.medium))
                            Text(L(detection.integration)).font(.system(size:11)).foregroundStyle(Theme.muted).frame(minHeight:30,alignment:.top)
                            if detection.id == "codex" {
                                Button(L(store.isConnected ? "connection.disconnect":(store.isConnecting ? "connection.connecting":"connection.connect"))) {
                                    if store.isConnected { confirmDisconnect=true } else { Task { await store.connect() } }
                                }.buttonStyle(QuietButton(prominent:!store.isConnected)).disabled(!detection.isInstalled || store.isConnecting)
                            } else {
                                Text(L("connection.offline")).font(.system(size:10)).foregroundStyle(Theme.muted).padding(.vertical,10)
                            }
                        }.padding(20).frame(maxWidth:.infinity,alignment:.leading).background(Theme.surface).clipShape(RoundedRectangle(cornerRadius:12)).overlay(RoundedRectangle(cornerRadius:12).strokeBorder(Theme.line))
                    }
                }
                HStack { SectionLabel(title:L("sessions.title"),count:store.visibleSessions.count); Button { store.detections=ExecutableLocator.detections() } label: { Label(L("agents.detect"),systemImage:"arrow.clockwise") }.buttonStyle(QuietButton()) }
                TextField(L("sessions.search"),text:$store.search).textFieldStyle(.plain).font(.system(size:12)).padding(12).background(Theme.raised).clipShape(RoundedRectangle(cornerRadius:7))
                Text(L("connection.historyNote")).font(.system(size:11)).foregroundStyle(Theme.muted)
                LazyVStack(spacing:0) {
                    ForEach(Array(store.filteredSessions.enumerated()),id:\.element.id) { index,session in
                        Button { store.selectedSessionID=session.id } label: {
                            HStack { SessionRow(session:session,index:index).frame(width:280); Spacer(); Text(session.cwd.isEmpty ? "—":URL(fileURLWithPath:session.cwd).lastPathComponent).font(.system(size:11)).foregroundStyle(Theme.muted); Spacer(); Text(session.updatedAt,format:.dateTime.month().day().hour().minute()).font(.system(size:10,design:.monospaced)).foregroundStyle(Theme.muted); Image(systemName:"chevron.right").font(.system(size:9)).foregroundStyle(Theme.muted) }.padding(.horizontal,14).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Divider().overlay(Theme.line)
                    }
                }
            }.padding(30)
        }.confirmationDialog(L("confirm.disconnect"),isPresented:$confirmDisconnect) { Button(L("connection.disconnect"),role:.destructive) { store.disconnect() } }
    }
}
struct PanelHeading: View {
    let title:String; let subtitle:String
    var body: some View { VStack(alignment:.leading,spacing:12) { Text(title).font(.system(size:27,weight:.medium)).tracking(-0.7); Text(subtitle).font(.system(size:12)).foregroundStyle(Theme.muted) } }
}
struct ActivityView: View {
    @Environment(WorkspaceStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:28) {
                PanelHeading(title:L("activity.title"),subtitle:L("footer.event"))
                if store.visibleEvents.isEmpty {
                    VStack(spacing:18) { Image(systemName:"leaf").font(.system(size:35,weight:.ultraLight)); Text(L("activity.empty")).font(.system(size:13)) }.foregroundStyle(Theme.muted).frame(maxWidth:.infinity,minHeight:300)
                }
                LazyVStack(spacing:0) {
                    ForEach(store.visibleEvents) { event in
                        HStack(alignment:.top,spacing:20) {
                            ActivityRow(event:event).frame(width:280,alignment:.leading)
                            Spacer()
                            Text(String(event.sessionID.prefix(12))).font(.system(size:10,design:.monospaced)).foregroundStyle(Theme.muted)
                            VStack(alignment:.trailing,spacing:5) {
                                Text(event.source == .demo ? "DEMO":"Codex App Server").font(.system(size:10)).foregroundStyle(event.source == .demo ? Theme.amber:Theme.green)
                                if !store.events.contains(where:{$0.id == event.id}) && !store.isDemo { Text(L("activity.persisted")).font(.system(size:9)).foregroundStyle(Theme.muted) }
                            }.frame(width:145,alignment:.trailing)
                        }.padding(.vertical,18)
                        Divider().overlay(Theme.line)
                    }
                }
            }.padding(30)
        }
    }
}
struct UsageView: View {
    @Environment(WorkspaceStore.self) private var store
    private var usage:[UsageMetrics] { store.activeLedger.sessions.values.compactMap(\.usage) }
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:28) {
                PanelHeading(title:L("usage.title"),subtitle:L("usage.subtitle"))
                AccountQuotaView()
                Divider().overlay(Theme.line)
                SectionLabel(title:L("usage.observedTokens"))
                HStack(spacing:14) {
                    MetricCard(title:L("usage.input"),value:UsageAggregate(usage).inputTokens,symbol:"arrow.down.left")
                    MetricCard(title:L("usage.output"),value:UsageAggregate(usage).outputTokens,symbol:"arrow.up.right")
                    VStack(alignment:.leading,spacing:18) { Label(L("usage.billing"),systemImage:"creditcard").font(.system(size:11)).foregroundStyle(Theme.muted); Text("—").font(.system(size:27,weight:.medium,design:.monospaced)); Text(L("usage.unavailable")).font(.system(size:10)).foregroundStyle(Theme.muted) }.padding(22).frame(maxWidth:.infinity,alignment:.leading).background(Theme.surface).clipShape(RoundedRectangle(cornerRadius:10)).overlay(RoundedRectangle(cornerRadius:10).strokeBorder(Theme.line))
                }
                Text(L("usage.noData")).font(.system(size:11)).foregroundStyle(Theme.muted)
                ForEach(store.visibleSessions.filter { store.activeLedger.sessions[$0.id]?.usage != nil }) { session in
                    if let metrics=store.activeLedger.sessions[session.id]?.usage {
                        VStack(alignment:.leading,spacing:15) {
                            HStack { Text(session.name).font(.system(size:13,weight:.medium)); Spacer(); Tag(text:L(metrics.measurement == .actual ? "usage.actual":"usage.estimated")) }
                            HStack { UsageSmall(title:L("usage.input"),value:metrics.inputTokens); Spacer(); UsageSmall(title:L("usage.output"),value:metrics.outputTokens); Spacer(); UsageSmall(title:L("usage.total"),value:metrics.totalTokens) }
                            Text(metrics.source).font(.system(size:10)).foregroundStyle(Theme.muted)
                            HStack { Text(L("usage.session")); Spacer(); Text(metrics.measuredAt,format:.dateTime.hour().minute().second()) }.font(.system(size:10)).foregroundStyle(Theme.muted)
                        }.padding(20).background(Theme.surface).clipShape(RoundedRectangle(cornerRadius:10))
                    }
                }

            }.padding(30)
        }
    }

}
struct MetricCard: View {
    let title:String; let value:Int?; let symbol:String
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            Label(title,systemImage:symbol).font(.system(size:11)).foregroundStyle(Theme.muted)
            Text(value.map {$0.formatted()} ?? "—").font(.system(size:27,weight:.medium,design:.monospaced))
            Text(L(value == nil ? "usage.unavailable":"usage.actual")).font(.system(size:10)).foregroundStyle(value == nil ? Theme.muted:Theme.green)
        }.padding(22).frame(maxWidth:.infinity,alignment:.leading).background(Theme.surface).clipShape(RoundedRectangle(cornerRadius:10)).overlay(RoundedRectangle(cornerRadius:10).strokeBorder(Theme.line))
    }
}
