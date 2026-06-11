import Foundation

public actor TesseraMCPClient {
    private let endpoint: URL
    private let transport: HTTPTransport
    private var sessionID: String?
    private var nextRequestID = 1

    public init(
        endpoint: URL = URL(string: "http://127.0.0.1:3000/mcp")!,
        transport: HTTPTransport = URLSessionHTTPTransport()
    ) {
        self.endpoint = endpoint
        self.transport = transport
    }

    public func callTool(name: String, arguments: [String: JSONValue]) async throws -> JSONValue {
        guard TesseraToolCatalog.allowedNames.contains(name) else {
            throw TesseraMCPError.unknownTool(name)
        }

        try await initializeIfNeeded()

        let id = nextID()
        let request = try makeRequest(
            body: .object([
                "jsonrpc": .string("2.0"),
                "id": .number(Double(id)),
                "method": .string("tools/call"),
                "params": .object([
                    "name": .string(name),
                    "arguments": .object(arguments),
                ]),
            ]),
            sessionID: sessionID
        )

        let response = try await send(request)
        guard let result = response.objectValue?["result"] else {
            if let error = response.objectValue?["error"] {
                throw TesseraMCPError.rpcError(error.jsonString())
            }
            throw TesseraMCPError.missingResult(response.jsonString())
        }

        return result
    }

    private func initializeIfNeeded() async throws {
        guard sessionID == nil else {
            return
        }

        let id = nextID()
        let request = try makeRequest(
            body: .object([
                "jsonrpc": .string("2.0"),
                "id": .number(Double(id)),
                "method": .string("initialize"),
                "params": .object([
                    "protocolVersion": .string("2025-03-26"),
                    "capabilities": .object([:]),
                    "clientInfo": .object([
                        "name": .string("fm-rag"),
                        "version": .string("0.1.0"),
                    ]),
                ]),
            ]),
            sessionID: nil
        )

        let (_, httpResponse) = try await transport.data(for: request)
        try validate(httpResponse)

        guard let sessionID = header("mcp-session-id", in: httpResponse) else {
            throw TesseraMCPError.missingSessionID
        }
        self.sessionID = sessionID

        let initialized = try makeRequest(
            body: .object([
                "jsonrpc": .string("2.0"),
                "method": .string("notifications/initialized"),
                "params": .object([:]),
            ]),
            sessionID: sessionID
        )
        let (_, initializedResponse) = try await transport.data(for: initialized)
        try validate(initializedResponse)
    }

    private func nextID() -> Int {
        defer {
            nextRequestID += 1
        }
        return nextRequestID
    }

    private func makeRequest(body: JSONValue, sessionID: String?) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        if let sessionID {
            request.setValue(sessionID, forHTTPHeaderField: "mcp-session-id")
        }
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func send(_ request: URLRequest) async throws -> JSONValue {
        let (data, response) = try await transport.data(for: request)
        try validate(response)
        return try decodeStreamableHTTPBody(data)
    }

    private func validate(_ response: HTTPURLResponse) throws {
        guard (200...299).contains(response.statusCode) else {
            throw TesseraMCPError.httpStatus(response.statusCode)
        }
    }

    private func decodeStreamableHTTPBody(_ data: Data) throws -> JSONValue {
        guard let body = String(data: data, encoding: .utf8) else {
            throw TesseraMCPError.invalidUTF8Body
        }

        for rawLine in body.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("data:") else {
                continue
            }

            let payload = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
            guard payload.first == "{" else {
                continue
            }

            return try JSONDecoder().decode(JSONValue.self, from: Data(payload.utf8))
        }

        throw TesseraMCPError.missingDataEvent(body)
    }

    private func header(_ name: String, in response: HTTPURLResponse) -> String? {
        for (key, value) in response.allHeaderFields {
            guard let key = key as? String, key.caseInsensitiveCompare(name) == .orderedSame else {
                continue
            }
            return value as? String
        }
        return nil
    }
}

public protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionHTTPTransport: HTTPTransport {
    public init() {}

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TesseraMCPError.nonHTTPResponse
        }
        return (data, httpResponse)
    }
}

public enum TesseraMCPError: Error, Equatable, CustomStringConvertible {
    case unknownTool(String)
    case nonHTTPResponse
    case httpStatus(Int)
    case missingSessionID
    case invalidUTF8Body
    case missingDataEvent(String)
    case missingResult(String)
    case rpcError(String)

    public var description: String {
        switch self {
        case .unknownTool(let name):
            "unknown Tessera tool: \(name)"
        case .nonHTTPResponse:
            "Tessera MCP response was not HTTP"
        case .httpStatus(let status):
            "Tessera MCP HTTP status \(status)"
        case .missingSessionID:
            "Tessera MCP initialize response did not include mcp-session-id"
        case .invalidUTF8Body:
            "Tessera MCP response body is not UTF-8"
        case .missingDataEvent(let body):
            "Tessera MCP response did not contain a JSON data event: \(body)"
        case .missingResult(let body):
            "Tessera MCP response did not contain result: \(body)"
        case .rpcError(let body):
            "Tessera MCP RPC error: \(body)"
        }
    }
}
