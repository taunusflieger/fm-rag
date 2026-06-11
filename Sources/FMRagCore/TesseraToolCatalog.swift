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
            description: "Returns configured rule sources with source metadata, status, available filter facets, and configuration errors."
        ),
        .init(
            name: "search_rules",
            description: "Semantic or hybrid search over rules for intent-oriented queries."
        ),
        .init(
            name: "search_exact",
            description: "Full-text (FTS5/BM25) search for exact terms or phrases."
        ),
        .init(
            name: "search_identifiers",
            description: "Search by requirement IDs, discipline numbers, or technical prefixes."
        ),
        .init(
            name: "count_identifiers",
            description: "Count identifiers in the index under optional metadata filters."
        ),
        .init(
            name: "count_text_matches",
            description: "Count how often a term or phrase appears in the indexed text."
        ),
        .init(
            name: "search_tables",
            description: "Search candidate table artifacts by caption, header, cell, or table text. Use open_table before final answers that depend on concrete rows, cells, row sets, or column relationships."
        ),
        .init(
            name: "open_chunk",
            description: "Retrieve one indexed text chunk by its chunk ID."
        ),
        .init(
            name: "open_table",
            description: "Retrieve one indexed table by table ID. This is the canonical verifier for table-row and table-cell evidence."
        ),
        .init(
            name: "get_context",
            description: "Retrieve neighbouring chunks before and after a known chunk ID."
        ),
        .init(
            name: "find_rule_number",
            description: "Find structural rule or section numbers across all indexed sources."
        ),
        .init(
            name: "trace_requirement",
            description: "Trace upstream and downstream links for a requirement ID or chunk ID."
        ),
        .init(
            name: "find_module",
            description: "Find DIM module names by name search."
        ),
    ]

    public static let allowedNames = Set(definitions.map(\.name))
}
