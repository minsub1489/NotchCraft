import Foundation

public enum QuotaPeriod: Equatable, Sendable {
    case weeks(Int), days(Int), hours(Int), minutes(Int), unknown
    public init(minutes: Int?) {
        guard let minutes, minutes > 0 else { self = .unknown; return }
        if minutes.isMultiple(of:10_080) { self = .weeks(minutes/10_080) }
        else if minutes.isMultiple(of:1_440) { self = .days(minutes/1_440) }
        else if minutes.isMultiple(of:60) { self = .hours(minutes/60) }
        else { self = .minutes(minutes) }
    }
}
public struct QuotaWindow: Identifiable, Equatable, Sendable {
    public var id: String
    public var usedPercent: Double
    public var remainingPercent: Double
    public var period: QuotaPeriod
    public var resetsAt: Date?
    init?(id:String, value:JSONValue) {
        func percentage(_ value:JSONValue) -> Double? {
            guard let number=value.double, number.isFinite, (0...100).contains(number) else { return nil }
            return number
        }
        let used=percentage(value["usedPercent"]), remaining=percentage(value["remainingPercent"])
        guard used != nil || remaining != nil else { return nil }
        self.id=id
        self.usedPercent=used ?? (100 - (remaining ?? 0))
        self.remainingPercent=remaining ?? (100 - (used ?? 0))
        period=QuotaPeriod(minutes:value["windowDurationMins"].int)
        if let reset=value["resetsAt"].double, reset.isFinite, reset > 0 { resetsAt=Date(timeIntervalSince1970:reset) }
    }
}
public struct QuotaBucket: Identifiable, Equatable, Sendable {
    public var id:String
    public var name:String
    public var plan:String?
    public var windows:[QuotaWindow]
    init?(id:String, value:JSONValue) {
        let windows=["primary","secondary"].compactMap { QuotaWindow(id:$0,value:value[$0]) }
        guard !windows.isEmpty else { return nil }
        self.id=value["limitId"].string ?? id
        name=value["limitName"].string ?? (self.id == "codex" ? "Codex":self.id)
        plan=value["planType"].string; self.windows=windows
    }
}
public struct AccountQuotaSnapshot: Equatable, Sendable {
    public private(set) var buckets:[QuotaBucket]
    public var receivedAt:Date
    public init(response:JSONValue, receivedAt:Date) {
        self.receivedAt=receivedAt
        if case .object(let map)=response["rateLimitsByLimitId"] {
            buckets=map.keys.sorted().compactMap { key in map[key].flatMap { QuotaBucket(id:key,value:$0) } }
        } else { buckets=[] }
        if buckets.isEmpty, let legacy=QuotaBucket(id:"codex",value:response["rateLimits"]) { buckets=[legacy] }
    }
    public func isStale(at now:Date) -> Bool {
        now.timeIntervalSince(receivedAt) > 75 || buckets.contains { bucket in
            bucket.windows.contains { $0.resetsAt.map { $0 <= now } ?? false }
        }
    }
    /// Push updates can describe one bucket; retain unrelated, explicitly named buckets.
    public func merging(response:JSONValue, receivedAt:Date) -> Self {
        let incoming=Self(response:response,receivedAt:receivedAt)
        guard !incoming.buckets.isEmpty else { return self }
        var merged=self
        for bucket in incoming.buckets {
            merged.buckets.removeAll { $0.id == bucket.id }; merged.buckets.append(bucket)
        }
        merged.buckets.sort { $0.id < $1.id }; merged.receivedAt=receivedAt
        return merged
    }
}
