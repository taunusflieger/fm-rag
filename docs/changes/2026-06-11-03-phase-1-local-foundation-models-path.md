# 2026-06-11-03: Phase 1 Local Foundation Models Path

**Status:** Implemented

**Created:** 2026-06-11

## Goal

Prove that the Phase 1 CLI can create a local Apple Foundation Models session and receive a basic text response from the on-device system language model.

Success means a supported macOS 26 machine can run one CLI command, the program checks Foundation Models availability, creates a `LanguageModelSession`, sends the user's question to the model, and prints a non-empty model answer.

This change intentionally proves only the local model path. It does not add MCP, retrieval, tool calling, or grounded answers.

## Scope

Implement:

- Official Apple documentation evidence for every Foundation Models API used by this change.
- A minimal Foundation Models response path using the default system language model.
- Availability handling before session creation.
- CLI output that keeps the existing question echo and adds a model answer.
- Focused deterministic tests for local formatting or availability-message mapping if that logic is placed in `FMRagCore`.
- README or runbook updates that show the basic local-model run path and the expected unsupported-machine behavior.
- Architecture documentation for the new CLI-to-Foundation-Models boundary.

Allowed paths:

- `Sources/FMRagCLI/main.swift`
- `Sources/FMRagCore/`
- `Tests/FMRagCoreTests/`
- `README.md`
- `docs/architecture.md`
- `implementation_plan.md`

## Non-Goals

Do not implement:

- Foundation Models `Tool` conformance.
- `@Generable` argument or response types.
- MCP client code.
- RAG server calls.
- Retrieval result formatting.
- Prompt assembly for retrieved context.
- Source attribution.
- Configuration files or runtime provider selection.
- Generic model-provider abstractions.
- Retry, caching, persistence, telemetry, or streaming.
- A GUI, REPL, Xcode project, or Xcode workspace.

## Required Preflight

Run these commands from the repository root before editing product files:

```sh
swift --version
xcrun --show-sdk-path
swift build
swift test
swift run fm-rag "test question"
```

Record the outputs in the implementation notes or final report. The existing CLI run must still print:

```text
Question: test question
```

If `swift --version` or `xcrun --show-sdk-path` does not show a toolchain and SDK that support macOS 26 and Foundation Models, stop and report the blocker. Do not add compatibility shims for older SDKs.

## Official API Evidence Gate

Before writing any Foundation Models integration code, open and record the current official Apple documentation for each symbol used.

Required Apple documentation pages:

- `Foundation Models`
  - `https://developer.apple.com/documentation/foundationmodels`
- `SystemLanguageModel`
  - `https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel`
- `SystemLanguageModel.default`
  - `https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/default`
- `SystemLanguageModel.availability`
  - `https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.property`
- `SystemLanguageModel.Availability`
  - `https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum`
- `LanguageModelSession`
  - `https://developer.apple.com/documentation/foundationmodels/languagemodelsession`
- `LanguageModelSession.init(model:tools:instructions:)`
  - `https://developer.apple.com/documentation/foundationmodels/languagemodelsession/init(model:tools:instructions:)`
- `LanguageModelSession.respond(to:options:)`
  - `https://developer.apple.com/documentation/foundationmodels/languagemodelsession/respond(to:options:)`
- `LanguageModelSession.Response`
  - `https://developer.apple.com/documentation/foundationmodels/languagemodelsession/response`
- `LanguageModelSession.Response.content`
  - `https://developer.apple.com/documentation/foundationmodels/languagemodelsession/response/content`

The implementation may use the Apple documentation JSON endpoints as a diagnostic aid, for example:

```sh
curl --max-time 20 -L https://developer.apple.com/tutorials/data/documentation/foundationmodels/languagemodelsession/respond(to:options:).json
```

Documentation evidence required for this change:

- `SystemLanguageModel.default` is the selected model.
- `SystemLanguageModel.availability` or `isAvailable` is checked before session creation.
- `LanguageModelSession` can be initialized with the selected model, no tools, and optional instructions.
- `respond(to:options:)` can produce a string response.
- `Response.content` is the value printed as the model answer.

If official Apple documentation does not clearly support one of those API shapes, stop and report the evidence gap. Do not substitute SDK symbol discovery, generated interfaces, compilation success, memory, or unofficial examples for the missing official documentation.

## Design

Keep the command shape unchanged:

```sh
swift run fm-rag "Answer in one short sentence: what is 2 + 2?"
```

Expected successful output shape:

```text
Question: Answer in one short sentence: what is 2 + 2?
Foundation Models: available
Answer: <non-empty model response>
```

If Foundation Models is unavailable, print a clear message and exit nonzero before creating a session:

```text
Question: Answer in one short sentence: what is 2 + 2?
Foundation Models: unavailable (<availability reason>)
```

The exact availability reason should be derived from the documented `SystemLanguageModel.Availability` cases available in the selected SDK. Keep the mapping small and deterministic. A fallback string for unknown future cases is acceptable only if required by Swift exhaustiveness.

Use the smallest session setup that the official documentation supports. Prefer:

- `SystemLanguageModel.default`
- `LanguageModelSession(model: model, tools: [], instructions: <short string or nil>)`
- `try await session.respond(to: question)`
- `response.content`

Instructions, if used, must be limited to basic answer behavior, for example asking for a concise response. Do not add retrieval-grounding instructions in this change, because retrieval is not implemented yet.

## Implementation Steps

1. Complete the preflight and evidence gates.
   - Run the required preflight commands.
   - Open the required Apple documentation pages.
   - Record the exact toolchain, SDK path, and documentation symbols used.
   - Verify: no product files are edited until the gate is complete.

2. Add the minimal Foundation Models response path.
   - Import `FoundationModels` only in the file or files that directly create the model/session.
   - Check model availability before session creation.
   - Create one `LanguageModelSession` with no tools.
   - Send the CLI question to the session and capture `response.content`.
   - Verify: `swift build` succeeds.

3. Update CLI output and exit behavior.
   - Preserve the existing argument validation behavior.
   - Preserve the first output line as `Question: <question>`.
   - Print `Foundation Models: available` before the answer on supported machines.
   - Print `Foundation Models: unavailable (<availability reason>)` and exit nonzero when the model is unavailable.
   - Print Foundation Models generation errors to stderr and exit nonzero.
   - Verify: invalid argument counts still print usage and exit nonzero.

4. Add focused deterministic tests where possible.
   - Keep live model calls out of unit tests.
   - Test only pure mapping or formatting logic introduced by this change.
   - Do not assert the model's natural-language output text in unit tests.
   - Verify: `swift test` succeeds.

5. Update docs and status.
   - Update `README.md` with the new local-model run path and unsupported-machine behavior.
   - Create or update `docs/architecture.md` with the Phase 1 Step 2 boundary: CLI -> Foundation Models session, no MCP yet.
   - Update `implementation_plan.md` to `Implemented` only after all required verification and manual acceptance pass.
   - Verify: documentation matches actual command output.

## Verification

Required commands from the repository root:

```sh
swift build
swift test
swift run fm-rag "Answer in one short sentence: what is 2 + 2?"
```

Manual acceptance on a supported macOS 26 machine with Apple Intelligence enabled:

- The CLI prints the question.
- The CLI prints `Foundation Models: available`.
- The CLI prints `Answer:`.
- The answer is non-empty.
- The process exits with status 0.

Manual unsupported-machine acceptance, if the model is unavailable on the current machine:

- The CLI prints the question.
- The CLI prints `Foundation Models: unavailable (<availability reason>)`.
- The process exits nonzero.
- The implementation report states that live model acceptance remains blocked by local machine availability.

## Acceptance Criteria

- Required preflight outputs are recorded.
- Every Foundation Models symbol used by the implementation is backed by an official Apple documentation reference in the implementation report, README, or change notes.
- `swift build` succeeds.
- `swift test` succeeds.
- `swift run fm-rag "Answer in one short sentence: what is 2 + 2?"` reaches the Foundation Models path on a supported machine.
- Successful CLI output includes the original question, model availability, and a non-empty answer.
- Unavailable model output is explicit and exits nonzero.
- Invalid argument handling remains unchanged.
- No Foundation Models `Tool`, MCP, RAG, retrieval, source-attribution, provider-selection, or generic abstraction code is added.
- `docs/architecture.md` reflects that Step 2 has only a direct local Foundation Models session path.
- No `.xcodeproj`, `.xcworkspace`, `.build/`, `.swiftpm/`, `runtime/`, or derived data is committed.
- `implementation_plan.md` marks this change as `Implemented` only after all required verification passes.

## Known Failure Signatures

- `no such module 'FoundationModels'`
  - Indicates the active SDK or toolchain does not expose the framework. Stop and fix the selected Xcode command-line tools or `DEVELOPER_DIR`; do not stub the framework.
- `cannot find 'LanguageModelSession' in scope`
  - Indicates the implementation is not grounded against the selected SDK or the import/API shape is wrong. Re-open the official Apple documentation for the selected symbol before editing again.
- `cannot convert value of type ... to expected argument type ...` for session initialization or response calls
  - Indicates an API-shape mismatch. Stop after the first such failure and inspect the official documentation page for the exact overload.
- Foundation Models availability reports device not eligible, Apple Intelligence disabled, or model not ready.
  - This is an environment blocker for live acceptance, not a code defect. Report the exact availability case and do not add fallback providers.
- The model returns sensitive-content or generation errors for the smoke prompt.
  - Change the smoke prompt to a neutral basic prompt only after recording the exact error. Do not add retry loops.
- `swift test` starts a live model call.
  - The test boundary is wrong. Unit tests must cover only deterministic formatting or mapping logic for this change.

## Wrong Fixes To Avoid

- Do not use unofficial examples, memory, generated SDK interfaces, or compilation success as the only Foundation Models evidence.
- Do not add MCP client code early.
- Do not implement `Tool`, `@Generable`, `@Guide`, or structured output in this change.
- Do not add a provider protocol or mock model abstraction. Put deterministic formatting or mapping logic behind small pure functions instead.
- Do not add command-line flags for model selection, availability bypass, or configuration.
- Do not hide Foundation Models unavailability behind a fake answer.
- Do not broaden the CLI into an interactive app.
- Do not mark the change implemented because `swift build` passes if the live run or explicit unavailable-machine behavior has not been checked.
