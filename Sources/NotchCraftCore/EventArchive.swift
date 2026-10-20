import Foundation
import CSQLite

public enum ArchiveError: Error { case open, statement, write }
/// Contains only normalized event metadata. Prompts, responses, commands and secrets are never persisted here.
public final class EventArchive {
    private var database: OpaquePointer?
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    public init(url: URL) throws {
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            if let database { sqlite3_close(database) }; database = nil; throw ArchiveError.open
        }
        sqlite3_busy_timeout(database, 2_000)
        guard sqlite3_exec(database, "CREATE TABLE IF NOT EXISTS events (id TEXT PRIMARY KEY, time REAL NOT NULL, data BLOB NOT NULL)", nil, nil, nil) == SQLITE_OK else { throw ArchiveError.statement }
    }
    deinit { sqlite3_close(database) }
    public func record(_ event: AgentEvent) throws {
        var safe = event
        safe.permissionRequest = nil
        // Summary is a normalized, app-owned label, not a provider's raw tool output.
        safe.summary = event.eventType.rawValue
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "INSERT OR IGNORE INTO events(id,time,data) VALUES(?,?,?)", -1, &statement, nil) == SQLITE_OK else { throw ArchiveError.statement }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, event.eventID, -1, transient)
        sqlite3_bind_double(statement, 2, event.timestamp.timeIntervalSince1970)
        let bytes = try JSONEncoder().encode(safe)
        _ = bytes.withUnsafeBytes { sqlite3_bind_blob(statement, 3, $0.baseAddress, Int32(bytes.count), transient) }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw ArchiveError.write }
        // Bound disk history independently of the UI buffer.
        guard sqlite3_exec(database, "DELETE FROM events WHERE id IN (SELECT id FROM events ORDER BY time DESC LIMIT -1 OFFSET 10000)", nil, nil, nil) == SQLITE_OK else { throw ArchiveError.write }
    }
    public func recent(limit: Int = 100) throws -> [AgentEvent] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT data FROM events ORDER BY time DESC LIMIT ?", -1, &statement, nil) == SQLITE_OK else { throw ArchiveError.statement }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(clamping: min(10_000, max(0, limit))))
        var result: [AgentEvent] = []
        var status = sqlite3_step(statement)
        while status == SQLITE_ROW {
            if let blob = sqlite3_column_blob(statement, 0) {
                let data = Data(bytes: blob, count: Int(sqlite3_column_bytes(statement, 0)))
                result.append(try JSONDecoder().decode(AgentEvent.self, from: data))
            }
            status = sqlite3_step(statement)
        }
        guard status == SQLITE_DONE else { throw ArchiveError.statement }
        return result
    }
    public func deleteAll() throws {
        guard sqlite3_exec(database, "DELETE FROM events; VACUUM;", nil, nil, nil) == SQLITE_OK else { throw ArchiveError.write }
    }
}
