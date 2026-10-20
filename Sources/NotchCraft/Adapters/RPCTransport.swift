import Foundation
import NotchCraftCore

/// Private stdio transport. No listening ports or shared authentication tokens.
@MainActor final class RPCTransport {
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var errorOutput: FileHandle?
    private var framer = LineFramer()
    private var pending: [Int: CheckedContinuation<JSONValue, any Error>] = [:]
    private var deadlines: [Int: Task<Void, Never>] = [:]
    private var nextID = 1
    var onMessage: ((JSONValue) -> Void)?
    var onDisconnect: (() -> Void)?
    var isRunning: Bool { process?.isRunning == true }

    func start(executable: URL) throws {
        stop(notify: false)
        let process = Process()
        let stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
        process.executableURL = executable
        process.arguments = ["app-server", "--stdio", "-c", "analytics.enabled=false"]
        process.standardInput = stdin; process.standardOutput = stdout; process.standardError = stderr
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = [executable.deletingLastPathComponent().path, environment["PATH"] ?? "", "/usr/bin", "/bin", "/usr/sbin", "/sbin"].joined(separator: ":")
        process.environment = environment
        output = stdout.fileHandleForReading; input = stdin.fileHandleForWriting; errorOutput = stderr.fileHandleForReading
        output?.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            Task { @MainActor [weak self] in self?.consume(data) }
        }
        // Drain diagnostics without saving raw provider output or credentials.
        errorOutput?.readabilityHandler = { handle in _ = handle.availableData }
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in self?.stop() }
        }
        try process.run()
        self.process = process
    }
    func request(_ method: String, params: JSONValue = .object([:])) async throws -> JSONValue {
        guard isRunning else { throw AdapterError.disconnected }
        let id = nextID; nextID += 1
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending[id] = continuation
                do {
                    try send(.object(["id": .int(id), "method": .string(method), "params": params]))
                    deadlines[id] = Task { [weak self] in
                        do { try await Task.sleep(for: .seconds(20)) } catch { return }
                        self?.finish(id: id, result: .failure(AdapterError.timeout))
                    }
                } catch { finish(id: id, result: .failure(error)) }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.finish(id: id, result: .failure(CancellationError())) }
        }
    }
    func notify(_ method: String) throws { try send(.object(["method": .string(method), "params": .object([:])])) }
    func respond(id: JSONValue, result: JSONValue) throws { try send(.object(["id": id, "result": result])) }
    func rejectUnsupported(id: JSONValue) throws {
        try send(.object(["id": id, "error": .object(["code": .int(-32601), "message": .string("This request type is not supported by NotchCraft.")])]))
    }
    private func send(_ value: JSONValue) throws {
        guard let input, isRunning else { throw AdapterError.disconnected }
        var data = try JSONEncoder().encode(value)
        guard data.count <= 1024 * 1024 else { throw AdapterError.invalidInput }
        data.append(10)
        try input.write(contentsOf: data)
    }
    private func consume(_ data: Data) {
        guard !data.isEmpty else { return }
        do {
            for line in try framer.append(data) {
                let message = try JSONDecoder().decode(JSONValue.self, from: line)
                if message["method"].isNull, let id = message["id"].int {
                    if !message["error"].isNull { finish(id: id, result: .failure(AdapterError.remote(message["error"]["code"].int ?? -1))) }
                    else { finish(id: id, result: .success(message["result"])) }
                } else { onMessage?(message) }
            }
        } catch { stop() }
    }
    private func finish(id: Int, result: Result<JSONValue, any Error>) {
        deadlines.removeValue(forKey: id)?.cancel()
        pending.removeValue(forKey: id)?.resume(with: result)
    }
    func stop(notify: Bool = true) {
        let wasRunning = process != nil
        output?.readabilityHandler = nil; errorOutput?.readabilityHandler = nil
        process?.terminationHandler = nil
        try? input?.close(); try? output?.close(); try? errorOutput?.close()
        if process?.isRunning == true { process?.terminate() }
        process = nil; input = nil; output = nil; errorOutput = nil; framer = LineFramer()
        for id in Array(pending.keys) { finish(id: id, result: .failure(AdapterError.disconnected)) }
        if wasRunning && notify { onDisconnect?() }
    }
}
