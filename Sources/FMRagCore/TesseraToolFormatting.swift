public enum TesseraToolResponseFormatter {
    public static func format(
        toolName: String,
        arguments: [String: JSONValue],
        response: JSONValue
    ) -> String {
        let payload = response.objectValue?["structuredContent"] ?? response
        let compactPayload = evidencePayload(from: payload)
        let compactArguments = JSONValue.object(arguments).compacted(maxStringLength: 240)

        return [
            "tool: \(toolName)",
            "arguments: \(compactArguments.jsonString())",
            "result:",
            plainText(compactPayload),
        ].joined(separator: "\n")
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
                "table": compactArtifact(table, textLimit: 700),
            ]
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

        return .array(results.prefix(2).map { compactSearchHit($0) })
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
                "source_name",
                "document_source",
                "title",
                "page_start",
                "page_end",
                "score",
                "caption",
                "heading_path",
                "section_numbers",
                "snippet",
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
        If you are unsure what sources or metadata filters exist, call list_sources. If you are unsure which content tool fits, compare the available tool descriptions and parameter names, then choose the closest matching tool.
        For search_rules, search_exact, search_identifiers, and search_tables, use view "summary" unless the user explicitly asks for full raw search output.
        For open_table, prefer view "compact" unless the user explicitly asks for full table text.
        Do not invent metadata filter values. Only pass source, system, artifact_layer, domain, module, document_source, authority, version, document_id, or page when the user explicitly supplied that value or a previous Tessera tool returned it.
        If you are unsure which source or filter applies, either omit metadata filters or call list_sources first.
        When search results contain only summaries, IDs, counts, or hints, call follow-up tools such as open_table, open_chunk, or get_context when needed before answering.
        For questions asking for a concrete value from a table or rule, do not answer from an empty search result. Try another Tessera search tool or open an ID returned by a prior tool.
        Answer only from retrieved evidence when you used tools. If retrieved context is insufficient, say so directly.
        Do not invent citations, rule numbers, calibers, values, or source names that are not present in retrieved evidence.
        """
}
