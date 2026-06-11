import Foundation

public enum JSONValue: Codable, Equatable, Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .number(Double(value))
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            if value.rounded(.towardZero) == value {
                try container.encode(Int(value))
            } else {
                try container.encode(value)
            }
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    public var objectValue: [String: JSONValue]? {
        if case .object(let value) = self {
            value
        } else {
            nil
        }
    }

    public func compacted(maxStringLength: Int = 1_200, maxArrayCount: Int = 8, maxDepth: Int = 6) -> JSONValue {
        guard maxDepth > 0 else {
            return .string("<nested>")
        }

        switch self {
        case .object(let object):
            return .object(
                object.mapValues {
                    $0.compacted(
                        maxStringLength: maxStringLength,
                        maxArrayCount: maxArrayCount,
                        maxDepth: maxDepth - 1
                    )
                }
            )
        case .array(let array):
            let prefix = array.prefix(maxArrayCount).map {
                $0.compacted(
                    maxStringLength: maxStringLength,
                    maxArrayCount: maxArrayCount,
                    maxDepth: maxDepth - 1
                )
            }
            if array.count > maxArrayCount {
                return .array(prefix + [.string("<\(array.count - maxArrayCount) more>")])
            }
            return .array(Array(prefix))
        case .string(let value):
            if value.count > maxStringLength {
                let end = value.index(value.startIndex, offsetBy: maxStringLength)
                return .string(String(value[..<end]) + "...<truncated>")
            }
            return self
        case .number, .bool, .null:
            return self
        }
    }

    public func jsonString(pretty: Bool = false) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes] : [
            .sortedKeys,
            .withoutEscapingSlashes,
        ]

        guard let data = try? encoder.encode(self), let string = String(data: data, encoding: .utf8) else {
            return "<invalid-json>"
        }
        return string
    }
}

extension Dictionary where Key == String, Value == JSONValue {
    func adding(_ key: String, _ value: String?) -> [String: JSONValue] {
        guard let value else {
            return self
        }

        var copy = self
        copy[key] = .string(value)
        return copy
    }

    func adding(_ key: String, _ value: Int?) -> [String: JSONValue] {
        guard let value else {
            return self
        }

        var copy = self
        copy[key] = .number(Double(value))
        return copy
    }

    func adding(_ key: String, _ value: Bool?) -> [String: JSONValue] {
        guard let value else {
            return self
        }

        var copy = self
        copy[key] = .bool(value)
        return copy
    }
}
