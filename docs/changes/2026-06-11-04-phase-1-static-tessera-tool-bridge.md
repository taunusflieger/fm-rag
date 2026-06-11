# 2026-06-11-04: Phase 1 Static Tessera Tool Bridge

**Status:** Implemented

**Created:** 2026-06-11

## Goal

Wire the existing Tessera MCP RAG server into the Phase 1 CLI through a static Apple Foundation Models tool catalog that exposes every Tessera MCP tool registered by the local Tessera server.

Success means a supported macOS machine can run the CLI with a known question against the configured Tessera data set, observe that the Foundation Model chooses among the full static Tessera tool surface, see a compact tool-call trace from Tessera, and receive an answer grounded in retrieved context.

This change implements Phase 1 step 3 only. It does not complete the full Phase 1 runbook polish from step 4.

This change intentionally revises the initial one-tool interpretation of step 3. A single app-owned "search and open everything" tool would prove only that the model can invoke one black-box retrieval function. It would not say much about the system model's ability to use tools.

This change also intentionally avoids narrowing the model to only `search_rules`, `open_table`, and `open_chunk`. That restriction could hide better Tessera paths such as exact search, identifier search, section lookup, table search, context expansion, counts, or source inspection. Step 3 therefore exposes all Tessera tools statically while still avoiding a runtime `tools/list` discovery call.

## Tessera Server To Use

Use the local Tessera repository at:

```text
/Users/michael/src/tessera
```

Use Tessera with the DSB data set. The primary source name is:

```text
dsb_sportordnung_online
```

Tessera evidence from the current local repository:

- `server/src/main.rs` hosts the MCP service at `/mcp`.
- `server/src/config.rs` defaults `TESSERA_PORT` to `3000`.
- `scripts/runtime_up_dsb.sh` starts the DSB runtime with:
  - `TESSERA_DB_PATH=runtime_dsb/data/tessera.sqlite`
  - `TESSERA_QDRANT_DATA=runtime_dsb/qdrant`
  - `TESSERA_RETRIEVAL_CONFIG=retrieval.yaml`
  - `TESSERA_SOURCES_FILE=configs/sources.dsb.yaml`
  - `TESSERA_QDRANT_COLLECTION=tessera_dsb`
- `configs/sources.dsb.yaml` defines `dsb_sportordnung_online` as the DSB Sportordnung source with version `Stand 01.01.2026`.
- `server/src/server.rs` registers these MCP tools: `list_sources`, `search_rules`, `search_exact`, `search_identifiers`, `count_identifiers`, `count_text_matches`, `search_tables`, `open_chunk`, `open_table`, `get_context`, `find_rule_number`, `trace_requirement`, and `find_module`.
- `server/tests/mcp_db_integration.rs` contains a DSB business case for `welcher mindestimpuls ist für 9mm vorgeschrieben`, expecting the retrieved table to contain `2.53`, `9 mm`, `Luger`, and `250`.

## Scope

Implement:

- A static Apple Foundation Models tool for every Tessera MCP tool registered in `/Users/michael/src/tessera/server/src/server.rs`:
  - `list_sources`
  - `search_rules`
  - `search_exact`
  - `search_identifiers`
  - `count_identifiers`
  - `count_text_matches`
  - `search_tables`
  - `open_chunk`
  - `open_table`
  - `get_context`
  - `find_rule_number`
  - `trace_requirement`
  - `find_module`
- A narrow Tessera MCP client for the local HTTP endpoint at `http://127.0.0.1:3000/mcp`.
- A static in-repo tool catalog copied from Tessera source, not obtained by calling MCP `tools/list` at runtime.
- Tool names, descriptions, argument names, required arguments, enum values, and argument descriptions that mirror Tessera `build_tools()` source.
- Model-directed tool use:
  - the model decides whether to call Tessera tools;
  - the model decides which Tessera tool to call;
  - the model decides whether to call follow-up tools using IDs or hints returned by earlier tool calls;
  - each Apple tool forwards exactly one corresponding Tessera MCP tool call and formats only that tool's response as compact plain text.
- CLI output that shows a compact tool-call trace before the final answer.
- Prompt/session instructions that require the model to answer from retrieved context and say when retrieved context is insufficient.
- Focused tests for request encoding, response decoding, evidence selection, evidence formatting, and prompt/instruction assembly.
- README and `docs/architecture.md` updates for the Tessera run path with the configured data set.

Allowed paths:

- `Sources/FMRagCLI/main.swift`
- `Sources/FMRagCore/`
- `Tests/FMRagCoreTests/`
- `README.md`
- `docs/architecture.md`
- `docs/changes/2026-06-11-04-phase-1-static-tessera-tool-bridge.md`
- `implementation_plan.md`

## Non-Goals

Do not implement:

- A generic MCP client framework beyond the narrow call path needed to invoke the static catalog.
- Dynamic MCP tool discovery in the production path.
- Multiple MCP servers.
- Multiple retrieval providers.
- Runtime provider selection or configuration files.
- A source-group picker.
- Authentication, retry policies, caching, persistence, telemetry, or streaming.
- A GUI or interactive REPL.
- Domain-specific rule logic in Swift.
- Hardcoded answers for individual questions.
- Broad citation UX beyond compact source/tool/table/chunk trace lines.
- Step 4 documentation polish beyond the run instructions needed for this change.
- A hidden app-side chain that automatically opens tables, chunks, context, or follow-up searches without a model tool call.

## Required Preflight

Run these commands before editing product files:

```sh
swift --version
xcrun --show-sdk-path
swift build
swift test
```

Start the Tessera runtime with the acceptance data set in a separate terminal from `/Users/michael/src/tessera`:

```sh
cargo make up-dsb
```

If `cargo make up-dsb` fails because `runtime_dsb/data/tessera.sqlite`, `runtime_dsb/qdrant`, or the vector collection is missing, stop and report the missing runtime artifact. Do not silently switch to a different data set. A fallback to `cargo make up-reqlense-dsb` is allowed only if the implementation report explicitly records that the Tessera-owned runtime was unavailable and that the adjacent DSB regression runtime was used for manual acceptance.

Confirm the HTTP endpoint is reachable:

```sh
curl --max-time 5 -i http://127.0.0.1:3000/mcp
```

Known Tessera behavior: a plain HTTP probe may return an MCP-session error such as HTTP `406` or `400`. That still proves the host-running server is reachable. It does not prove the MCP client contract.

## MCP Contract Capture Gate

Before writing the Swift MCP client, capture a known-good MCP exchange against the running Tessera server with the acceptance data set loaded.

Do not use MCP `tools/list` to build the Step 3 tool catalog. The catalog for this change is static and comes from `/Users/michael/src/tessera/server/src/server.rs`.

Required captured calls:

1. `initialize`
2. `tools/call` for `list_sources` with `{}` and a response containing `dsb_sportordnung_online`
3. `tools/call` for at least one search or lookup tool that can answer the acceptance question, for example `search_rules`:

```json
{
  "query": "welcher mindestimpuls ist für 9mm vorgeschrieben",
  "limit": 5,
  "view": "summary",
  "document_source": "dsb_sportordnung_online"
}
```

4. One model-useful follow-up `tools/call` chosen from the returned evidence, for example:
   - `open_table` with a returned `table_id`, `view: "compact"` or `view: "full"`;
   - `open_chunk` with a returned `chunk_id`;
   - `get_context` with a returned `chunk_id`;
   - `find_rule_number` with a rule or section number found by an earlier tool.

Record the exact HTTP method, URL, required headers, session handling, JSON-RPC envelope, request body, and response shape in the implementation report or README. Use Tessera's actual running server response as the source of truth.

Do not implement the Swift MCP client until this capture is complete. Do not guess the Streamable HTTP MCP framing from memory.

## Official Foundation Models API Evidence Gate

Before writing any Foundation Models tool code, open and record current official Apple documentation for every Foundation Models API used by this change.

Required Apple documentation pages:

- `Tool`
  - `https://developer.apple.com/documentation/foundationmodels/tool`
- `Tool.call(arguments:)`
  - `https://developer.apple.com/documentation/foundationmodels/tool/call(arguments:)`
- `Tool.Arguments`
  - `https://developer.apple.com/documentation/foundationmodels/tool/arguments`
- `Tool.Output`
  - `https://developer.apple.com/documentation/foundationmodels/tool/output`
- `Generable`
  - `https://developer.apple.com/documentation/foundationmodels/generable`
- `Guide(description:)`
  - `https://developer.apple.com/documentation/foundationmodels/guide(description:)`
- `LanguageModelSession.init(model:tools:instructions:)`
  - `https://developer.apple.com/documentation/foundationmodels/languagemodelsession/init(model:tools:instructions:)`
- `LanguageModelSession.respond(to:options:)`
  - `https://developer.apple.com/documentation/foundationmodels/languagemodelsession/respond(to:options:)`

Evidence already checked while preparing this change:

- `Tool` is documented as a model-callable tool for runtime information.
- `Tool.call(arguments:)` is documented as `async throws -> Self.Output`.
- `Generable` is documented as the protocol used for generated prompt data.
- `Guide(description:)` is documented as a macro for describing generated properties.

The implementer must refresh and record this evidence in the implementation report before code edits. If official Apple documentation does not support the selected tool shape, stop and report the evidence gap.

## Design

The CLI command shape remains:

```sh
swift run fm-rag "Welcher Mindestimpuls ist für 9 mm Luger vorgeschrieben?"
```

Expected successful output shape:

```text
Question: Welcher Mindestimpuls ist für 9 mm Luger vorgeschrieben?
Foundation Models: available
Tool: search_rules arguments=<compact-json>
Tool: <one-or-more-model-selected-follow-up-tools> arguments=<compact-json>
Answer: <grounded model response>
```

The tool trace must be produced by app code from observed tool calls, not inferred from model answer text.

### Static Tessera Tool Catalog

Create exactly one Apple Foundation Models `Tool` for each Tessera MCP tool currently registered by `/Users/michael/src/tessera/server/src/server.rs`.

The Apple tool names must be identical to the Tessera MCP tool names:

- `list_sources`
- `search_rules`
- `search_exact`
- `search_identifiers`
- `count_identifiers`
- `count_text_matches`
- `search_tables`
- `open_chunk`
- `open_table`
- `get_context`
- `find_rule_number`
- `trace_requirement`
- `find_module`

The Apple tool descriptions must be copied from Tessera `build_tools()`:

| Tool | Description |
| --- | --- |
| `list_sources` | Returns configured rule sources with source metadata, status, available filter facets, and configuration errors. |
| `search_rules` | Semantic or hybrid search over rules for intent-oriented queries. |
| `search_exact` | Full-text (FTS5/BM25) search for exact terms or phrases. |
| `search_identifiers` | Search by requirement IDs, discipline numbers, or technical prefixes. |
| `count_identifiers` | Count identifiers in the index under optional metadata filters. |
| `count_text_matches` | Count how often a term or phrase appears in the indexed text. |
| `search_tables` | Search candidate table artifacts by caption, header, cell, or table text. Use open_table before final answers that depend on concrete rows, cells, row sets, or column relationships. |
| `open_chunk` | Retrieve one indexed text chunk by its chunk ID. |
| `open_table` | Retrieve one indexed table by table ID. This is the canonical verifier for table-row and table-cell evidence. |
| `get_context` | Retrieve neighbouring chunks before and after a known chunk ID. |
| `find_rule_number` | Find structural rule or section numbers across all indexed sources. |
| `trace_requirement` | Trace upstream and downstream links for a requirement ID or chunk ID. |
| `find_module` | Find DIM module names by name search. |

Mirror the Tessera JSON schema from `build_tools()` as Apple `@Generable` argument types. Use optional Swift properties for optional MCP arguments. Required properties must match the `required` arrays in Tessera source.

Shared optional metadata filters for tools that use `filtered_properties`:

| Argument | Type | Description |
| --- | --- | --- |
| `source` | `String?` | Source metadata filter; known list_sources.name values are accepted as document_source aliases |
| `system` | `String?` | System metadata filter |
| `artifact_layer` | `String?` | Artifact-layer metadata filter |
| `domain` | `String?` | Domain metadata filter |
| `module` | `String?` | Module metadata filter |
| `document_source` | `String?` | Canonical document source-name filter; use this for list_sources.name values |
| `authority` | `String?` | Document authority filter |
| `version` | `String?` | Document version filter |
| `document_id` | `String?` | Document ID filter |
| `page` | `Int?` | Page number contained in the indexed artifact page range |

Per-tool arguments:

| Tool | Required | Additional arguments |
| --- | --- | --- |
| `list_sources` | none | none |
| `search_rules` | `query` | `query: String` "Search query"; `limit: Int?` "Maximum number of results"; `view: String?` "Response view", enum `full`, `summary`; shared metadata filters |
| `search_exact` | `term` | `term: String` "Term or phrase to search for"; `limit: Int?`; `view: String?` enum `full`, `summary`; shared metadata filters |
| `search_identifiers` | `query` | `query: String` "Identifier query"; `limit: Int?`; `kind: String?` "Identifier kind filter"; `include_related: Bool?`; `relation_limit: Int?`; `view: String?` enum `full`, `summary`; shared metadata filters |
| `count_identifiers` | none | `query: String?`; `match_mode: String?` enum `exact`, `prefix`, `contains`, `fts`, `all`; `kind: String?`; `distinct: String?` enum `value`, `identifier`; `sample_limit: Int?`; shared metadata filters |
| `count_text_matches` | `term` | `term: String` "Term or phrase to count"; `match_mode: String?` enum `exact_phrase`, `fts`; `count_unit: String?` enum `chunks`, `occurrences`; `sample_limit: Int?`; shared metadata filters |
| `search_tables` | `query` | `query: String` "Table search query"; `limit: Int?`; `view: String?` enum `full`, `summary`; shared metadata filters |
| `open_chunk` | `chunk_id` | `chunk_id: String` "Chunk ID to retrieve" |
| `open_table` | `table_id` | `table_id: String` "Table ID to retrieve"; `view: String?` "Response view: full, markdown, plain_text, or compact"; `row_offset: Int?`; `row_limit: Int?` |
| `get_context` | `chunk_id` | `chunk_id: String` "Chunk ID to retrieve context around"; `before: Int?`; `after: Int?`; `include_non_primary: Bool?` |
| `find_rule_number` | `number` | `number: String` "Rule or section number"; `limit: Int?`; `include_descendants: Bool?`; shared metadata filters |
| `trace_requirement` | none | `requirement_id: String?`; `chunk_id: String?`; `direction: String?` enum `downstream`, `upstream`, `both`; `limit: Int?`; `include_unresolved: Bool?`; shared metadata filters |
| `find_module` | `module_name` | `module_name: String` "Module name to search for"; `limit: Int?`; shared metadata filters |

Use this shape only if it still matches current official Apple documentation and compilation. If the installed SDK requires a different documented shape, update the implementation accordingly and record the documentation reference.

### Tessera Client Shape

Add a narrow client owned by `FMRagCore`, for example:

```text
Sources/FMRagCore/
  TesseraMCPClient.swift
  RetrievalEvidence.swift
  RetrievalFormatting.swift
  PromptAssembly.swift
```

The client should expose a small testable surface, for example:

```swift
struct TesseraMCPClient {
    func callTool(name: String, arguments: [String: JSONValue]) async throws -> JSONValue
}
```

Keep `callTool(name:arguments:)` constrained to the static catalog. The method must reject names that are not in the copied Tessera tool list before making an HTTP request. This is not a dynamic MCP framework; it is the narrow transport used by the statically declared Apple tools.

Use `URLSession` and `JSONEncoder` / `JSONDecoder`; do not add package dependencies for HTTP or JSON.

### Model-Directed Tool Flow

The app must not hide a multi-step Tessera retrieval sequence behind one model-facing call. The model-facing flow is:

1. The model decides whether the user question needs Tessera evidence.
2. If evidence is needed, the model chooses one of the statically exposed Tessera tools.
3. The selected Apple tool forwards one MCP `tools/call` request to Tessera with the same tool name and model-generated arguments.
4. The tool returns compact plain text that preserves the structured fields the model needs for follow-up calls.
5. The model decides whether to call another Tessera tool using IDs, counts, source names, table IDs, chunk IDs, rule numbers, or tool hints returned by the previous tool.
6. Each tool formats compact plain text for the model:
   - include source name;
   - include tool name;
   - include IDs needed for follow-up calls, including `table_id`, `chunk_id`, requirement IDs, rule numbers, source names, and module names when present;
   - include page, score, caption, headers, rows, text, counts, or errors when present;
   - include enough text/cells/counts to support the answer;
   - keep the total tool output short enough for the model context.

Tool outputs must not invent facts. If Tessera returns no useful results or an error, the relevant tool returns a compact text message that says retrieved context is unavailable or insufficient.

### Prompt Instructions

Update session instructions so the model:

- chooses among the available Tessera tools for source-backed rule and knowledge questions;
- may call `list_sources` to inspect available sources and filters;
- may use semantic, exact, identifier, table, section, count, context, trace, or module tools according to the question;
- opens table or chunk evidence with `open_table`, `open_chunk`, or `get_context` before answering when search results contain only summaries or IDs;
- answers from retrieved evidence when it used tools;
- says the retrieved context is insufficient when the tool output does not contain the needed fact;
- does not invent citations, rule numbers, calibers, or values that are not present in the retrieved evidence.

Do not force every general prompt through tools unless the official SDK provides a documented tool-choice mode and the implementation has grounded it. If forcing a tool is not clearly documented, use the instructions plus the acceptance question.

## Implementation Steps

1. Complete preflight and evidence gates.
   - Run Swift preflight commands.
   - Start the Tessera runtime with the configured data set.
   - Capture the MCP contract calls.
   - Refresh and record Apple Tool API documentation.
   - Verify: no product files are edited until these gates are complete.

2. Add stable model-facing tool data models and formatting.
   - Add request/response types for the captured Tessera response shapes.
   - Add `ToolCallTrace` or equivalent.
   - Add compact formatter for generic Tessera tool responses and trace lines.
   - Verify: focused tests cover success, empty results, Tessera error, and ID-preserving output formatting.

3. Add the narrow Tessera MCP client.
   - Implement only the captured Streamable HTTP MCP request pattern.
   - Hard-code endpoint `http://127.0.0.1:3000/mcp` for this change.
   - Reject tool names that are not in the static Tessera tool catalog before making an HTTP request.
   - Do not hard-code data-set filters into the client or into individual tools.
   - Verify: tests cover request encoding, allowed-tool validation, and response decoding with captured JSON fixtures or inline literals.

4. Add the Foundation Models Tessera tools.
   - Implement one Apple `Tool` for each static Tessera catalog entry.
   - Inject the Tessera client through tool initializers so tool behavior can be tested with a fake client.
   - Register exactly the static Tessera tool catalog in `LanguageModelSession`.
   - Verify: tool tests use a fake client and do not call the live model or live Tessera server.

5. Update CLI output and prompt instructions.
   - Preserve existing question and availability output.
   - Print observed tool-call trace lines from app code.
   - Print the final answer.
   - Verify: invalid argument behavior remains unchanged.

6. Update docs and status.
   - Update README with the Tessera startup command and acceptance command.
   - Update `docs/architecture.md` with the Step 3 boundary.
   - Mark this change `Implemented` only after all required verification passes.

## Verification

Required commands from `/Users/michael/src/fm-rag`:

```sh
swift build
swift test
swift run fm-rag "Welcher Mindestimpuls ist für 9 mm Luger vorgeschrieben?"
```

Required Tessera runtime command from `/Users/michael/src/tessera` in a separate terminal:

```sh
cargo make up-dsb
```

Manual acceptance:

- Tessera runtime is running on `http://127.0.0.1:3000/mcp` with the configured acceptance data set.
- `list_sources` capture contains `dsb_sportordnung_online`.
- At least one captured Tessera search or lookup call for the acceptance question returns useful evidence.
- The model calls at least one Tessera tool from the static catalog.
- If the model's first tool call returns only summaries, IDs, counts, or hints, the model calls at least one follow-up Tessera tool when needed to inspect the underlying evidence.
- CLI output includes a tool-call trace line.
- The final answer uses retrieved facts and includes the evidence that the 9 mm Luger Mindestimpuls value is `250`.
- The answer does not mention facts absent from retrieved context.

If the model does not call any Tessera tool for the acceptance question, inspect whether official documentation supports tool-choice forcing. Do not invent a private API or prompt hack. If no documented forcing mode exists, report the blocker with the prompt, transcript evidence, and the registered tool availability.

## Acceptance Criteria

- Preflight outputs are recorded.
- MCP contract capture is recorded with exact HTTP/session/JSON-RPC details.
- Foundation Models `Tool` API evidence is recorded from official Apple documentation.
- `swift build` succeeds.
- `swift test` succeeds.
- Unit tests do not call live Foundation Models or live Tessera.
- Running the acceptance CLI command against a live Tessera runtime prints:
  - the original question;
  - Foundation Models availability;
  - tool-call trace;
  - a non-empty answer.
- Tool-call request encoding preserves model-provided arguments without injecting data-set-specific defaults.
- Deterministic tests cover Tessera response decoding and evidence formatting.
- No generic MCP framework, dynamic discovery production path, multi-provider abstraction, source picker, caching, retries, or hardcoded answer is added.
- `docs/architecture.md` reflects that Step 3 has a static full Tessera tool catalog backed by the local Tessera MCP server.
- `implementation_plan.md` marks this change as `Implemented` only after all required verification passes.

## Known Failure Signatures

- `curl http://127.0.0.1:3000/mcp` returns connection refused.
  - Tessera is not running or is on a different port. Start `cargo make up-dsb` or record the actual `TESSERA_PORT`.
- `cargo make up-dsb` reports missing `runtime_dsb/data/tessera.sqlite` or `runtime_dsb/qdrant`.
  - The Tessera acceptance runtime has not been built. Stop and report the missing runtime artifact; do not switch data sets silently.
- A static tool from the copied catalog returns `unknown tool`.
  - The copied catalog no longer matches the running Tessera server. Stop and compare `/Users/michael/src/tessera/server/src/server.rs` with the Swift catalog.
- `list_sources` does not include `dsb_sportordnung_online`.
  - The wrong source config or data set is loaded.
- `search_rules` returns `database_not_configured`.
  - Tessera started without a database path; inspect `TESSERA_DB_PATH`.
- `search_rules` returns results but no openable `table_id` or `chunk_id`.
  - Update evidence selection only from the captured response shape; do not infer unavailable IDs.
- The live CLI reports `Foundation Models generation failed` after a Tessera tool call succeeds.
  - Preserve the tool-call trace and report the Foundation Models error separately from Tessera errors.
- Xcode prints Apple Biome instrumentation messages.
  - Treat those as Apple framework console noise unless the app also prints `Foundation Models generation failed`.

## Wrong Fixes To Avoid

- Do not hardcode the answer `250`.
- Do not hardcode a specific table ID unless it came from live Tessera tool output in the same run.
- Do not bypass Tessera by reading its SQLite database directly.
- Do not call Tessera Rust crates in-process from `fm-rag`.
- Do not add dynamic MCP discovery to the production retrieval path.
- Do not collapse search and open into a hidden app-side retrieval orchestrator.
- Do not invent Apple-only tool names or omit Tessera tools from the static catalog.
- Do not add dependencies before proving `URLSession` is insufficient.
- Do not hard-code data-set-specific filters into generic tool implementations.
- Do not mark this change implemented if the model never calls a Tessera tool during the live acceptance question.

## Implementation Evidence

Preflight and verification ran from `/Users/michael/src/fm-rag` on 2026-06-11:

- `swift --version`
  - `swift-driver version: 1.167 Apple Swift version 6.4`
  - target `arm64-apple-macosx27.0.0`
- `xcrun --show-sdk-path`
  - `/Applications/Xcode-beta.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk`
- `swift build`
  - passed
- `swift test`
  - passed with 13 Swift Testing tests

Tessera runtime and MCP contract capture:

- Runtime command from `/Users/michael/src/tessera`: `cargo make up-dsb`
- Server endpoint: `http://127.0.0.1:3000/mcp`
- Plain probe: `curl --max-time 5 -i http://127.0.0.1:3000/mcp`
  - returned HTTP `406 Not Acceptable`, confirming the server was reachable and enforcing Streamable HTTP accept headers.
- `initialize`:
  - method: `POST`
  - URL: `http://127.0.0.1:3000/mcp`
  - headers: `Content-Type: application/json`, `Accept: application/json, text/event-stream`
  - response: HTTP `200 OK`, `content-type: text/event-stream`, `mcp-session-id: 1fb8ae5c-3cdf-4006-bb58-4a2137230408`
  - server info: `rmcp` `1.7.0`
- `notifications/initialized`:
  - same URL and accept headers with `mcp-session-id`
  - response: HTTP `202 Accepted`
- `tools/call` `list_sources`:
  - response included `dsb_sportordnung_online`
- `tools/call` `search_rules` with:

```json
{
  "query": "welcher mindestimpuls ist für 9mm vorgeschrieben",
  "limit": 5,
  "view": "summary",
  "document_source": "dsb_sportordnung_online"
}
```

  - response included a table hit with `table_id: table:dsb_sportordnung_online:f13136507ee3:000076:911a9b0cdcb9`
- `tools/call` `open_table` with that table ID and `view: "compact"`:
  - response included the row evidence for `9 mm Luger (9x19)` with Mindestimpuls `250`

Official Apple Foundation Models documentation was refreshed before product edits:

- `https://developer.apple.com/documentation/foundationmodels/tool`
- `https://developer.apple.com/documentation/foundationmodels/tool/call(arguments:)`
- `https://developer.apple.com/documentation/foundationmodels/generable`
- `https://developer.apple.com/documentation/foundationmodels/languagemodelsession/init(model:tools:instructions:)`

Final live acceptance command:

```sh
swift run fm-rag "Welcher Mindestimpuls ist für 9 mm Luger vorgeschrieben?"
```

Final observed output shape:

```text
Question: Welcher Mindestimpuls ist für 9 mm Luger vorgeschrieben?
Foundation Models: available
Tool: search_rules arguments={"query":"Mindestimpuls 9 mm Luger","view":"summary"}
Answer: Laut der Sportordnung des Deutschen Schützenbundes beträgt der Mindestimpuls für eine 9-mm-Pistole (Kaliber 9x19) 250 J.
```

## Post-Implementation Validation Result

Subsequent live DSB validation proved the static Tessera MCP bridge technically,
but also showed that the current Apple Foundation Models context size is too
small for useful DSB-scale RAG in this shape.

Observed failing commands included:

```sh
swift run fm-rag "Welche Diziplinen darf man mit einer mehrschüssigen Luftpistole schiessen?"
swift run fm-rag "Welcher Mindestimpuls ist für 9mm vorgeschrieben?"
```

Observed failure signature:

```text
Foundation Models generation failed: Content contains 4100 tokens, which exceeds the maximum allowed context size of 4096.
```

The conclusion is that Step 3 achieved the technical integration objective, but
the current Apple Foundation Models runtime is not practically useful for the
tested DSB RAG workload. The bridge should not compensate with domain-specific
table, index, or retrieval heuristics, because that would change the evidence
surface and obscure the model/tool suitability result.
