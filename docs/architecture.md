# Architecture

This document records the current technical architecture for the Phase 1 command-line proof of concept.

## Current Boundary

The current implementation proves the local Foundation Models path only:

```text
CLI argument
  -> FMRagCLI
  -> SystemLanguageModel.default availability check
  -> LanguageModelSession
  -> local model response
  -> CLI output
```

The CLI preserves the original question line, reports Foundation Models availability, and prints the generated answer when the model is available.

If `SystemLanguageModel.default.availability` is unavailable, the CLI prints the documented unavailable reason and exits nonzero before creating a `LanguageModelSession`.

The CLI flushes stdout after the question and availability lines so framework
stderr output from Foundation Models does not reorder the user-visible status
lines in Xcode or other consoles.

## Foundation Models API Use

The implementation uses only the official Apple-documented symbols needed for the direct local model path:

- `SystemLanguageModel.default`
- `SystemLanguageModel.availability`
- `SystemLanguageModel.Availability.available`
- `SystemLanguageModel.Availability.unavailable(_:)`
- `SystemLanguageModel.Availability.UnavailableReason`
- `LanguageModelSession.init(model:tools:instructions:)`
- `LanguageModelSession.respond(to:options:)`
- `LanguageModelSession.Response.content`

The session is created with no tools. Tool calling, MCP, RAG client code, retrieval formatting, and grounded answer behavior are outside the current implementation boundary.

Foundation Models may emit Apple Biome instrumentation messages when run under
Xcode's debugger. Those messages are outside the app's logging surface and do
not change the current architecture boundary.

## Targets

- `FMRagCLI` owns process exit behavior, Foundation Models availability checks, session creation, and live model calls.
- `FMRagCore` owns deterministic CLI helpers that can be tested without calling the live model.
- `FMRagCoreTests` tests argument parsing and pure output formatting only.

## Planned Next Boundary

The next Phase 1 implementation step is expected to add one MCP-backed retrieval tool. That future change should keep the current direct local model path intact and introduce retrieval only through the approved Foundation Models `Tool` API shape.
