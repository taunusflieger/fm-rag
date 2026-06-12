public struct TesseraToolDefinition: Equatable, Sendable {
    public let name: String
    public let description: String

    public init(name: String, description: String) {
        self.name = name
        self.description = description
    }
}

public enum TesseraToolCatalog {
    public static let definitions: [TesseraToolDefinition] = [
        .init(
            name: "list_sources",
            description: "Discover configured sources, source metadata, available filter facets, status, and configuration errors. Use this to understand what collections and filters exist; it does not search document content."
        ),
        .init(
            name: "search_exact",
            description: "Search indexed text for exact words or phrases with FTS5/BM25. Use this when the user supplies distinctive terms, identifiers, equipment names, calibers, or quoted phrases that should appear literally."
        ),
        .init(
            name: "search_rules",
            description: "Search rule and knowledge text by meaning for intent-oriented questions. Use this when the user asks in natural language and you need relevant passages before deciding whether more specific lookup is needed."
        ),
        .init(
            name: "search_identifiers",
            description: "Search by requirement IDs, discipline numbers, rule numbers, or technical prefixes. Use this when the user gives a structured identifier rather than a prose question."
        ),
        .init(
            name: "count_identifiers",
            description: "Count identifiers in the index under optional metadata filters. Use this for quantitative questions about how many IDs exist, not for finding answer passages."
        ),
        .init(
            name: "count_text_matches",
            description: "Count how often a term or phrase appears in indexed text. Use this for frequency questions, not for answering what a rule says."
        ),
        .init(
            name: "search_tables",
            description: "Search table artifacts by caption, header, cell, or table text. Use this when the answer may be in a table, especially concrete values, rows, columns, calibers, measurements, limits, equipment specifications, or equipment-to-competition mappings. Use open_table before final answers that depend on table rows or cells."
        ),
        .init(
            name: "open_chunk",
            description: "Retrieve one indexed text chunk by chunk ID returned from a prior search. Use this to inspect the full evidence behind a summarized text hit."
        ),
        .init(
            name: "open_table",
            description: "Retrieve one indexed table by table ID returned from a prior table search. This is the canonical verifier for table-row and table-cell evidence."
        ),
        .init(
            name: "get_context",
            description: "Retrieve neighbouring chunks before and after a known chunk ID. Use this when a search hit needs surrounding context before answering."
        ),
        .init(
            name: "find_rule_number",
            description: "Find structural rule or section numbers across all indexed sources. Use this when the user asks for or provides a rule number, section number, or structural location."
        ),
        .init(
            name: "trace_requirement",
            description: "Trace upstream and downstream links for a requirement ID or chunk ID. Use this for dependency, provenance, or relationship questions after an ID is known."
        ),
        .init(
            name: "find_module",
            description: "Find DIM module names by name search. Use this only for module-name lookup questions."
        ),
    ]

    public static let allowedNames = Set(definitions.map(\.name))
}
