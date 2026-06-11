import Testing

@testable import FMRagCore

@Test func acceptsExactlyOneQuestion() throws {
    let parsed = CLIArguments.parse(["test question"])
    #expect(parsed == .success("test question"))
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

@Test func formatsAvailableFoundationModelsStatus() {
    #expect(CLIOutput.foundationModelsAvailable == "Foundation Models: available")
}

@Test func formatsUnavailableFoundationModelsStatus() {
    let line = CLIOutput.foundationModelsUnavailable(reason: "modelNotReady")

    #expect(line == "Foundation Models: unavailable (modelNotReady)")
}

@Test func formatsFoundationModelsAnswer() {
    let line = CLIOutput.answer("Four.")

    #expect(line == "Answer: Four.")
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
