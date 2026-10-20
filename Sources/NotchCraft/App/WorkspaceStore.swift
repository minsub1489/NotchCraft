import AppKit
import Observation
import UserNotifications
import NotchCraftCore

@MainActor @Observable final class WorkspaceStore {
    var workspaceVisible = true
    var tab = WorkspaceTab.world
    var selectedSessionID: String?
    var search = ""
    var showNewTask = false
    var showSettings = false
    var showWelcome = !UserDefaults.standard.bool(forKey: "hasWelcomed")
    var notice: String?
    var isConnecting = false
    var isConnected = false
    var sessions: [ProviderSession] = []
    var sessionOutputs: [String: String] = [:]
    var events: [AgentEvent] = []
    var historicalEvents: [AgentEvent] = []
    var permissions: [PermissionRequest] = []
    var quota: JSONValue = .null
    var quotaUpdatedAt: Date?
    var detections = ExecutableLocator.detections()
    var language = UserDefaults.standard.string(forKey: "language") ?? "ko" { didSet { UserDefaults.standard.set(language, forKey: "language") } }
    var showNotch = UserDefaults.standard.object(forKey: "showNotch") as? Bool ?? true { didSet { UserDefaults.standard.set(showNotch, forKey: "showNotch"); onNotchVisibility?(showNotch) } }
    var reduceMotion = UserDefaults.standard.bool(forKey: "reduceMotion") { didSet { UserDefaults.standard.set(reduceMotion, forKey: "reduceMotion") } }
    var lowPower = UserDefaults.standard.bool(forKey: "lowPower") { didSet { UserDefaults.standard.set(lowPower, forKey: "lowPower") } }
    var saveHistory = UserDefaults.standard.object(forKey: "saveHistory") as? Bool ?? true { didSet { UserDefaults.standard.set(saveHistory, forKey: "saveHistory") } }
    var notifications = UserDefaults.standard.bool(forKey: "notifications") { didSet { UserDefaults.standard.set(notifications, forKey: "notifications") } }
    var projectPath = UserDefaults.standard.string(forKey: "projectPath") ?? "" { didSet { UserDefaults.standard.set(projectPath, forKey: "projectPath") } }
    var isPinned = false { didSet { onPin?(isPinned) } }
    var isDemo = false
    var onNotchVisibility: ((Bool) -> Void)?
    var onPin: ((Bool) -> Void)?
    var onOpenWorkspace: (() -> Void)?
    var onCollapse: (() -> Void)?
    private(set) var ledger = EventLedger()
    private var demoLedger = EventLedger(acceptsDemo: true)
    private var demoSessions: [ProviderSession] = []
    private var demoEvents: [AgentEvent] = []
    private var demoTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var archive: EventArchive?
    private let adapter = CodexAdapter()
    private var intentionallyDisconnected = false
    private var reconnectAttempts = 0

    var activeLedger: EventLedger { isDemo ? demoLedger : ledger }
    var visibleSessions: [ProviderSession] { isDemo ? demoSessions : sessions }
    var visibleEvents: [AgentEvent] { isDemo ? demoEvents : events + historicalEvents }
    var selectedSession: ProviderSession? { visibleSessions.first { $0.id == selectedSessionID } }
    var activeCount: Int { activeLedger.sessions.values.filter { $0.status == .working }.count }
    var workingSessions: [ProviderSession] {
        visibleSessions.filter { [.working, .waitingApproval].contains(activeLedger.sessions[$0.id]?.status ?? .unknown) }
    }
    var filteredSessions: [ProviderSession] {
        let matching = visibleSessions.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.cwd.localizedCaseInsensitiveContains(search) }
        return matching.sorted {
            let a = activeLedger.sessions[$0.id]?.status == .working
            let b = activeLedger.sessions[$1.id]?.status == .working
            return a == b ? $0.updatedAt > $1.updatedAt : a
        }
    }
    init() {
        do {
            let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("NotchCraft", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let url = folder.appendingPathComponent("activity.sqlite")
            archive = try EventArchive(url: url)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            historicalEvents = try archive?.recent(limit: 200) ?? []
        } catch { notice = L("error.archive") }
        adapter.onSessionCreated = { [weak self] session in
            self?.sessions.removeAll { $0.id == session.id }; self?.sessions.insert(session, at: 0)
        }
        adapter.onOutput = { [weak self] id, text in
            guard let self else { return }
            if self.sessionOutputs.count >= 32, self.sessionOutputs[id] == nil, let oldest = self.sessions.last(where: { self.sessionOutputs[$0.id] != nil }) { self.sessionOutputs.removeValue(forKey: oldest.id) }
            self.sessionOutputs[id] = text
        }
        adapter.onDisconnect = { [weak self] in self?.didDisconnect() }
        adapter.onUnsupportedRequest = { [weak self] _ in self?.notice = L("error.unsupportedRequest") }
    }
    func finishWelcome() { showWelcome = false; UserDefaults.standard.set(true, forKey: "hasWelcomed") }
    func connect() async {
        guard !isConnecting, !isConnected else { return }
        isConnecting = true; intentionallyDisconnected = false
        eventTask?.cancel()
        let stream = adapter.subscribeEvents()
        eventTask = Task { [weak self] in
            for await event in stream { guard !Task.isCancelled else { return }; self?.ingest(event) }
        }
        defer { isConnecting = false }
        do {
            try await adapter.connect()
            isConnected = true; reconnectAttempts = 0
            await refresh()
            refreshTask?.cancel()
            refreshTask = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(30)) } catch { return }
                    guard let self, self.isConnected else { return }
                    await self.refresh()
                }
            }
        } catch { notice = error.localizedDescription; eventTask?.cancel() }
    }
    func refresh() async {
        guard isConnected else { return }
        do {
            let discovered = try await adapter.listSessions()
            // Merge by ID; an active new thread may not yet have reached persistent discovery.
            var indexed = Dictionary(uniqueKeysWithValues: sessions.filter(\.owned).map { ($0.id, $0) })
            for session in discovered { indexed[session.id] = session }
            sessions = indexed.values.sorted { $0.updatedAt > $1.updatedAt }
        } catch { notice = error.localizedDescription }
        do { quota = try await adapter.getUsage(); quotaUpdatedAt = Date() }
        catch { quota = .null; quotaUpdatedAt = nil } // Quota is optional and is never inferred.
    }
    func disconnect() {
        intentionallyDisconnected = true; reconnectTask?.cancel(); refreshTask?.cancel(); eventTask?.cancel()
        adapter.disconnect(); didDisconnect()
    }
    private func didDisconnect() {
        isConnected = false; permissions = []; quota = .null; quotaUpdatedAt = nil; sessionOutputs = [:]
        ledger.markDisconnected(providerID: "codex")
        sessions = sessions.map { var value = $0; value.owned = false; return value }
        guard !intentionallyDisconnected, reconnectAttempts < 3 else { return }
        reconnectAttempts += 1
        let delay = 1 << reconnectAttempts
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            await self?.connect()
        }
    }
    private func ingest(_ event: AgentEvent) {
        guard ledger.apply(event) == .applied else { return }
        events.insert(event, at: 0)
        if events.count > 200 { events.removeLast(events.count - 200) }
        if saveHistory { do { try archive?.record(event) } catch { notice = L("error.archive") } }
        permissions = adapter.getPermissionRequests()
        if event.eventType == .approvalRequested || event.eventType == .taskCompleted || event.eventType == .taskFailed {
            notify(title: "Codex", body: L("event." + event.eventType.rawValue))
        }
    }
    func startTask(prompt: String, allowWrites: Bool) async {
        guard !projectPath.isEmpty else { notice = L("error.project"); return }
        do {
            let session = try await adapter.startTask(prompt: prompt, project: URL(fileURLWithPath: projectPath), allowProjectWrites: allowWrites)
            sessions.removeAll { $0.id == session.id }; sessions.insert(session, at: 0)
            selectedSessionID = session.id; showNewTask = false; tab = .world
        } catch { notice = error.localizedDescription }
    }
    func respond(_ request: PermissionRequest, allow: Bool) {
        do { try adapter.respondToPermission(request, allow: allow); permissions = adapter.getPermissionRequests() }
        catch { notice = error.localizedDescription }
    }
    func cancel(_ session: ProviderSession) async {
        guard let task = ledger.sessions[session.id]?.taskID else { return }
        do { try await adapter.cancelTask(sessionID: session.id, taskID: task) }
        catch { notice = error.localizedDescription }
    }
    func chooseProject() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        panel.prompt = L("new.choose")
        if panel.runModal() == .OK, let url = panel.url { projectPath = url.path }
    }
    func deleteHistory() {
        do { try archive?.deleteAll(); historicalEvents = []; events = [] }
        catch { notice = L("error.archive") }
    }
    func enableNotifications() async {
        do {
            notifications = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            if !notifications { notice = L("settings.notificationDenied") }
        } catch { notice = error.localizedDescription }
    }
    private func notify(title: String, body: String) {
        guard notifications else { return }
        let content = UNMutableNotificationContent(); content.title = title; content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    func setDemo(_ enabled: Bool, residentCount: Int = 6) {
        demoTask?.cancel(); isDemo = enabled; selectedSessionID = nil
        guard enabled else { demoSessions = []; demoEvents = []; demoLedger = EventLedger(acceptsDemo: true); return }
        demoLedger = EventLedger(acceptsDemo: true); demoEvents = []
        let baseNames = ["CODEX", "CLAUDE", "GEMINI", "OPENCODE", "SCOUT", "BUILDER"]
        let count = min(32, max(1, residentCount))
        let names = (0..<count).map { baseNames[$0 % 6] + ($0 >= 6 ? " \($0 / 6 + 1)" : "") }
        let activities: [ActivityType] = [.building, .research, .farming, .automation, .mining, .crafting]
        demoSessions = names.enumerated().map { ProviderSession(id: "demo-\($0.offset)", name: $0.element, provider: "DEMO", model: L("demo.agent"), cwd: "", updatedAt: Date()) }
        for index in names.indices { demoEvent(index: index, type: index < 4 ? .taskStarted : .connected, activity: activities[index % 6]) }
        demoTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(4)) } catch { return }
                guard let self else { return }
                let index = tick % count
                self.demoEvent(index: index, type: tick % 5 == 4 ? .taskCompleted : .taskStarted, activity: activities[(tick / 6 + index) % 6])
                tick += 1
            }
        }
    }
    private func demoEvent(index: Int, type: EventType, activity: ActivityType) {
        let id = "demo-\(index)"
        let event = AgentEvent(providerID: "demo", adapterID: "demo", agentID: id, sessionID: id,
                               taskID: UUID().uuidString, eventType: type, activityType: activity, source: .demo)
        _ = demoLedger.apply(event); demoEvents.insert(event, at: 0)
        if demoEvents.count > 50 { demoEvents.removeLast() }
    }
    func shutdown() { intentionallyDisconnected = true; disconnect(); demoTask?.cancel() }
}
enum WorkspaceTab: String, CaseIterable, Identifiable {
    case world, agents, activity, usage
    var id: String { rawValue }
    var symbol: String { switch self { case .world: "square.3.layers.3d"; case .agents: "person.2"; case .activity: "clock.arrow.circlepath"; case .usage: "chart.bar.xaxis" } }
}
