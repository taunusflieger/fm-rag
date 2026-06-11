import Foundation
import Testing

@testable import FMRagCore

@Test func staticCatalogContainsAllTesseraTools() {
    let names = TesseraToolCatalog.definitions.map(\.name)

    #expect(names == [
        "list_sources",
        "search_rules",
        "search_exact",
        "search_identifiers",
        "count_identifiers",
        "count_text_matches",
        "search_tables",
        "open_chunk",
        "open_table",
        "get_context",
        "find_rule_number",
        "trace_requirement",
        "find_module",
    ])
}

@Test func clientRejectsUnknownToolBeforeHTTPRequest() async throws {
    let transport = MockHTTPTransport(responses: [])
    let client = TesseraMCPClient(transport: transport)

    do {
        _ = try await client.callTool(name: "missing_tool", arguments: [:])
        Issue.record("Expected unknown tool error")
    } catch let error as TesseraMCPError {
        #expect(error == .unknownTool("missing_tool"))
    }

    #expect(await transport.requests.isEmpty)
}

@Test func clientInitializesSessionAndEncodesToolCall() async throws {
    let transport = MockHTTPTransport(responses: [
        .init(
            statusCode: 200,
            headers: ["mcp-session-id": "session-1"],
            body: """
            data:
            id: 0
            retry: 3000

            data: {"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-03-26"}}

            """
        ),
        .init(statusCode: 202, body: ""),
        .init(
            statusCode: 200,
            body: """
            data:
            id: 0/0
            retry: 3000

            data: {"jsonrpc":"2.0","id":2,"result":{"structuredContent":{"found":true,"table_id":"table-1"},"isError":false}}

            """
        ),
    ])
    let client = TesseraMCPClient(transport: transport)

    let result = try await client.callTool(
        name: "open_table",
        arguments: ["table_id": .string("table-1"), "view": .string("compact")]
    )

    #expect(result.objectValue?["structuredContent"]?.objectValue?["table_id"] == .string("table-1"))

    let requests = await transport.requests
    #expect(requests.count == 3)
    #expect(requests[0].value(at: "method") == .string("initialize"))
    #expect(requests[1].value(at: "method") == .string("notifications/initialized"))
    #expect(requests[2].value(at: "method") == .string("tools/call"))
    #expect(requests[2].value(at: "params.name") == .string("open_table"))
    #expect(requests[2].value(at: "params.arguments.table_id") == .string("table-1"))
    #expect(requests[2].headers["mcp-session-id"] == "session-1")
}

@Test func formatterPreservesIdentifiersAndCompactsLongText() {
    let output = TesseraToolResponseFormatter.format(
        toolName: "open_table",
        arguments: ["table_id": .string("table-1")],
        response: .object([
            "structuredContent": .object([
                "found": .bool(true),
                "table": .object([
                    "table_id": .string("table-1"),
                    "semantic_text": .string(String(repeating: "x", count: 1_500)),
                ]),
            ]),
        ])
    )

    #expect(output.contains("tool: open_table"))
    #expect(output.contains("table_id: table-1"))
    #expect(output.contains("<truncated>"))
}

@Test func traceFormatsObservedToolCalls() async {
    let trace = ToolCallTrace()

    await trace.record(toolName: "search_rules", arguments: ["query": .string("mindestimpuls")])

    #expect(await trace.lines() == [
        "Tool: search_rules arguments={\"query\":\"mindestimpuls\"}",
    ])
}

private actor MockHTTPTransport: HTTPTransport {
    private var responses: [MockHTTPResponse]
    private(set) var requests: [RecordedRequest] = []

    init(responses: [MockHTTPResponse]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(try RecordedRequest(request: request))
        let response = responses.removeFirst()
        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: response.statusCode,
            httpVersion: nil,
            headerFields: response.headers
        )!
        return (Data(response.body.utf8), httpResponse)
    }
}

private struct MockHTTPResponse {
    var statusCode: Int
    var headers: [String: String]
    var body: String

    init(statusCode: Int, headers: [String: String] = [:], body: String) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

private struct RecordedRequest {
    var headers: [String: String]
    var body: JSONValue

    init(request: URLRequest) throws {
        headers = request.allHTTPHeaderFields ?? [:]
        body = try JSONDecoder().decode(JSONValue.self, from: request.httpBody ?? Data())
    }

    func value(at path: String) -> JSONValue? {
        var current = body
        for component in path.split(separator: ".").map(String.init) {
            guard let object = current.objectValue, let next = object[component] else {
                return nil
            }
            current = next
        }
        return current
    }
}
