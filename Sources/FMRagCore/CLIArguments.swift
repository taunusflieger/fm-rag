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
