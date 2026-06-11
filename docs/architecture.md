# Architecture

This document records the current technical architecture for the Phase 1 command-line proof of concept.

## Current Boundary

The current implementation proves the local Foundation Models path with a
static Tessera MCP tool bridge:

```text
CLI argument
  -> FMRagCLI
  -> SystemLanguageModel.default availability check
  -> LanguageModelSession with static Tessera tools
  -> model-selected tool calls
  -> Tessera MCP Streamable HTTP endpoint
  -> local model response grounded in tool output
  -> CLI output
```

The CLI preserves the original question line, reports Foundation Models availability, prints observed Tessera tool-call trace lines, and prints the generated answer when the model is available.

If `SystemLanguageModel.default.availability` is unavailable, the CLI prints the documented unavailable reason and exits nonzero before creating a `LanguageModelSession`.

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

- `FMRagCLI` owns process exit behavior, Foundation Models availability checks, session creation, and live model calls.
- `FMRagCore` owns deterministic CLI helpers, the static Tessera tool catalog, MCP transport, tool formatting, and prompt assembly.
- `FMRagCoreTests` tests argument parsing, output formatting, static catalog coverage, MCP request encoding, response decoding, allowed-tool validation, and trace formatting without calling the live model or live Tessera.
