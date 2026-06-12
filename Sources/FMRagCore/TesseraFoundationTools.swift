import FoundationModels

protocol TesseraToolArguments: Sendable {
    var mcpArguments: [String: JSONValue] { get }
}

struct EmptyArguments: TesseraToolArguments {
    var mcpArguments: [String: JSONValue] {
        [:]
    }
}

struct FilterArguments: Sendable {
    var source: String?
    var system: String?
    var artifact_layer: String?
    var domain: String?
    var module: String?
    var document_source: String?
    var authority: String?
    var version: String?
    var document_id: String?
    var page: Int?

    func add(to arguments: [String: JSONValue]) -> [String: JSONValue] {
        arguments
            .adding("source", source)
            .adding("system", system)
            .adding("artifact_layer", artifact_layer)
            .adding("domain", domain)
            .adding("module", module)
            .adding("document_source", document_source)
            .adding("authority", authority)
            .adding("version", version)
            .adding("document_id", document_id)
            .adding("page", page)
    }
}

struct TesseraToolExecutor: Sendable {
    let name: String
    let client: TesseraMCPClient
    let trace: ToolCallTrace

    func call(arguments: [String: JSONValue]) async throws -> String {
        await trace.record(toolName: name, arguments: arguments)
        let response = try await client.callTool(name: name, arguments: arguments)
        return TesseraToolResponseFormatter.format(
            toolName: name,
            arguments: arguments,
            response: response
        )
    }
}

public enum TesseraFoundationToolFactory {
    public static func makeTools(client: TesseraMCPClient, trace: ToolCallTrace) -> [any Tool] {
        [
            ListSourcesTool(client: client, trace: trace),
            SearchRulesTool(client: client, trace: trace),
            SearchExactTool(client: client, trace: trace),
            SearchIdentifiersTool(client: client, trace: trace),
            CountIdentifiersTool(client: client, trace: trace),
            CountTextMatchesTool(client: client, trace: trace),
            SearchTablesTool(client: client, trace: trace),
            OpenChunkTool(client: client, trace: trace),
            OpenTableTool(client: client, trace: trace),
            GetContextTool(client: client, trace: trace),
            FindRuleNumberTool(client: client, trace: trace),
            TraceRequirementTool(client: client, trace: trace),
            FindModuleTool(client: client, trace: trace),
        ]
    }
}

struct ListSourcesTool: Tool {
    let name = "list_sources"
    let description = "Discover configured sources, source metadata, available filter facets, status, and configuration errors. Use this to understand what collections and filters exist; it does not search document content."
    let executor: TesseraToolExecutor

    init(client: TesseraMCPClient, trace: ToolCallTrace) {
        executor = TesseraToolExecutor(name: name, client: client, trace: trace)
    }

    @Generable
    struct Arguments: TesseraToolArguments {
        var mcpArguments: [String: JSONValue] {
            [:]
        }
    }

    func call(arguments: Arguments) async throws -> String {
        try await executor.call(arguments: arguments.mcpArguments)
    }
}

struct SearchRulesTool: Tool {
    let name = "search_rules"
    let description = "Search rule and knowledge text by meaning for intent-oriented questions. Use this when the user asks in natural language and you need relevant passages before deciding whether more specific lookup is needed."
    let executor: TesseraToolExecutor

    init(client: TesseraMCPClient, trace: ToolCallTrace) {
        executor = TesseraToolExecutor(name: name, client: client, trace: trace)
    }

    @Generable
    struct Arguments: TesseraToolArguments {
        @Guide(description: "Search query")
        let query: String
        @Guide(description: "Maximum number of results")
        let limit: Int?
        @Guide(description: "Response view: full or summary")
        let view: String?
        let source: String?
        let system: String?
        let artifact_layer: String?
        let domain: String?
        let module: String?
        let document_source: String?
        let authority: String?
        let version: String?
        let document_id: String?
        let page: Int?

        var mcpArguments: [String: JSONValue] {
            filters.add(to: ["query": .string(query)])
                .adding("limit", limit)
                .adding("view", view)
        }

        private var filters: FilterArguments {
            FilterArguments(
                source: source,
                system: system,
                artifact_layer: artifact_layer,
                domain: domain,
                module: module,
                document_source: document_source,
                authority: authority,
                version: version,
                document_id: document_id,
                page: page
            )
        }
    }

    func call(arguments: Arguments) async throws -> String {
        try await executor.call(arguments: arguments.mcpArguments)
    }
}

struct SearchExactTool: Tool {
    let name = "search_exact"
    let description = "Search indexed text for exact words or phrases with FTS5/BM25. Use this when the user supplies distinctive terms, identifiers, names, calibers, or quoted phrases that should appear literally."
    let executor: TesseraToolExecutor

    init(client: TesseraMCPClient, trace: ToolCallTrace) {
        executor = TesseraToolExecutor(name: name, client: client, trace: trace)
    }

    @Generable
    struct Arguments: TesseraToolArguments {
        @Guide(description: "Term or phrase to search for")
        let term: String
        @Guide(description: "Maximum number of results")
        let limit: Int?
        @Guide(description: "Response view: full or summary")
        let view: String?
        let source: String?
        let system: String?
        let artifact_layer: String?
        let domain: String?
        let module: String?
        let document_source: String?
        let authority: String?
        let version: String?
        let document_id: String?
        let page: Int?

        var mcpArguments: [String: JSONValue] {
            FilterArguments(
                source: source,
                system: system,
                artifact_layer: artifact_layer,
                domain: domain,
                module: module,
                document_source: document_source,
                authority: authority,
                version: version,
                document_id: document_id,
                page: page
            )
            .add(to: ["term": .string(term)])
            .adding("limit", limit)
            .adding("view", view)
        }
    }

    func call(arguments: Arguments) async throws -> String {
        try await executor.call(arguments: arguments.mcpArguments)
    }
}

struct SearchIdentifiersTool: Tool {
    let name = "search_identifiers"
    let description = "Search by requirement IDs, discipline numbers, rule numbers, or technical prefixes. Use this when the user gives a structured identifier rather than a prose question."
    let executor: TesseraToolExecutor

    init(client: TesseraMCPClient, trace: ToolCallTrace) {
        executor = TesseraToolExecutor(name: name, client: client, trace: trace)
    }

    @Generable
    struct Arguments: TesseraToolArguments {
        @Guide(description: "Identifier query")
        let query: String
        @Guide(description: "Maximum number of results")
        let limit: Int?
        @Guide(description: "Identifier kind filter")
        let kind: String?
        @Guide(description: "Include related identifiers where available")
        let include_related: Bool?
        @Guide(description: "Maximum number of related identifiers per hit")
        let relation_limit: Int?
        @Guide(description: "Response view: full or summary")
        let view: String?
        let source: String?
        let system: String?
        let artifact_layer: String?
        let domain: String?
        let module: String?
        let document_source: String?
        let authority: String?
        let version: String?
        let document_id: String?
        let page: Int?

        var mcpArguments: [String: JSONValue] {
            FilterArguments(
                source: source,
                system: system,
                artifact_layer: artifact_layer,
                domain: domain,
                module: module,
                document_source: document_source,
                authority: authority,
                version: version,
                document_id: document_id,
                page: page
            )
            .add(to: ["query": .string(query)])
            .adding("limit", limit)
            .adding("kind", kind)
            .adding("include_related", include_related)
            .adding("relation_limit", relation_limit)
            .adding("view", view)
        }
    }

    func call(arguments: Arguments) async throws -> String {
        try await executor.call(arguments: arguments.mcpArguments)
    }
}

struct CountIdentifiersTool: Tool {
    let name = "count_identifiers"
    let description = "Count identifiers in the index under optional metadata filters. Use this for quantitative questions about how many IDs exist, not for finding answer passages."
    let executor: TesseraToolExecutor

    init(client: TesseraMCPClient, trace: ToolCallTrace) {
        executor = TesseraToolExecutor(name: name, client: client, trace: trace)
    }

    @Generable
    struct Arguments: TesseraToolArguments {
        @Guide(description: "Identifier query")
        let query: String?
        @Guide(description: "Identifier match mode: exact, prefix, contains, fts, or all")
        let match_mode: String?
        @Guide(description: "Identifier kind filter")
        let kind: String?
        @Guide(description: "Distinct counting mode: value or identifier")
        let distinct: String?
        @Guide(description: "Maximum number of sample identifiers")
        let sample_limit: Int?
        let source: String?
        let system: String?
        let artifact_layer: String?
        let domain: String?
        let module: String?
        let document_source: String?
        let authority: String?
        let version: String?
        let document_id: String?
        let page: Int?

        var mcpArguments: [String: JSONValue] {
            FilterArguments(
                source: source,
                system: system,
                artifact_layer: artifact_layer,
                domain: domain,
                module: module,
                document_source: document_source,
                authority: authority,
                version: version,
                document_id: document_id,
                page: page
            )
            .add(to: [:])
            .adding("query", query)
            .adding("match_mode", match_mode)
            .adding("kind", kind)
            .adding("distinct", distinct)
            .adding("sample_limit", sample_limit)
        }
    }

    func call(arguments: Arguments) async throws -> String {
        try await executor.call(arguments: arguments.mcpArguments)
    }
}

struct CountTextMatchesTool: Tool {
    let name = "count_text_matches"
    let description = "Count how often a term or phrase appears in indexed text. Use this for frequency questions, not for answering what a rule says."
    let executor: TesseraToolExecutor

    init(client: TesseraMCPClient, trace: ToolCallTrace) {
        executor = TesseraToolExecutor(name: name, client: client, trace: trace)
    }

    @Generable
    struct Arguments: TesseraToolArguments {
        @Guide(description: "Term or phrase to count")
        let term: String
        @Guide(description: "Text match mode: exact_phrase or fts")
        let match_mode: String?
        @Guide(description: "Text count unit: chunks or occurrences")
        let count_unit: String?
        @Guide(description: "Maximum number of sample chunks")
        let sample_limit: Int?
        let source: String?
        let system: String?
        let artifact_layer: String?
        let domain: String?
        let module: String?
        let document_source: String?
        let authority: String?
        let version: String?
        let document_id: String?
        let page: Int?

        var mcpArguments: [String: JSONValue] {
            FilterArguments(
                source: source,
                system: system,
                artifact_layer: artifact_layer,
                domain: domain,
                module: module,
                document_source: document_source,
                authority: authority,
                version: version,
                document_id: document_id,
                page: page
            )
            .add(to: ["term": .string(term)])
            .adding("match_mode", match_mode)
            .adding("count_unit", count_unit)
            .adding("sample_limit", sample_limit)
        }
    }

    func call(arguments: Arguments) async throws -> String {
        try await executor.call(arguments: arguments.mcpArguments)
    }
}

struct SearchTablesTool: Tool {
    let name = "search_tables"
    let description = "Search table artifacts by caption, header, cell, or table text. Use this when the answer may be in a table, especially concrete values, rows, columns, calibers, measurements, limits, or mappings. Use open_table before final answers that depend on table rows or cells."
    let executor: TesseraToolExecutor

    init(client: TesseraMCPClient, trace: ToolCallTrace) {
        executor = TesseraToolExecutor(name: name, client: client, trace: trace)
    }

    @Generable
    struct Arguments: TesseraToolArguments {
        @Guide(description: "Table search query")
        let query: String
        @Guide(description: "Maximum number of results")
        let limit: Int?
        @Guide(description: "Response view: full or summary")
        let view: String?
        let source: String?
        let system: String?
        let artifact_layer: String?
        let domain: String?
        let module: String?
        let document_source: String?
        let authority: String?
        let version: String?
        let document_id: String?
        let page: Int?

        var mcpArguments: [String: JSONValue] {
            FilterArguments(
                source: source,
                system: system,
                artifact_layer: artifact_layer,
                domain: domain,
                module: module,
                document_source: document_source,
                authority: authority,
                version: version,
                document_id: document_id,
                page: page
            )
            .add(to: ["query": .string(query)])
            .adding("limit", limit)
            .adding("view", view)
        }
    }

    func call(arguments: Arguments) async throws -> String {
        try await executor.call(arguments: arguments.mcpArguments)
    }
}

struct OpenChunkTool: Tool {
    let name = "open_chunk"
    let description = "Retrieve one indexed text chunk by chunk ID returned from a prior search. Use this to inspect the full evidence behind a summarized text hit."
    let executor: TesseraToolExecutor

    init(client: TesseraMCPClient, trace: ToolCallTrace) {
        executor = TesseraToolExecutor(name: name, client: client, trace: trace)
    }

    @Generable
    struct Arguments: TesseraToolArguments {
        @Guide(description: "Chunk ID to retrieve")
        let chunk_id: String

        var mcpArguments: [String: JSONValue] {
            ["chunk_id": .string(chunk_id)]
        }
    }

    func call(arguments: Arguments) async throws -> String {
        try await executor.call(arguments: arguments.mcpArguments)
    }
}

struct OpenTableTool: Tool {
    let name = "open_table"
    let description = "Retrieve one indexed table by table ID returned from a prior table search. This is the canonical verifier for table-row and table-cell evidence."
    let executor: TesseraToolExecutor

    init(client: TesseraMCPClient, trace: ToolCallTrace) {
        executor = TesseraToolExecutor(name: name, client: client, trace: trace)
    }

    @Generable
    struct Arguments: TesseraToolArguments {
        @Guide(description: "Table ID to retrieve")
        let table_id: String
        @Guide(description: "Response view: full, markdown, plain_text, or compact")
        let view: String?
        @Guide(description: "Zero-based offset into data rows; the header row is always retained")
        let row_offset: Int?
        @Guide(description: "Maximum number of data rows to return")
        let row_limit: Int?

        var mcpArguments: [String: JSONValue] {
            ["table_id": .string(table_id)]
                .adding("view", view)
                .adding("row_offset", row_offset)
                .adding("row_limit", row_limit)
        }
    }

    func call(arguments: Arguments) async throws -> String {
        try await executor.call(arguments: arguments.mcpArguments)
    }
}

struct GetContextTool: Tool {
    let name = "get_context"
    let description = "Retrieve neighbouring chunks before and after a known chunk ID. Use this when a search hit needs surrounding context before answering."
    let executor: TesseraToolExecutor

    init(client: TesseraMCPClient, trace: ToolCallTrace) {
        executor = TesseraToolExecutor(name: name, client: client, trace: trace)
    }

    @Generable
    struct Arguments: TesseraToolArguments {
        @Guide(description: "Chunk ID to retrieve context around")
        let chunk_id: String
        @Guide(description: "Number of preceding chunks to return")
        let before: Int?
        @Guide(description: "Number of following chunks to return")
        let after: Int?
        @Guide(description: "Include non-primary chunks in the context window")
        let include_non_primary: Bool?

        var mcpArguments: [String: JSONValue] {
            ["chunk_id": .string(chunk_id)]
                .adding("before", before)
                .adding("after", after)
                .adding("include_non_primary", include_non_primary)
        }
    }

    func call(arguments: Arguments) async throws -> String {
        try await executor.call(arguments: arguments.mcpArguments)
    }
}

struct FindRuleNumberTool: Tool {
    let name = "find_rule_number"
    let description = "Find structural rule or section numbers across all indexed sources. Use this when the user asks for or provides a rule number, section number, or structural location."
    let executor: TesseraToolExecutor

    init(client: TesseraMCPClient, trace: ToolCallTrace) {
        executor = TesseraToolExecutor(name: name, client: client, trace: trace)
    }

    @Generable
    struct Arguments: TesseraToolArguments {
        @Guide(description: "Rule or section number")
        let number: String
        @Guide(description: "Maximum number of results")
        let limit: Int?
        @Guide(description: "Include descendant section numbers")
        let include_descendants: Bool?
        let source: String?
        let system: String?
        let artifact_layer: String?
        let domain: String?
        let module: String?
        let document_source: String?
        let authority: String?
        let version: String?
        let document_id: String?
        let page: Int?

        var mcpArguments: [String: JSONValue] {
            FilterArguments(
                source: source,
                system: system,
                artifact_layer: artifact_layer,
                domain: domain,
                module: module,
                document_source: document_source,
                authority: authority,
                version: version,
                document_id: document_id,
                page: page
            )
            .add(to: ["number": .string(number)])
            .adding("limit", limit)
            .adding("include_descendants", include_descendants)
        }
    }

    func call(arguments: Arguments) async throws -> String {
        try await executor.call(arguments: arguments.mcpArguments)
    }
}

struct TraceRequirementTool: Tool {
    let name = "trace_requirement"
    let description = "Trace upstream and downstream links for a requirement ID or chunk ID. Use this for dependency, provenance, or relationship questions after an ID is known."
    let executor: TesseraToolExecutor

    init(client: TesseraMCPClient, trace: ToolCallTrace) {
        executor = TesseraToolExecutor(name: name, client: client, trace: trace)
    }

    @Generable
    struct Arguments: TesseraToolArguments {
        @Guide(description: "Requirement ID to trace")
        let requirement_id: String?
        @Guide(description: "Chunk ID to trace")
        let chunk_id: String?
        @Guide(description: "Trace direction: downstream, upstream, or both")
        let direction: String?
        @Guide(description: "Maximum number of trace hits")
        let limit: Int?
        @Guide(description: "Include unresolved link references")
        let include_unresolved: Bool?
        let source: String?
        let system: String?
        let artifact_layer: String?
        let domain: String?
        let module: String?
        let document_source: String?
        let authority: String?
        let version: String?
        let document_id: String?
        let page: Int?

        var mcpArguments: [String: JSONValue] {
            FilterArguments(
                source: source,
                system: system,
                artifact_layer: artifact_layer,
                domain: domain,
                module: module,
                document_source: document_source,
                authority: authority,
                version: version,
                document_id: document_id,
                page: page
            )
            .add(to: [:])
            .adding("requirement_id", requirement_id)
            .adding("chunk_id", chunk_id)
            .adding("direction", direction)
            .adding("limit", limit)
            .adding("include_unresolved", include_unresolved)
        }
    }

    func call(arguments: Arguments) async throws -> String {
        try await executor.call(arguments: arguments.mcpArguments)
    }
}

struct FindModuleTool: Tool {
    let name = "find_module"
    let description = "Find DIM module names by name search. Use this only for module-name lookup questions."
    let executor: TesseraToolExecutor

    init(client: TesseraMCPClient, trace: ToolCallTrace) {
        executor = TesseraToolExecutor(name: name, client: client, trace: trace)
    }

    @Generable
    struct Arguments: TesseraToolArguments {
        @Guide(description: "Module name to search for")
        let module_name: String
        @Guide(description: "Maximum number of results")
        let limit: Int?
        let source: String?
        let system: String?
        let artifact_layer: String?
        let domain: String?
        let module: String?
        let document_source: String?
        let authority: String?
        let version: String?
        let document_id: String?
        let page: Int?

        var mcpArguments: [String: JSONValue] {
            FilterArguments(
                source: source,
                system: system,
                artifact_layer: artifact_layer,
                domain: domain,
                module: module,
                document_source: document_source,
                authority: authority,
                version: version,
                document_id: document_id,
                page: page
            )
            .add(to: ["module_name": .string(module_name)])
            .adding("limit", limit)
        }
    }

    func call(arguments: Arguments) async throws -> String {
        try await executor.call(arguments: arguments.mcpArguments)
    }
}
