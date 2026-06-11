# 2026-06-11-02: Phase 1 Swift Package And CLI Shell

**Status:** Approved

**Created:** 2026-06-11

## Goal

Create the initial Swift Package Manager project shell for the Phase 1 command-line proof of concept.

Success means the repository root can be built with SwiftPM, opened in Xcode as a Swift package, and run as a minimal CLI that accepts one question argument and echoes it through the CLI entry point.

This change intentionally establishes only the package and CLI shell. It does not integrate Apple Foundation Models, MCP, or retrieval.

## Scope

Implement:

- `Package.swift` at the repository root.
- One executable target named `FMRagCLI`.
- One library target named `FMRagCore` only if needed to keep argument handling testable.
- A CLI executable product named `fm-rag`.
- Minimal command-line argument handling for exactly one question string.
- Focused tests for deterministic CLI argument parsing if parsing is placed in a library target.
- `.gitignore` entries for SwiftPM, Xcode, and local runtime build outputs.
- README or runbook updates that show how to build, test, run, and open the package in Xcode.

Allowed paths:

- `Package.swift`
- `.gitignore`
- `Sources/FMRagCLI/`
- `Sources/FMRagCore/`
- `Tests/FMRagCoreTests/`
- `README.md`
- `implementation_plan.md`

## Non-Goals

Do not implement:

- Apple Foundation Models imports or API usage.
- `LanguageModelSession`.
- Foundation Models `Tool` conformance.
- MCP client code.
- RAG server calls.
- Retrieval result formatting.
- Prompt assembly for model generation.
- Xcode project or workspace files.
- Configuration files for MCP server selection.
- Interactive REPL behavior.
- Logging, telemetry, or observability beyond normal CLI output.

## Design

Use Swift Package Manager as the source of truth. Xcode should open the repository root directly as a Swift package.

The CLI behavior is intentionally minimal:

```sh
swift run fm-rag "What is in the knowledge base?"
```

Expected output should show that the argument reached the executable, for example:

```text
Question: What is in the knowledge base?
```

If no question is provided or more than one question argument is provided, print a short usage message and exit with a nonzero status.

Keep argument parsing small. A local helper type or function is acceptable if it enables tests. Do not add an external argument parsing dependency for this change.

## Required Preflight

Run these commands before editing product files:

```sh
swift --version
xcrun --show-sdk-path
```

Record the output in the implementation notes or final report.

This change does not use Apple Foundation Models APIs. Do not consult, design, or implement Foundation Models symbols as part of this change.

## Implementation Steps

1. Create the SwiftPM package shell.
   - Add `Package.swift` with macOS 26 as the platform target.
   - Define an executable product named `fm-rag`.
   - Define `FMRagCLI` as the executable target.
   - Add `FMRagCore` and tests only if argument parsing is moved out of `main.swift`.

2. Implement minimal CLI argument handling.
   - Accept exactly one question argument.
   - Print `Question: <question>` for a valid invocation.
   - Print usage and exit nonzero for invalid invocations.

3. Add repository hygiene.
   - Add `.gitignore` entries for `.build/`, `.swiftpm/`, `DerivedData/`, `runtime/`, and user-specific Xcode files if needed.
   - Do not commit generated SwiftPM or Xcode state.

4. Document the shell.
   - Update README instructions for `swift build`, `swift test`, `swift run fm-rag "..."`, and opening the repository root in Xcode.

## Verification

Required commands from the repository root:

```sh
swift build
swift test
swift run fm-rag "test question"
```

Expected CLI output:

```text
Question: test question
```

Also verify manually:

- Open the repository root in Xcode.
- Confirm Xcode loads the Swift package.
- Confirm the `fm-rag` or `FMRagCLI` scheme is visible.
- Confirm the CLI target builds in Xcode on a supported macOS 26 machine.

## Acceptance Criteria

- `swift build` succeeds.
- `swift test` succeeds.
- `swift run fm-rag "test question"` prints `Question: test question`.
- Invalid argument counts print usage and exit nonzero.
- The repository root opens in Xcode as a Swift package.
- The CLI target is visible and builds in Xcode.
- No Apple Foundation Models API is imported or referenced.
- No MCP or retrieval code is added.
- No `.xcodeproj`, `.xcworkspace`, `.build/`, `.swiftpm/`, `runtime/`, or derived data is committed.
- `implementation_plan.md` marks this change as `Implemented` only after all required verification passes.

## Known Failure Signatures

- `error: the package manifest requires a minimum Swift tools version...`
  - Indicates the selected `swift-tools-version` is newer than the active toolchain. Use a tools version supported by the installed Swift toolchain.
- `error: no executable product named 'fm-rag'`
  - Indicates the executable product name does not match the required CLI command. Fix `Package.swift`; do not change the required command.
- Xcode opens an empty folder instead of a package.
  - Indicates `Package.swift` is missing or invalid. Fix the SwiftPM manifest; do not add a hand-maintained Xcode project unless SwiftPM package opening is proven insufficient.
- Xcode writes user state files.
  - Do not commit them. Add ignore rules if needed.

## Wrong Fixes To Avoid

- Do not add Foundation Models code early to prove future integration.
- Do not add MCP server configuration or client code.
- Do not add dependencies for argument parsing.
- Do not generate or commit an Xcode project.
- Do not broaden the CLI into an interactive app.
- Do not add a GUI.
- Do not mark the change implemented because `swift build` passes if `swift test`, CLI run, or Xcode build has not been checked.
