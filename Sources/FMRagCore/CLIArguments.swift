public enum CLIArguments {
    public static let usage = "Usage: swift run fm-rag \"question text\""

    public static func parse(_ arguments: [String]) -> ParseResult {
        guard arguments.count == 1, let question = arguments.first, !question.isEmpty else {
            return .failure(usage)
        }

        return .success(question)
    }

    public enum ParseResult: Equatable {
        case success(String)
        case failure(String)
    }
}

public enum CLIOutput {
    public static let foundationModelsAvailable = "Foundation Models: available"

    public static func foundationModelsUnavailable(reason: String) -> String {
        "Foundation Models: unavailable (\(reason))"
    }

    public static func answer(_ content: String) -> String {
        "Answer: \(content)"
    }

    public static func normalizedAnswerContent(_ content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["model\n", "assistant\n"] {
            if trimmed.hasPrefix(prefix) {
                return String(trimmed.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return trimmed
    }
}
