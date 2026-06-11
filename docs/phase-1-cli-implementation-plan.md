# Phase 1 CLI Implementation Plan

## Goal

Build a command-line proof of concept that answers the project question:

Can Apple Foundation Models use tool calling to augment local generation with authoritative knowledge retrieved from an existing RAG server exposed through MCP?

Phase 1 succeeds when a user can run one CLI command, ask a domain question, observe the Foundation Model invoke one retrieval tool backed by the existing MCP RAG server, and receive an answer that is grounded in the retrieved context.

## Scope

Phase 1 includes:

- A Swift Package Manager command-line executable.
- A package root that opens cleanly in Xcode and exposes the CLI target there.
- Integration with Apple Foundation Models through `LanguageModelSession`.
- One Foundation Models `Tool` implementation for retrieval.
- A narrow MCP client path for the existing RAG server.
- A minimal request and response mapping between the tool and the MCP server.
- CLI output that shows the final answer and enough retrieval trace to verify that retrieval happened.
- Focused tests for request mapping, response parsing, and prompt assembly where those pieces can be tested without the live Foundation Model.

Phase 1 does not include:

- A macOS GUI.
- A generic MCP client framework.
- Multiple MCP servers.
- Multiple retrieval providers.
- Runtime provider selection.
- Configuration files or plugin discovery.
- Production-grade authentication, retries, caching, persistence, or telemetry.
- Full source attribution UX.
- MCP compatibility beyond the one existing server.
- Benchmarking or evaluation suites.

## Assumptions

- The target platform is macOS 26 or newer on Apple silicon with Apple Intelligence enabled.
- The project uses Swift Package Manager. The repository root must be openable
  in Xcode as a Swift package; Phase 1 does not create a separate `.xcodeproj`
  unless SwiftPM package opening is proven insufficient.
- Every Foundation Models API usage requires clear evidence from official Apple
  documentation before design or implementation. Installed SDK symbols,
  generated interfaces, successful compilation, memory, or unofficial examples
  are not sufficient by themselves. If official Apple documentation does not
  clearly support the intended Foundation Models API shape or behavior, Phase 1
  must stop and report the evidence gap.
- The existing RAG server already exposes an MCP interface and is available during manual acceptance testing.
- Phase 1 may bind directly to the known MCP server shape. Server tool names, request fields, and response fields can be hard-coded once verified from that server.
- If the MCP server requires a launch command, URL, token, or local socket path, Phase 1 records that value in the approved change document or in a small local-only runtime instruction. It does not build a reusable configuration system.
- Retrieval quality is evaluated with a small known question set, not a benchmark suite.

## Architecture

```text
CLI input
  -> Phase1Command
  -> LanguageModelSession
  -> RetrievalTool
  -> NarrowMCPRagClient
  -> Existing MCP RAG server
  -> Retrieved context
  -> Foundation Model final answer
  -> CLI output
```

## Components

### Swift Package

Create a Swift package with one executable target and one library target if shared code needs focused tests. The package manifest should be compatible with Xcode package opening so a developer can open the repository root in Xcode, select the CLI scheme, and build it.

Expected structure:

```text
Package.swift
Sources/
  FMRagCLI/
    main.swift
  FMRagCore/
    RetrievalTool.swift
    NarrowMCPRagClient.swift
    PromptAssembly.swift
Tests/
  FMRagCoreTests/
```

Keep the structure smaller if the first implementation does not need a library boundary.

### Xcode Build

The project must remain usable from Xcode even though Phase 1 is CLI-first.

Required behavior:

- Opening the repository root in Xcode loads the Swift package.
- Xcode shows the CLI executable target.
- Building the CLI scheme in Xcode succeeds on a supported macOS 26 machine.
- Generated Xcode state, derived data, and user-specific files are not committed.

Do not add a hand-maintained Xcode project in Phase 1 unless opening the Swift package directly in Xcode cannot satisfy these requirements.

### CLI

The CLI accepts one user question and prints:

- The question.
- A compact retrieval trace showing that the MCP-backed tool ran.
- The final Foundation Model answer.

Initial command shape:

```sh
swift run fm-rag "question text"
```

No interactive shell is required for Phase 1.

### Foundation Models Session

Create one `LanguageModelSession` only after the required Foundation Models
symbols and behavior are grounded in official Apple documentation. At minimum,
the implementation must cite official documentation for session creation, tool
registration, tool argument/output requirements, generation calls, availability
checks, and any tool-calling options used.

The session should use:

- Instructions that tell the model to use the retrieval tool for domain-specific or current knowledge.
- Exactly one registered retrieval tool.
- Generation options only when required by the installed SDK and verified API surface.

The implementation should prefer the smallest working session setup. If forcing tool use is supported by the selected SDK, use it for the acceptance scenario when the question must be answered from retrieval. If forcing tool use is not available on the Phase 1 deployment target, use instructions and a retrieval-dependent test question instead.

### Retrieval Tool

Implement one `Tool` named for the concrete retrieval action, for example `searchKnowledgeBase`. Do this only after official Apple documentation supports the required `Tool` conformance shape, argument type constraints, output type constraints, and call behavior.

The tool accepts a small `@Generable` argument type:

```swift
struct Arguments {
    let query: String
}
```

Add fields only when the existing MCP server requires them. Do not add filters, top-k controls, provider names, namespaces, or source-group selection unless the selected server requires those exact fields for a successful request.

The tool returns a compact text representation of retrieved context that the model can use in its final answer.

### MCP RAG Client

Implement the narrowest MCP path needed for the existing server.

Required discovery before code:

1. Identify how the server is reached for Phase 1: stdio process, HTTP endpoint, local socket, or another already-known transport.
2. Identify the exact MCP method or tool call used for retrieval.
3. Capture one known-good request and response example from the existing server.
4. Map only the fields needed for the Phase 1 retrieval question.

Do not build:

- Generic MCP capability discovery.
- Dynamic tool registration from MCP metadata.
- Transport abstraction layers.
- Provider-independent schemas.

### Prompt And Answer Grounding

The session instructions should require:

- Use retrieved context for domain-specific facts.
- If retrieved context is empty or insufficient, say that the available retrieved context does not answer the question.
- Do not invent citations or facts that are not present in the retrieved context.

Phase 1 does not need polished citations, but the answer must visibly depend on retrieved content.

## Implementation Steps

1. Establish the Swift package and CLI shell.
   - Create the SwiftPM package, CLI target, optional shared library target, and minimal argument handling.
   - Verify: `swift build` succeeds, `swift run fm-rag "test question"` reaches the CLI entry point, and the repository root opens in Xcode with the CLI target visible.

2. Prove the local Foundation Models path.
   - Ground every Foundation Models API usage against official Apple documentation, record the supporting documentation links or symbol pages, add the minimal `LanguageModelSession` path, and confirm the CLI can get a basic response on a supported machine.
   - Verify: official documentation evidence is recorded, toolchain checks are recorded, and a basic model response works before MCP integration is added.

3. Wire the existing MCP RAG server through one retrieval tool.
   - Inspect the server contract, capture one known-good request and response, implement the narrow MCP client, implement the Foundation Models `Tool` using only officially documented API shapes, and register it with the session.
   - Verify: deterministic tests cover request encoding, response decoding, and tool formatting; a known domain question triggers the retrieval tool.

4. Close the Phase 1 acceptance loop.
   - Add the documented run path, expected output shape, and known environment requirements.
   - Verify: `swift build`, `swift test`, Xcode build, and the live acceptance question all pass, with CLI output showing retrieval and a grounded final answer.

## Test Strategy

Automated tests should cover deterministic code:

- CLI argument validation.
- MCP request encoding.
- MCP response decoding.
- Retrieval result formatting.
- Prompt or instruction assembly.
- Tool behavior with a fake MCP client.

Manual acceptance covers live model and server behavior:

- Apple Intelligence availability.
- Foundation Models session creation.
- Real tool invocation.
- Real retrieval from the existing MCP server.
- Final answer grounded in retrieved context.

Do not try to unit test the Foundation Model's reasoning quality in Phase 1.

## Acceptance Criteria

Phase 1 is complete when all of the following are true:

- `swift build` succeeds from the repository root.
- `swift test` succeeds from the repository root.
- The repository root opens in Xcode as a Swift package.
- The CLI target builds from Xcode on a supported macOS 26 machine.
- Every Foundation Models API usage in the implementation is backed by a clear
  official Apple documentation reference recorded in the Phase 1 runbook or
  change notes.
- The existing MCP RAG server can be reached through the Phase 1 client path.
- Running `swift run fm-rag "KNOWN_QUESTION"` calls the retrieval tool.
- CLI output includes a compact retrieval trace.
- The final answer uses facts from retrieved context.
- A question with no useful retrieved context does not produce unsupported factual claims.
- The implementation has no generic provider abstraction, no dynamic MCP discovery, and no multi-server configuration surface.

## Main Risks

- Foundation Models tool-calling API details may differ across macOS 26 SDK point releases. Mitigation: verify against the installed SDK before implementation.
- Official Apple documentation may not clearly describe an API shape or behavior
  needed for the intended implementation. Mitigation: stop and report the
  evidence gap; do not design or implement Foundation Models code by inference.
- The MCP server contract may not expose retrieval in a shape suitable for direct model context. Mitigation: capture one known-good request and response before writing integration code.
- The model may decide not to call a tool for some prompts. Mitigation: use a retrieval-dependent acceptance question and, if supported by the selected SDK, set tool calling mode to required for the acceptance run.
- Retrieved context may be too verbose for the local model context window. Mitigation: format only the top relevant snippets required by the known Phase 1 question.

## Phase 1 Exit Decision

After Phase 1, the PoC question is answered positively if the CLI demonstrates that:

- Foundation Models can invoke app-defined Swift tool code.
- That tool can call the existing MCP RAG server.
- Retrieved knowledge can change the final model answer in a grounded way.

If any of those three points fails, Phase 1 should stop and document the blocker before planning Phase 2.
