import Foundation
import Testing

@testable import FMRagCore

@Test func acceptsExactlyOneQuestion() throws {
    let parsed = CLIArguments.parse(["test question"])

    #expect(parsed == .success(.init(question: "test question", modelSelection: .foundationModels)))
}

@Test func acceptsCoreAIModelOption() throws {
    let parsed = CLIArguments.parse(["--coreai-model", "/tmp/model", "test question"])

    #expect(parsed == .success(.init(question: "test question", modelSelection: .coreAI(modelPath: "/tmp/model"))))
}

@Test func rejectsMissingQuestion() {
    let parsed = CLIArguments.parse([])

    #expect(parsed.failure == CLIArguments.usage)
}

@Test func rejectsMultipleArguments() {
    let parsed = CLIArguments.parse(["one", "two"])

    #expect(parsed.failure == CLIArguments.usage)
}

@Test func rejectsEmptyQuestion() {
    let parsed = CLIArguments.parse([""])

    #expect(parsed.failure == CLIArguments.usage)
}

@Test func rejectsMissingCoreAIModelPath() {
    let parsed = CLIArguments.parse(["--coreai-model"])

    #expect(parsed.failure == CLIArguments.usage)
}

@Test func rejectsDuplicateCoreAIModelOption() {
    let parsed = CLIArguments.parse(["--coreai-model", "/tmp/model", "--coreai-model", "/tmp/other", "question"])

    #expect(parsed.failure == CLIArguments.usage)
}

@Test func rejectsUnknownFlag() {
    let parsed = CLIArguments.parse(["--model", "/tmp/model", "question"])

    #expect(parsed.failure == CLIArguments.usage)
}

@Test func rejectsMissingQuestionAfterCoreAIModelPath() {
    let parsed = CLIArguments.parse(["--coreai-model", "/tmp/model"])

    #expect(parsed.failure == CLIArguments.usage)
}

@Test func validatesExistingCoreAIModelDirectory() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("fm-rag-coreai-model-validation-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let message = CoreAIModelPathValidator.validateDirectory(at: directory.path)

    #expect(message == nil)
}

@Test func rejectsMissingCoreAIModelDirectory() {
    let path = FileManager.default.temporaryDirectory
        .appendingPathComponent("fm-rag-missing-coreai-model-\(UUID().uuidString)", isDirectory: true)
        .path

    let message = CoreAIModelPathValidator.validateDirectory(at: path)

    #expect(message == "Model path not found: \(path)")
}

@Test func formatsAvailableFoundationModelsStatus() {
    #expect(CLIOutput.foundationModelsAvailable == "Foundation Models: available")
}

@Test func formatsUnavailableFoundationModelsStatus() {
    let line = CLIOutput.foundationModelsUnavailable(reason: "modelNotReady")

    #expect(line == "Foundation Models: unavailable (modelNotReady)")
}

@Test func formatsCoreAIModelOutput() {
    #expect(CLIOutput.coreAIModel() == "Model: Core AI qwen3-4b")
    #expect(CLIOutput.coreAIModelPath("/tmp/model") == "Model path: /tmp/model")
}

@Test func formatsFoundationModelsAnswer() {
    let line = CLIOutput.answer("Four.")

    #expect(line == "Answer: Four.")
}

@Test func normalizesFoundationModelsRolePrefix() {
    let content = CLIOutput.normalizedAnswerContent("model\nFour.\n")

    #expect(content == "Four.")
}

private extension CLIArguments.ParseResult {
    var failure: String? {
        if case .failure(let message) = self {
            message
        } else {
            nil
        }
    }
}
