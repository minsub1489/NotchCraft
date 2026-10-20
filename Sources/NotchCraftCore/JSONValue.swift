import Foundation

public enum JSONValue: Codable, Equatable, Sendable {
    case object([String: JSONValue]), array([JSONValue]), string(String), int(Int), double(Double), bool(Bool), null
    public init(from decoder: Decoder) throws {
        let box = try decoder.singleValueContainer()
        if box.decodeNil() { self = .null }
        else if let value = try? box.decode(Bool.self) { self = .bool(value) }
        else if let value = try? box.decode(Int.self) { self = .int(value) }
        else if let value = try? box.decode(Double.self) { self = .double(value) }
        else if let value = try? box.decode(String.self) { self = .string(value) }
        else if let value = try? box.decode([JSONValue].self) { self = .array(value) }
        else { self = .object(try box.decode([String: JSONValue].self)) }
    }
    public func encode(to encoder: Encoder) throws {
        var box = encoder.singleValueContainer()
        switch self {
        case .object(let v): try box.encode(v)
        case .array(let v): try box.encode(v)
        case .string(let v): try box.encode(v)
        case .int(let v): try box.encode(v)
        case .double(let v): try box.encode(v)
        case .bool(let v): try box.encode(v)
        case .null: try box.encodeNil()
        }
    }
    public subscript(_ key: String) -> JSONValue { if case .object(let value) = self { value[key] ?? .null } else { .null } }
    public var string: String? { if case .string(let value) = self { value } else { nil } }
    public var int: Int? { if case .int(let value) = self { value } else { nil } }
    public var double: Double? {
        switch self { case .double(let v): v; case .int(let v): Double(v); default: nil }
    }
    public var array: [JSONValue] { if case .array(let value) = self { value } else { [] } }
    public var isNull: Bool { self == .null }
}
public enum FramingError: Error, Equatable { case tooLarge }
public struct LineFramer: Sendable {
    private var buffer = Data()
    private let maximumBytes: Int
    public init(maximumBytes: Int = 4 * 1024 * 1024) { self.maximumBytes = maximumBytes }
    public mutating func append(_ data: Data) throws -> [Data] {
        buffer.append(data)
        var frames: [Data] = []
        while let newline = buffer.firstIndex(of: 10) {
            guard buffer.distance(from: buffer.startIndex, to: newline) <= maximumBytes else {
                buffer.removeAll(); throw FramingError.tooLarge
            }
            let frame = buffer.subdata(in: buffer.startIndex..<newline)
            buffer.removeSubrange(buffer.startIndex...newline)
            if !frame.isEmpty { frames.append(frame) }
        }
        guard buffer.count <= maximumBytes else { buffer.removeAll(); throw FramingError.tooLarge }
        return frames
    }
}
