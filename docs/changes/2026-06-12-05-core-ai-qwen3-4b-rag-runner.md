# 2026-06-12-05: Core AI Qwen3 4B RAG Runner

**Status:** Approved

**Created:** 2026-06-12

## Goal

Add a Core AI language-model path for the Phase 1 RAG CLI using the already
supported `qwen3-4b` model from the adjacent `coreai-models` checkout.

Success means the same static Tessera MCP tool bridge can be exercised with a
local Core AI `qwen3-4b` bundle instead of `SystemLanguageModel.default`, so RAG
validation is no longer blocked by the observed Apple system-model 4096-token
context limit.

This change is for RAG model suitability testing. It must not attempt to port
`Qwen/Qwen3.6-35B-A3B` to Core AI.

## Source Repositories

Use these local repositories:

```text
/Users/michael/src/fm-rag
/Users/michael/src/coreai-models
/Users/michael/src/tessera
```

Use the Core AI model already supported by `coreai-models`:

```text
qwen3-4b
Qwen/Qwen3-4B
macOS
4bit
```

The expected exported bundle directory is:

```text
/Users/michael/src/coreai-models/exports/qwen3_4b_4bit_dynamic
```

If the local `coreai-models` registry or README no longer resolves this output
name, stop and update this change document before implementation. Do not switch
to an unregistered model.

## Scope

Implement:

- A CLI-selectable Core AI model path that loads a local exported model bundle.
- SwiftPM integration with the local `../coreai-models` package.
- Use of `CoreAILanguageModel(resourcesAt:)` from `CoreAILanguageModels`.
- Reuse of the existing Tessera static tool catalog, MCP client, trace output,
  and prompt instructions.
- CLI output that clearly identifies the selected model provider and model path.
- Deterministic tests for CLI argument parsing, model-path validation, provider
  selection, and output formatting.
- README and `docs/architecture.md` updates describing the Core AI RAG run path.
- Implementation-plan status maintenance.

Allowed paths:

- `Package.swift`
- `Sources/FMRagCLI/main.swift`
- `Sources/FMRagCore/`
- `Tests/FMRagCoreTests/`
- `README.md`
- `docs/architecture.md`
- `docs/changes/2026-06-12-05-core-ai-qwen3-4b-rag-runner.md`
- `implementation_plan.md`

## Non-Goals

Do not implement:

- Any `Qwen/Qwen3.6-35B-A3B` Core AI export, registry entry, model class, or
  compatibility shim.
- MLX integration.
- A generic multi-provider framework beyond the two concrete choices needed now:
  default Apple system model and local Core AI bundle.
- Dynamic model downloads from the CLI.
- Runtime model export from `fm-rag`.
- Dynamic MCP tool discovery.
- Different Tessera tools, hidden retrieval orchestration, answer hardcoding, or
  domain-specific Swift retrieval heuristics.
- A GUI, REPL, Xcode project, telemetry, caching, retry policy, or persistence.

## Required Preflight

Run these commands from `/Users/michael/src/fm-rag` before editing product files:

```sh
swift --version
xcrun --show-sdk-path
swift build
swift test
```

Run these commands from `/Users/michael/src/coreai-models` before editing product
files:

```sh
uv run coreai.model.registry --model-info qwen3-4b --type llm --platform macOS --as-export-args
uv run coreai.llm.export qwen3-4b --platform macOS --dry-run
```

If the dry run does not resolve to `Qwen/Qwen3-4B`, platform `macOS`,
compression `4bit`, and output directory under `exports/`, stop and report the
registry mismatch.

If the exported bundle is absent, create it from `/Users/michael/src/coreai-models`:

```sh
uv run coreai.llm.export qwen3-4b --platform macOS
```

Then verify the exported bundle with the Core AI reference runner:

```sh
swift run -c release llm-runner \
  --model /Users/michael/src/coreai-models/exports/qwen3_4b_4bit_dynamic \
  --prompt "Answer in one short sentence: what is 2 + 2?"
```

If export or runner validation fails, stop and report the Core AI blocker. Do
not edit `fm-rag` to compensate for a broken or missing model asset.

## Core AI API Evidence Gate

Before writing Core AI integration code, verify the local `coreai-models` API
surface from source and record the exact files inspected.

Required evidence:

- `/Users/michael/src/coreai-models/Package.swift`
  - product `CoreAILM`
  - target/module `CoreAILanguageModels`
  - platform requirement `macOS("27.0")`
- `/Users/michael/src/coreai-models/models/qwen3/README.md`
  - `qwen3-4b` is supported on macOS
  - export and runner commands for Qwen3 models
- `/Users/michael/src/coreai-models/swift/Sources/CoreAILanguageModels/LanguageModel/CoreAILanguageModel.swift`
  - `CoreAILanguageModel(resourcesAt:)`
  - conformance to Foundation Models `LanguageModel`

The implementation may also inspect the local `llm-runner` source for a
source-backed loading pattern. Do not invent Core AI or `CoreAILanguageModels`
symbols from memory.

## Design

Keep the existing default behavior when no Core AI model path is provided:

```sh
swift run fm-rag "Welcher Mindestimpuls ist für 9 mm Luger vorgeschrieben?"
```

That command continues to use `SystemLanguageModel.default`.

Add an explicit Core AI run path:

```sh
swift run fm-rag \
  --coreai-model /Users/michael/src/coreai-models/exports/qwen3_4b_4bit_dynamic \
  "Welcher Mindestimpuls ist für 9 mm Luger vorgeschrieben?"
```

Expected output shape:

```text
Question: Welcher Mindestimpuls ist für 9 mm Luger vorgeschrieben?
Model: Core AI qwen3-4b
Model path: /Users/michael/src/coreai-models/exports/qwen3_4b_4bit_dynamic
Tool: <tessera-tool-name> arguments=<compact-json>
Answer: <grounded model response>
```

The Core AI path should:

- validate that the `--coreai-model` path exists and is a directory before
  creating a session;
- load `CoreAILanguageModel(resourcesAt: modelURL)`;
- create `LanguageModelSession(model: coreAIModel, tools: tools,
  instructions: TesseraPromptAssembly.instructions)`;
- call `respond(to:)` exactly like the current Foundation Models path;
- print observed Tessera tool-call traces from app state, not inferred answer
  text.

The default Foundation Models path should keep its existing availability check
and output.

## Swift Package Change

Add a local package dependency to `Package.swift`:

```swift
.package(path: "../coreai-models")
```

Add the package product to `FMRagCLI`:

```swift
.product(name: "CoreAILM", package: "coreai-models")
```

Update the package platform to match the dependency if required by SwiftPM:

```swift
.macOS("27.0")
```

Do not add remote Git dependencies for `coreai-models` in this change. The goal
is to test against the adjacent local checkout and its exported local model
bundle.

## Tessera Runtime

Use the same DSB Tessera runtime as the existing static tool bridge:

```sh
cd /Users/michael/src/tessera
cargo make up-dsb
```

The Core AI path must not change Tessera endpoint selection, tool names,
argument schema, evidence formatting, or prompt instructions unless a compile
error proves the existing code cannot be reused. If reuse fails, document the
specific type or API mismatch before making the smallest necessary change.

## Implementation Steps

1. Complete preflight and API evidence gates.
   - Verify Swift build/test before edits.
   - Verify the `qwen3-4b` Core AI registry dry run.
   - Verify the exported bundle with `llm-runner`.
   - Verify local `CoreAILanguageModel(resourcesAt:)` source.
   - Verify: no product files are edited until these gates complete.

2. Add CLI argument parsing for `--coreai-model`.
   - Preserve the existing one-question positional argument.
   - Accept either no option or exactly one `--coreai-model <path>` option.
   - Reject missing model path, unknown flags, duplicate options, and missing
     question with deterministic errors.
   - Verify: focused `CLIArguments` tests cover old and new forms.

3. Add the local Core AI dependency.
   - Update `Package.swift` with the local package dependency and product.
   - Bump the macOS platform only if SwiftPM requires it.
   - Import `CoreAILanguageModels` only where the Core AI model is loaded.
   - Verify: `swift build` succeeds.

4. Add the Core AI session path.
   - Split the current `answer(_:)` flow only as much as needed to choose the
     concrete model.
   - Keep Tessera tool construction shared between both paths.
   - Keep live model calls out of unit tests.
   - Verify: `swift test` succeeds.

5. Add output and docs.
   - Print the selected model provider before tool traces.
   - Update README with the export prerequisite and Core AI RAG command.
   - Update `docs/architecture.md` to show the alternate model path.
   - Verify: docs match actual command spelling.

6. Run live acceptance.
   - Start Tessera DSB runtime.
   - Run the Core AI acceptance command.
   - Confirm the model calls at least one Tessera tool.
   - Confirm the answer is grounded in retrieved evidence.
   - Mark this change `Implemented` only after required verification passes.

## Verification

Required commands from `/Users/michael/src/fm-rag`:

```sh
swift build
swift test
swift run fm-rag \
  --coreai-model /Users/michael/src/coreai-models/exports/qwen3_4b_4bit_dynamic \
  "Welcher Mindestimpuls ist für 9 mm Luger vorgeschrieben?"
```

Required commands from `/Users/michael/src/coreai-models`:

```sh
uv run coreai.llm.export qwen3-4b --platform macOS --dry-run
swift run -c release llm-runner \
  --model /Users/michael/src/coreai-models/exports/qwen3_4b_4bit_dynamic \
  --prompt "Answer in one short sentence: what is 2 + 2?"
```

Required Tessera runtime command from `/Users/michael/src/tessera` in a separate
terminal:

```sh
cargo make up-dsb
```

Manual acceptance:

- The CLI validates the Core AI model bundle path before session creation.
- The CLI prints the original question.
- The CLI prints `Model: Core AI qwen3-4b`.
- The model calls at least one Tessera tool.
- CLI output includes observed tool-call trace lines.
- The final answer is non-empty and grounded in retrieved Tessera evidence.
- For the 9 mm Luger acceptance question, the final answer includes the
  retrieved Mindestimpuls value `250` if the tool output contains that evidence.
- The default Foundation Models command still works or reports documented
  unavailability as before.

## Acceptance Criteria

- Preflight outputs are recorded.
- Core AI source evidence is recorded from the local `coreai-models` checkout.
- `qwen3-4b` dry-run registry resolution is recorded.
- The exported bundle exists at the documented path or the implementation report
  records the export command that created it.
- `llm-runner` can generate from the documented qwen3-4b bundle.
- `swift build` succeeds in `fm-rag`.
- `swift test` succeeds in `fm-rag`.
- Existing Foundation Models default behavior is preserved.
- Core AI path uses `CoreAILanguageModel(resourcesAt:)`.
- Unit tests do not call live Core AI, live Foundation Models, or live Tessera.
- Live Core AI RAG acceptance prints model identity, tool trace, and answer.
- No Qwen3.6, MLX, dynamic MCP discovery, hidden retrieval orchestration,
  hardcoded answer, generic provider framework, or model download feature is
  added.
- `docs/architecture.md` reflects that RAG can now be tested with a local Core
  AI `qwen3-4b` model bundle.
- `implementation_plan.md` marks this change as `Implemented` only after all
  required verification passes.

## Implementation Attempt Evidence

2026-06-12 implementation attempt:

- `swift --version` from `/Users/michael/src/fm-rag`:
  - `swift-driver version: 1.167 Apple Swift version 6.4`
  - target `arm64-apple-macosx27.0.0`
- `xcrun --show-sdk-path`:
  - `/Applications/Xcode-beta.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk`
- Pre-edit `swift build` from `/Users/michael/src/fm-rag` succeeded.
- Pre-edit `swift test` from `/Users/michael/src/fm-rag` succeeded with 13
  tests.
- `uv run coreai.model.registry --model-info qwen3-4b --type llm --platform macOS --as-export-args`
  from `/Users/michael/src/coreai-models` resolved:
  - `Qwen/Qwen3-4B --compression 4bit --compute-precision float16 --max-context-length 40960`
- `uv run coreai.llm.export qwen3-4b --platform macOS --dry-run` resolved:
  - model `Qwen/Qwen3-4B`
  - platform `macOS`
  - compression `4bit`
  - output directory `/Users/michael/src/coreai-models/exports`
- The expected bundle was absent and was created with
  `uv run coreai.llm.export qwen3-4b --platform macOS`.
- `swift run -c release llm-runner --model /Users/michael/src/coreai-models/exports/qwen3_4b_4bit_dynamic --prompt "Answer in one short sentence: what is 2 + 2?"`
  succeeded and generated output from the exported bundle.

Core AI source evidence inspected:

- `/Users/michael/src/coreai-models/Package.swift`
  - product `CoreAILM`
  - target/module `CoreAILanguageModels`
  - platform `.macOS("27.0")`
- `/Users/michael/src/coreai-models/models/qwen3/README.md`
  - Qwen3 4B is supported on macOS
  - export and runner commands are documented
  - README shows `CoreAILanguageModel(resourcesAt:)` with
    `LanguageModelSession(model:)`
- `/Users/michael/src/coreai-models/swift/Sources/CoreAILanguageModels/LanguageModel/CoreAILanguageModel.swift`
  - `public init(resourcesAt url: URL, ...) async throws`
  - `public struct CoreAILanguageModel: LanguageModel`
  - `capabilities` currently returns `.guidedGeneration` when
    `engine.supportsLogits` is true, otherwise no capabilities
- `/Users/michael/src/coreai-models/exports/qwen3_4b_4bit_dynamic/tokenizer/chat_template.jinja`
  - contains a `{% if tools %}` branch
  - renders tool definitions inside `<tools></tools>`
  - instructs the model to return JSON function calls inside
    `<tool_call></tool_call>`
- `/Users/michael/src/coreai-models/exports/qwen3_4b_4bit_dynamic/tokenizer/tokenizer_config.json`
  - contains `<tool_call>`, `</tool_call>`, `<tool_response>`, and
    `</tool_response>` token entries

Post-edit checks:

- `swift build` from `/Users/michael/src/fm-rag` succeeded.
- `swift test` from `/Users/michael/src/fm-rag` succeeded with 21 tests.

Live acceptance blocker:

- Tessera DSB runtime was started with `cargo make up-dsb`.
- `swift run fm-rag --coreai-model /Users/michael/src/coreai-models/exports/qwen3_4b_4bit_dynamic "Welcher Mindestimpuls ist für 9 mm Luger vorgeschrieben?"`
  reached the Core AI path and printed:
  - `Question: Welcher Mindestimpuls ist für 9 mm Luger vorgeschrieben?`
  - `Model: Core AI qwen3-4b`
  - `Model path: /Users/michael/src/coreai-models/exports/qwen3_4b_4bit_dynamic`
- The run failed before any Tessera tool call:
  - `Core AI generation failed: The selected model does not support tool calling. Consider trying again with a different model.`
- A narrow local wrapper was added in `FMRagCLI` to delegate to
  `CoreAILanguageModel` while advertising `.toolCalling` to Foundation Models.
- After that wrapper, the same live command passed the unsupported-capability
  gate but still failed before any Tessera tool trace:
  - `Core AI generation failed: Session ended without producing a response.`

Current diagnosis:

- The exported `qwen3-4b` bundle has tokenizer/template support for Qwen-style
  tool calls.
- The local Core AI Foundation Models adapter does not advertise `.toolCalling`
  from `CoreAILanguageModel.capabilities`.
- Advertising `.toolCalling` is not sufficient by itself. The Core AI executor
  currently routes generated text and reasoning events, but does not parse
  generated `<tool_call>` blocks and emit Foundation Models
  `LanguageModelExecutorGenerationChannel.toolCalls(...)` events.
- Upstream tracking issue:
  [`apple/coreai-models#28`](https://github.com/apple/coreai-models/issues/28).

This change must remain `Approved`, not `Implemented`, until the selected Core
AI language model can participate in Foundation Models tool calling or a
separate approved change defines a different architecture.

## Known Failure Signatures

- `package 'coreai-models' is using Swift tools version 6.0.0 but the installed version is ...`
  - The selected Swift toolchain is wrong. Fix `DEVELOPER_DIR` or Xcode command
    line tools; do not vendor `coreai-models`.
- `the package dependency graph can not be resolved` after adding
  `../coreai-models`
  - Inspect the exact SwiftPM resolution error. Do not switch to a remote
    dependency unless a separate change approves that.
- `product 'CoreAILM' required by package 'FMRag' target 'FMRagCLI' not found`
  - The local `coreai-models` package changed. Re-open its `Package.swift` and
    update this change before implementation.
- `no such module 'CoreAILanguageModels'`
  - The target dependency or product mapping is wrong. Check the local package
    product/target names; do not guess alternate module names.
- `Model path not found` or bundle metadata errors from `CoreAILanguageModel`
  - The qwen3-4b export is missing or invalid. Re-run the `coreai-models`
    export/runner validation; do not add fallback fake answers.
- `Content contains ... tokens, which exceeds ...`
  - Record whether this is still a model-context limitation. Do not add
    domain-specific truncation unless a separate change defines a general,
    evidence-preserving compression strategy.
- The model never calls Tessera tools for the acceptance question.
  - Preserve the prompt, model output, and registered tool evidence. Do not
    hardcode a tool call behind the model without a separate approved change.

## Wrong Fixes To Avoid

- Do not use Qwen3.6 or any unregistered Core AI model.
- Do not use MLX.
- Do not read Tessera SQLite directly.
- Do not bypass the existing Tessera MCP client.
- Do not remove the current Foundation Models path.
- Do not hide Core AI loading errors behind Foundation Models fallback.
- Do not add broad provider abstractions, configuration files, or model registry
  systems.
- Do not commit `.build/`, `.swiftpm/`, exported Core AI bundles, downloaded
  model weights, `runtime/`, or Tessera runtime data.
