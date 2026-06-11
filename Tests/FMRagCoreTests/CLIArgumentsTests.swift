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

private extension CLIArguments.ParseResult {
    var failure: String? {
        if case .failure(let message) = self {
            message
        } else {
            nil
        }
    }
}
