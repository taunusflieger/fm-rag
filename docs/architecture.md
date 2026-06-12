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
instructions as the default Foundation Models path. The CLI currently wraps the
Core AI model in a narrow capability bridge because the exported Qwen3 tokenizer
has tool-call template support, while the local Core AI adapter does not
advertise `.toolCalling` through Foundation Models.

Live acceptance with the exported `qwen3-4b` bundle is still blocked. Without
the bridge, Foundation Models reports:

```text
The selected model does not support tool calling. Consider trying again with a different model.
```

With the capability bridge, the session is accepted but ends before any Tessera
tool trace:

```text
Session ended without producing a response.
```

The remaining architectural gap is that the Core AI executor only routes
generated text and reasoning events today. It must parse generated Qwen3
`<tool_call>` blocks and emit Foundation Models `toolCalls(...)` channel events
before `LanguageModelSession` can execute the registered Tessera tools.
This is tracked upstream as
[`apple/coreai-models#28`](https://github.com/apple/coreai-models/issues/28).

The CLI must not compensate for that model capability gap by hardcoding
retrieval, bypassing the Tessera MCP client, or hiding retrieval orchestration
outside model-selected tool calls.

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
