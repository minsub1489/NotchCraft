import SwiftUI
import NotchCraftCore

func quotaPeriodTitle(_ period:QuotaPeriod,language:String) -> String {
    let key:String, count:Int
    switch period {
    case .weeks(let n): key="usage.period.weeks"; count=n
    case .days(let n): key="usage.period.days"; count=n
    case .hours(let n): key="usage.period.hours"; count=n
    case .minutes(let n): key="usage.period.minutes"; count=n
    case .unknown:return localized("usage.period.unknown",language:language)
    }
    return String(format:localized(key,language:language),count)
}
struct AccountQuotaView: View {
    @Environment(WorkspaceStore.self) private var store
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {
                SectionLabel(title:L("usage.quota"))
                if store.isRefreshingQuota { ProgressView().controlSize(.mini) }
                Button { Task { await store.refreshQuota() } } label:{ Image(systemName:"arrow.clockwise") }
                    .buttonStyle(IconButton()).disabled(!store.isConnected || store.isDemo || store.isRefreshingQuota)
                    .help(L("connection.refresh"))
            }
            Text(L("usage.quotaNote")).font(.system(size:11)).foregroundStyle(Theme.muted)
            if !store.isDemo, let snapshot=store.quotaSnapshot, !snapshot.buckets.isEmpty {
                TimelineView(.periodic(from:.now,by:15)) { context in
                    VStack(alignment:.leading,spacing:16) {
                        ForEach(snapshot.buckets) { bucket in
                            VStack(alignment:.leading,spacing:14) {
                                HStack {
                                    Text(bucket.name).font(.system(size:12,weight:.semibold))
                                    if let plan=bucket.plan { Text(plan.capitalized).font(.system(size:10)).foregroundStyle(Theme.muted) }
                                    Spacer()
                                }
                                ForEach(bucket.windows) { window in
                                    QuotaWindowCard(window:window,stale:store.quotaRefreshFailed || !store.isConnected || snapshot.isStale(at:context.date))
                                }
                            }
                        }
                        HStack(spacing:6) {
                            Image(systemName:"checkmark.shield")
                            Text("Codex")
                            Spacer()
                            Text(snapshot.receivedAt,format:.dateTime.hour().minute().second())
                        }.font(.system(size:10)).foregroundStyle(Theme.muted)
                        if store.quotaRefreshFailed || !store.isConnected || snapshot.isStale(at:context.date) {
                            Label(L("usage.stale"),systemImage:"clock.badge.exclamationmark").font(.system(size:10)).foregroundStyle(Theme.amber)
                        }
                    }
                }
            } else { Text(L("usage.unavailable")).font(.system(size:13)).foregroundStyle(Theme.muted).padding(.vertical,15) }
        }
        .task { if !store.isDemo { await store.refreshQuota() } }
        .onChange(of:store.isConnected) { _,connected in if connected { Task { await store.refreshQuota() } } }
    }
}
private struct QuotaWindowCard: View {
    @Environment(WorkspaceStore.self) private var store
    let window:QuotaWindow
    let stale:Bool
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack(alignment:.firstTextBaseline) {
                Text(quotaPeriodTitle(window.period,language:store.language)).font(.system(size:13,weight:.medium))
                Spacer()
                Text(window.remainingPercent,format:.number.precision(.fractionLength(0...1)))
                    .font(.system(size:23,weight:.medium,design:.monospaced))
                    + Text("% " + L("usage.remaining")).font(.system(size:11))
            }
            // Matches Codex's remaining allowance; the consumed percentage is separately named below.
            ProgressView(value:window.remainingPercent,total:100).tint(stale ? Theme.muted:Theme.green)
            HStack {
                Text(L("usage.used") + " ") + Text(window.usedPercent,format:.number.precision(.fractionLength(0...1))) + Text("%")
                Spacer()
                if let reset=window.resetsAt {
                    Text(L("usage.reset") + " · ") + Text(reset,format:.dateTime.month().day().hour().minute())
                }
            }.font(.system(size:10)).foregroundStyle(Theme.muted)
        }.padding(18).background(Theme.surface).clipShape(RoundedRectangle(cornerRadius:10))
            .overlay(RoundedRectangle(cornerRadius:10).strokeBorder(Theme.line))
    }
}
