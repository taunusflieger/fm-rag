public enum TesseraToolResponseFormatter {
    public static func format(
        toolName: String,
        arguments: [String: JSONValue],
        response: JSONValue
    ) -> String {
        let payload = response.objectValue?["structuredContent"] ?? response
        let compactPayload = evidencePayload(from: payload)
        let compactArguments = JSONValue.object(arguments).compacted(maxStringLength: 240)

        var lines = [
            "Tessera evidence result. Use this evidence to continue the same user request. If it is sufficient, write the final answer as plain assistant text.",
            "tool: \(toolName)",
            "arguments: \(compactArguments.jsonString())",
            "result:",
            plainText(compactPayload),
        ]
        if isSearchTool(toolName) {
            lines.insert(
                "Search results are candidate evidence, not final proof. Follow tool_hints, open returned table_id values, and use get_context for returned chunk_id values before answering questions about permitted disciplines, competitions, equipment use, table rows, or rule categories.",
                at: 1
            )
        }
        return lines.joined(separator: "\n")
    }

    private static func isSearchTool(_ toolName: String) -> Bool {
        [
            "search_rules",
            "search_exact",
            "search_identifiers",
            "search_tables",
            "find_rule_number",
            "find_module",
        ].contains(toolName)
    }

    private static func plainText(_ value: JSONValue, indent: String = "") -> String {
        switch value {
        case .object(let object):
            return object.keys.sorted().compactMap { key in
                guard let value = object[key] else {
                    return nil
                }
                switch value {
                case .object, .array:
                    return "\(indent)\(key):\n\(plainText(value, indent: indent + "  "))"
                default:
                    return "\(indent)\(key): \(scalarText(value))"
                }
            }.joined(separator: "\n")
        case .array(let array):
            return array.enumerated().map { index, value in
                switch value {
                case .object, .array:
                    return "\(indent)- \(index + 1):\n\(plainText(value, indent: indent + "  "))"
                default:
                    return "\(indent)- \(scalarText(value))"
                }
            }.joined(separator: "\n")
        default:
            return "\(indent)\(scalarText(value))"
        }
    }

    private static func scalarText(_ value: JSONValue) -> String {
        switch value {
        case .string(let value):
            return value
        case .number(let value):
            if value.rounded(.towardZero) == value {
                return String(Int(value))
            }
            return String(value)
        case .bool(let value):
            return String(value)
        case .null:
            return "null"
        case .object, .array:
            return value.jsonString()
        }
    }

    private static func evidencePayload(from payload: JSONValue) -> JSONValue {
        guard let object = payload.objectValue else {
            return payload.compacted(maxStringLength: 360, maxArrayCount: 4, maxDepth: 5)
        }

        if let sources = object["sources"] {
            return .object(["sources": compactSources(sources)])
        }

        if let results = object["results"] {
            var output: [String: JSONValue] = [
                "results": compactResults(results),
            ]
            copy("query", from: object, to: &output)
            copy("tool_hints", from: object["diagnostics"]?.objectValue, to: &output)
            copy("error", from: object, to: &output)
            return .object(output)
        }

        if let table = object["table"] {
            var output: [String: JSONValue] = [
                "found": object["found"] ?? .null,
            ]
            if let tableObject = table.objectValue, looksLikeNavigationTable(tableObject) {
                output["evidence_warning"] = .string(
                    "This opened table looks like a table of contents, index, or page-reference table. Do not use it as final evidence for permitted disciplines, competitions, equipment use, or rule categories. Continue with exact search, context lookup, or table search for a substantive equipment or competition table."
                )
                output["table"] = .object(pick(
                    from: tableObject,
                    keys: ["table_id", "source_name", "document_source", "page_start", "page_end"],
                    textLimit: 160
                ))
            } else {
                output["table"] = compactArtifact(table, textLimit: 700)
            }
            copy("table_id", from: object, to: &output)
            copy("error", from: object, to: &output)
            return .object(output)
        }

        if let chunk = object["chunk"] {
            var output: [String: JSONValue] = [
                "found": object["found"] ?? .null,
                "chunk": compactArtifact(chunk, textLimit: 700),
            ]
            copy("chunk_id", from: object, to: &output)
            copy("error", from: object, to: &output)
            return .object(output)
        }

        return payload.compacted(maxStringLength: 360, maxArrayCount: 4, maxDepth: 5)
    }

    private static func compactSources(_ value: JSONValue) -> JSONValue {
        guard case .array(let sources) = value else {
            return value.compacted(maxStringLength: 240, maxArrayCount: 8, maxDepth: 4)
        }

        return .array(sources.prefix(8).map { source in
            guard let object = source.objectValue else {
                return source.compacted(maxStringLength: 240, maxArrayCount: 4, maxDepth: 4)
            }

            return .object(pick(
                from: object,
                keys: ["name", "title", "authority", "type", "status", "available_facets_status"],
                textLimit: 240
            ))
        })
    }

    private static func compactResults(_ value: JSONValue) -> JSONValue {
        guard case .array(let results) = value else {
            return value.compacted(maxStringLength: 360, maxArrayCount: 4, maxDepth: 5)
        }

        return .array(results.prefix(5).map { compactSearchHit($0) })
    }

    private static func compactSearchHit(_ value: JSONValue) -> JSONValue {
        guard let object = value.objectValue else {
            return value.compacted(maxStringLength: 180, maxArrayCount: 3, maxDepth: 3)
        }

        return .object(pick(
            from: object,
            keys: [
                "table_id",
                "chunk_id",
                "requirement_id",
                "artifact_type",
                "chunk_type",
                "source_name",
                "source",
                "authority",
                "document_source",
                "version",
                "page_start",
                "page_end",
                "score",
                "caption",
            ],
            textLimit: 180
        ))
    }

    private static func compactArtifact(_ value: JSONValue, textLimit: Int) -> JSONValue {
        guard let object = value.objectValue else {
            return value.compacted(maxStringLength: textLimit, maxArrayCount: 4, maxDepth: 4)
        }

        return .object(pick(
            from: object,
            keys: [
                "table_id",
                "chunk_id",
                "requirement_id",
                "module_name",
                "source_name",
                "document_source",
                "source",
                "title",
                "version",
                "page_start",
                "page_end",
                "score",
                "caption",
                "heading_path",
                "section_numbers",
                "rule_number_candidates",
                "row_count",
                "returned_row_count",
                "column_count",
                "snippet",
                "text",
                "semantic_text",
                "markdown",
                "plain_text",
                "error",
            ],
            textLimit: textLimit
        ))
    }

    private static func looksLikeNavigationTable(_ object: [String: JSONValue]) -> Bool {
        let text = [
            object["caption"],
            object["semantic_text"],
            object["markdown"],
            object["plain_text"],
            object["text"],
            object["snippet"],
        ]
        .compactMap { value -> String? in
            if case .string(let string) = value {
                return string.lowercased()
            }
            return nil
        }
        .joined(separator: " ")

        guard !text.isEmpty else {
            return false
        }

        if text.contains("stichwortverzeichnis") {
            return true
        }
        if text.contains("seite") && text.contains("gruppe") {
            return true
        }
        if text.contains(" s. ") && text.contains("| ---") {
            return true
        }
        return false
    }

    private static func pick(
        from object: [String: JSONValue],
        keys: [String],
        textLimit: Int
    ) -> [String: JSONValue] {
        var output: [String: JSONValue] = [:]
        for key in keys {
            guard let value = object[key] else {
                continue
            }
            output[key] = value.compacted(maxStringLength: textLimit, maxArrayCount: 6, maxDepth: 4)
        }
        return output
    }

    private static func copy(
        _ key: String,
        from object: [String: JSONValue]?,
        to output: inout [String: JSONValue]
    ) {
        guard let value = object?[key] else {
            return
        }
        output[key] = value.compacted(maxStringLength: 360, maxArrayCount: 4, maxDepth: 4)
    }
}

public enum TesseraPromptAssembly {
    public static let instructions = """
        You have access to Tessera tools for source-backed rule and knowledge questions.
        Before deciding whether or how to use a Tessera tool, inspect the provided tool names, descriptions, and argument schemas in this session. Treat that tool metadata as the capability catalog.
        Infer what each tool can do only from its name, description, parameters, and prior Tessera results. Do not assume hidden tool capabilities.
        For source-backed factual questions, use Tessera tools when the capability catalog shows that a tool can retrieve or verify the needed evidence.
        When the user explicitly asks to use Tessera tools, do not finish the turn before making at least one Tessera tool call chosen from the capability catalog.
        If you are unsure what sources or metadata filters exist, call list_sources. If you are unsure which content tool fits, compare the available tool descriptions and parameter names, then choose the closest matching tool.
        Preserve the user's language and exact domain terms in search queries. Do not translate weapon names, equipment names, calibers, rule terms, or discipline names before searching.
        For search_rules, search_exact, search_identifiers, and search_tables, use view "summary" unless the user explicitly asks for full raw search output.
        For open_table, prefer view "compact" unless the user explicitly asks for full table text.
        Do not invent metadata filter values. Only pass source, system, artifact_layer, domain, module, document_source, authority, version, document_id, or page when the user explicitly supplied that value or a previous Tessera tool returned it.
        If you are unsure which source or filter applies, either omit metadata filters or call list_sources first.
        When search results contain only summaries, IDs, counts, or hints, call follow-up tools such as open_table or get_context when needed before answering.
        When a search result contains tool_hints, follow those hints before answering unless they are clearly irrelevant to the user's question.
        For questions asking for a concrete value from a table or rule, do not answer from an empty search result. Try another Tessera search tool or open an ID returned by a prior tool.
        For questions asking which disciplines, competitions, events, or rule categories are allowed for a weapon or equipment type, do not answer from table-of-contents rows, index rows, headings, or heading-only hits. Verify with a rule context or an opened table that states the equipment, competition, or row relationship.
        For a weapon-or-equipment-to-discipline question, first call search_exact with the exact weapon or equipment phrase from the user's question. Then use get_context for relevant chunk IDs instead of open_chunk, because headings alone are not sufficient. If the evidence mentions a named table or table-like reference, search_tables for that table name plus the equipment phrase and open the returned table.
        Before reporting insufficient evidence for a weapon-or-equipment-to-discipline question, try both the exact literal search path and a table search for the weapon or equipment phrase plus discipline or competition terms.
        When a user names a specific weapon or equipment phrase, prefer exact literal search and table search over broad semantic search if the first result is only a heading, index, or table of contents.
        After Tessera returns enough evidence to answer, stop calling tools and produce a concise final answer from that evidence.
        Final answers after tool use must be plain assistant text outside reasoning blocks and outside tool-call markup.
        Answer only from retrieved evidence when you used tools. If retrieved context is insufficient, say so directly.
        Do not invent citations, rule numbers, calibers, values, or source names that are not present in retrieved evidence.
        """
}
