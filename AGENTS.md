# AGENTS.md

## Project

This project is a PoC for onnecting Apple Foundation Models to external RAG and MCP-powered knowledge systems. It requires MacOS 26 beta 1 or newer.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## Scope of This File

This file contains exclusively development instructions for work on the `fm-rag` repo.

## Ways of Working

- Use `docs/architecture.md` as the continuously updated technical architecture and update it whenever a change affects architectural decisions.
- No commit unless explicitly told so by the user.
- It is forbidden to add a note to commit messages / details referencing the agent/AI that assisted in the creation.

# Development Conventions

**As of:** 2026-06-05

This document describes binding project conventions for code, files, documentation, and changes. It is extended whenever decisions are meant to apply permanently to the project.

## Language and Style

- Documentation in the repository is written in English.
- Code, file names, module names, tests, and technical identifiers are written in English.
- Comments in code explain the why, not the obvious.
- Do not leave commented-out code blocks permanently in the repository.
- Do not hardcode domain logic for individual rule questions.

## Changes
- No code changes without an approved change
- Every change must be registered in the root-level `implementation_plan.md` and its status must be maintained. Before committing a change, check and update the status in the implementation plan.
- The lifecycle of a change is: Draft -> Implementation Ready -> Approved -> Implemented
- Change documents must be written so a local coding model can implement them
  without relying on broad unstated project, framework, or platform knowledge.
  A change is not Implementation Ready until it is specific enough for a smaller
  local model to follow mechanically, classify failures, and stop at the right
  boundary.

### Local Model Implementability

Every change document must include enough detail to reduce guesswork for local
models:

- State the concrete goal in observable terms. Prefer "running `swift test`
  succeeds" over "tests work", and prefer "the placeholder window opens" over
  "the app runs".
- Define scope and non-goals explicitly. Non-goals must name tempting adjacent
  work that the model must not implement, especially when the next feature is
  obvious from the project direction.
- Name the affected modules, files, targets, commands, and documentation that
  are expected to change. If exact file names are not known yet, name the
  allowed directories and the ownership boundary.
- Specify required commands exactly, including working directory assumptions and
  whether commands are acceptance criteria, optional checks, or diagnostic aids.
- Specify the required test strategy. Name the test framework, the behavior to
  test, and behaviors that must not be asserted yet.
- Describe platform and toolchain constraints that are relevant to the change.
  This includes language versions, CLI-vs-IDE differences, generated files,
  unavailable macros, known cache or sandbox pitfalls, and framework-specific
  limitations.
- Include known failure signatures when a local model is likely to misdiagnose
  them. For each known signature, say what class of problem it indicates and the
  preferred recovery action.
- Include explicit "do not" guidance for common wrong fixes. For example, forbid
  adding dependencies, changing build systems, broad refactors, or implementing
  future features unless the change actually requires them.
- Define acceptance criteria as command-backed, user-observable outcomes. Each
  acceptance criterion should be verifiable by a command, a file inspection, or
  a clear manual check.
- Keep implementation steps small and ordered. Each step should have a matching
  verification note so a local model can make progress without looping on the
  same failing command.
- Document tradeoffs when multiple implementation paths are allowed. If one path
  is preferred, say why; if a fallback path is allowed, state the condition that
  permits it and the documentation required when it is used.
- Keep the change self-contained. Do not require the implementer to infer
  important constraints from chat history, model memory, or unversioned local
  context.

Changes may still leave design choices open when they are genuinely unimportant,
but ambiguity must be deliberate. If a choice affects architecture, build
commands, tests, user-visible behavior, or future work boundaries, the change
must either decide it or define the decision rule.

### Implementation Gate

Before creating or editing product files for an approved change, the implementer
must complete all preflight and discovery steps required by the change document.

Skipping a required preflight, wrapper command, dependency version check, API
grounding step, or other ordered setup step invalidates the implementation even
if later code happens to compile.

Required gates must be completed in order:

1. Read the change document.
2. Identify required preflight commands, command wrappers, dependency discovery,
   API grounding, and verification commands.
3. Run required preflight commands before product file edits.
4. Resolve dependency versions before writing manifests or integration code.
5. Ground external APIs against source-backed examples, source, generated docs,
   or official docs for the selected version.
6. Create or edit product files only after the required setup gates have
   completed successfully.
7. Update implementation status only after all required verification passes, or
   leave it unchanged with a clear blocker report.
8. When the user requests a commit, update the implementation status

If a required gate fails, stop and report the blocker. Do not continue by
guessing, substituting nearby commands, or writing partial implementation files.

### External API Grounding

When implementing against an external dependency, framework, SDK, tool, or
generated API, do not invent API names from memory or examples from another
version.

Apple Foundation Models are new and must be treated as a strict documentation-
grounded API surface. For any Foundation Models API design or implementation
decision, consult official Apple documentation first and record the specific
documented symbol, guide, or article that supports the usage. Installed SDK
interfaces, generated interfaces, local examples, or successful compilation are
not sufficient on their own for Foundation Models usage. If official Apple
documentation does not clearly support the API shape or behavior, stop and
report the evidence gap instead of designing or implementing by inference.

Before writing integration code:

- Identify the exact dependency, SDK, framework, or tool version selected for
  the change.
- Find a source-backed usage pattern for that exact version. Prefer, in order:
  existing project code using the same API, examples shipped with the installed
  dependency, installed dependency source or generated documentation, then
  official documentation for the selected version.
- Implement only with symbols, modules, methods, flags, configuration keys, and
  construction patterns that were verified in those sources.
- If the first compile, check, or smoke command fails with unresolved imports,
  missing methods, private modules, unknown flags, unknown configuration keys,
  or type-name errors, stop editing and inspect the selected version's
  examples, source, generated docs, or official docs before trying another API
  shape.
- Do not repeatedly guess alternate names for the same missing API.
- After two failed compile, check, or smoke attempts caused by unknown external
  API shape, stop and report the exact command run, the unresolved symbols or
  unsupported API surface, the source files or examples inspected, and the next
  source that must be consulted.

## File Names

- Markdown documents under `docs/` use `kebab-case`, for example `retrieval-reimplementation-plan.md`.
- Change documents are located under `docs/changes/` and begin with date and sequence number: `YYYY-MM-DD-NN-short-title.md`.
- Python modules and packages use `snake_case`.
- Swift source files use `UpperCamelCase` and are named after the primary type or view they contain.
- Configuration files keep established names, for example `pyproject.toml`, `docker-compose.yml`, `.dockerignore`, `.gitignore`.
- `AGENTS.md` and `CLAUDE.md` in the repo root are reserved exclusively for
  development instructions of the product repo. Usage profiles for
  consuming MCP agents are located under `agent-config/`.
- Runtime data is located exclusively under `runtime/` and
  is not committed.

## Swift Code

- Swift Package Manager is the default build system unless an approved change
  explicitly requires an Xcode project or workspace.
- Swift package tasks should run with `swift build` and `swift test` from the
  repository root. Xcode-backed targets should use `xcodebuild` with an
  explicit scheme, destination, and `-derivedDataPath runtime/derived-data`.
- Keep SwiftPM build output in the default repo-local `.build/` directory.
  Keep Xcode derived data and other generated build products under `runtime/`.
- Before changes that depend on macOS 26, Apple Foundation Models, SwiftData,
  AppKit, SwiftUI, or other Apple SDK APIs, verify the active toolchain with
  `swift --version` and `xcrun --show-sdk-path`.
- Ground Apple framework usage against the installed SDK headers, generated
  interfaces, local examples, or current official Apple documentation for the
  selected SDK. Do not invent Foundation Models or framework symbols from
  memory.
- For Apple Foundation Models specifically, official Apple documentation is
  mandatory evidence for every API usage. Do not design or implement Foundation
  Models session, tool, generation, transcript, options, or availability code
  from memory, SDK symbol names alone, examples from unofficial sources, or
  guessed behavior.
- Prefer `struct`, `enum`, and protocol-oriented designs for value semantics.
  Use classes only when reference identity, observation, Objective-C
  interoperability, or framework requirements make them appropriate.
- Use Swift concurrency deliberately. Prefer `async`/`await`, `Task`, actors,
  and `Sendable` where they fit the ownership and isolation model. Keep UI
  mutations on the main actor.
- Use Swift's typed error handling with `throws` and domain-specific `Error`
  enums for recoverable failures. Avoid `try!`, force unwraps, and implicitly
  unwrapped optionals in production code paths unless the invariant is enforced
  by the framework or construction path and documented locally.
- Keep public APIs minimal and intentional. Types should be named after domain
  concepts, not implementation mechanics.
- Prefer dependency injection through initializers or small protocols when code
  needs to be tested. Do not add abstraction layers for single-use behavior.
- Tests use Swift Testing or XCTest as selected by the package or target. Put
  package tests under `Tests/` and keep focused unit tests close to the behavior
  they verify.
- Use the repository's configured Swift formatter and linter when present. If
  none is configured yet, keep formatting consistent with surrounding code and
  avoid broad formatting-only diffs.
- When adding Swift package dependencies, look up the current compatible
  version and pin the requirement deliberately in `Package.swift`. Document any
  downgrade, branch dependency, or exact-version pin in the change document.

## Imports and Package Structure

- Prefer absolute imports within the project.


## Tests

- Every change defines a concrete verification path before implementation.
- New core logic gets focused tests.
- Tests for retrieval should verify source and metadata behavior, not just free response text.
- External documents must not be committed as test fixtures without control.
- Requirements fixtures may only contain synthetic test data.
- Eval input baselines are the limited exception for real sources in the repo:
  they are located under `eval_inputs/`, require a `manifest.json` with
  file hashes, tree hash, size, and source groups, and may only be
  regenerated or updated via explicit change approval.
- Binding gold/silver regression runs use
  `runtime_regtest/`. `runtime/` remains reserved for exploration, local investigations, and new
  inputs.
- Every eval input baseline must be reproducibly restored and verified
  into `runtime_regtest/` via versioned restore and verify targets.
- `swift test` runs Swift package tests.
- `swift build` verifies Swift package compilation.
- Xcode-backed targets are verified with `xcodebuild test` using the scheme,
  destination, and derived data path specified by the approved change.
- If the repository defines `make test`, `make lint`, `make typecheck`, or
  `make check`, those targets are the project-level wrappers for the same
  checks and should be preferred by change documents.

## MCP Tools

- MCP tools remain read-only for now.
- No shell execution via MCP.
- Tool responses should include source metadata once real data is connected.
- Tools should remain generic and not implement individual rule questions as special functions.

## Commits

- Commit messages follow Conventional Commits.
- No commit without explicit approval.
- Every implemented change should remain separately committable.
- The commit scope should match the actual change, for example `docs:`, `build:`, `feat:`, `fix:`, `test:`, or `refactor:`.
