public actor ToolCallTrace {
    private var entries: [Entry] = []

    public init() {}

    public func record(toolName: String, arguments: [String: JSONValue]) {
        entries.append(Entry(toolName: toolName, arguments: arguments))
    }

    public func lines() -> [String] {
        entries.map(\.line)
    }

    public struct Entry: Equatable, Sendable {
        public let toolName: String
        public let arguments: [String: JSONValue]

        public var line: String {
            "Tool: \(toolName) arguments=\(JSONValue.object(arguments).jsonString())"
        }
    }
}
