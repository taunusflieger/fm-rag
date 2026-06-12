# Architecture

This document records the current technical architecture for the Phase 1 command-line proof of concept.

## Current Boundary

The current implementation proves the local Foundation Models path with a
static Tessera MCP tool bridge and adds an explicit local Core AI model loading
path:

```text
CLI argument
  -> FMRagCLI
  -> model selection
  -> SystemLanguageModel.default availability check
     or CoreAILanguageModel(resourcesAt:) bundle load
  -> LanguageModelSession with static Tessera tools
  -> model-selected tool calls
  -> Tessera MCP Streamable HTTP endpoint
  -> local model response grounded in tool output
  -> CLI output
```

The CLI preserves the original question line, reports Foundation Models
availability for the default system-model path or the Core AI model name and
bundle path for `--coreai-model`, prints observed Tessera tool-call trace lines,
and prints the generated answer when the selected model can run the session.

This boundary proves technical integration, not practical viability for every
RAG workload. Live validation against the DSB data set showed that ordinary
retrieval output can exceed the observed Foundation Models 4096-token context
limit. The bridge therefore must not hide that limitation with domain-specific
retrieval heuristics or aggressive evidence rewriting. When a live run fails
with an error such as `Content contains 4100 tokens, which exceeds the maximum
allowed context size of 4096`, the result is a model-context limitation rather
than a Tessera integration failure.

If `SystemLanguageModel.default.availability` is unavailable, the CLI prints the documented unavailable reason and exits nonzero before creating a `LanguageModelSession`.

If `--coreai-model <path>` is supplied, the CLI validates that the path exists
and is a directory before loading a model. The Core AI path loads
`CoreAILanguageModel(resourcesAt:)` from the adjacent `coreai-models` checkout
and creates a `LanguageModelSession` with the same Tessera tools and prompt
instructions as the default Foundation Models path. The current local
`coreai-models` checkout advertises `.toolCalling` for exported bundles whose
tokenizer exposes tool-call markers and routes generated tool-call markup to
Foundation Models `toolCalls(...)` channel events. The upstream tool-calling
fix was tracked as
[`apple/coreai-models#28`](https://github.com/apple/coreai-models/issues/28).

Live Core AI RAG acceptance has two observed modes:

- A direct tool prompt such as `List the available sources using the provided
  tool.` calls `list_sources` and returns a non-empty answer.
- The accepted DSB retrieval prompt
  `Nutze Tessera tools. Welcher Mindestimpuls ist fuer 9 mm Luger vorgeschrieben?`
  makes the model choose a Tessera search tool and returns the 9 mm Luger
  Mindestimpuls value `250`.

The Tessera system instructions make tool selection capability-driven: the
model is told to inspect the available tool names, descriptions, and argument
schemas as its capability catalog before choosing a tool. This keeps retrieval
selection inside the model/tool loop without hardcoded Swift-side orchestration.
Core AI runs pass `GenerationOptions(maximumResponseTokens: 768)` because the
default 512-token budget can end Qwen3 4B after tool use before any plain
assistant response is emitted. A 1024-token budget is not used because local
testing hit the Core AI engine failure
`Engine not returned after drain() — tokenSequence Task stuck?`.
For deeper RAG questions that require exact search, context expansion, table
search, and table verification, Qwen3 4B remains model-limited and can still
stop early or answer from insufficient evidence.

The CLI must not compensate for model-specific tool-selection weaknesses by
hardcoding retrieval, bypassing the Tessera MCP client, or hiding retrieval
orchestration outside model-selected tool calls.

The CLI flushes stdout after the question and availability lines so framework
stderr output from Foundation Models does not reorder the user-visible status
lines in Xcode or other consoles.

## Foundation Models API Use

The implementation uses only the official Apple-documented symbols needed for the local model and tool-calling path:

- `SystemLanguageModel.default`
- `SystemLanguageModel.availability`
- `SystemLanguageModel.Availability.available`
- `SystemLanguageModel.Availability.unavailable(_:)`
- `SystemLanguageModel.Availability.UnavailableReason`
- `Tool`
- `Tool.call(arguments:)`
- `Generable`
- `Guide(description:)`
- `LanguageModelSession.init(model:tools:instructions:)`
- `LanguageModelSession.respond(to:options:)`
- `LanguageModelSession.Response.content`

The Core AI integration is grounded in the local `/Users/michael/src/coreai-models`
checkout:

- `Package.swift` defines product `CoreAILM`, module target
  `CoreAILanguageModels`, and platform `.macOS("27.0")`.
- `models/qwen3/README.md` documents Qwen3 4B as supported on macOS and shows
  loading a Core AI language model through Foundation Models.
- `swift/Sources/CoreAILanguageModels/LanguageModel/CoreAILanguageModel.swift`
  defines `CoreAILanguageModel(resourcesAt:)` and conforms the type to
  Foundation Models `LanguageModel`.
- The exported `qwen3_4b_4bit_dynamic` tokenizer includes `<tool_call>` and
  `<tool_response>` tokens and a `chat_template.jinja` branch for `tools`.

The session is created with a static Apple `Tool` for each Tessera MCP tool
registered in `/Users/michael/src/tessera/server/src/server.rs`. The tool names
match Tessera's MCP names, and each Apple tool forwards exactly one MCP
`tools/call` request to Tessera.

The production path intentionally does not call MCP `tools/list`; the catalog is
copied from source for this Phase 1 step.

## Tessera MCP Bridge

`FMRagCore` owns:

- the static Tessera tool catalog;
- generic JSON request/response values;
- the narrow Streamable HTTP MCP client for `http://127.0.0.1:3000/mcp`;
- compact tool-output formatting;
- observed tool-call trace state;
- prompt instructions for model-directed tool selection.

The MCP client performs:

1. `initialize` over `POST /mcp` with `Accept: application/json, text/event-stream`;
2. `notifications/initialized` with the returned `mcp-session-id`;
3. one `tools/call` request per model-selected Apple tool call.

Tool output is returned to the model as compact plain text that preserves
follow-up IDs such as `table_id`, `chunk_id`, rule numbers, source names, and
module names when Tessera returns them.

Foundation Models may emit Apple Biome instrumentation messages when run under
Xcode's debugger. Those messages are outside the app's logging surface and do
not change the current architecture boundary.

## Targets

- `FMRagCLI` owns process exit behavior, model-provider selection, Foundation Models availability checks, Core AI model bundle loading, session creation, and live model calls.
- `FMRagCore` owns deterministic CLI helpers, the static Tessera tool catalog, MCP transport, tool formatting, and prompt assembly.
- `FMRagCoreTests` tests argument parsing, output formatting, static catalog coverage, MCP request encoding, response decoding, allowed-tool validation, and trace formatting without calling the live model or live Tessera.
