import Foundation

public enum CLIArguments {
    public static let usage = "Usage: swift run fm-rag [--coreai-model <path>] \"question text\""

    public static func parse(_ arguments: [String]) -> ParseResult {
        guard !arguments.isEmpty else {
            return .failure(usage)
        }

        var remaining = arguments
        var modelSelection = ModelSelection.foundationModels

        if remaining.first == "--coreai-model" {
            remaining.removeFirst()

            guard let modelPath = remaining.first, !modelPath.isEmpty, !modelPath.hasPrefix("--") else {
                return .failure(usage)
            }

            modelSelection = .coreAI(modelPath: modelPath)
            remaining.removeFirst()
        }

        guard remaining.count == 1, let question = remaining.first, !question.isEmpty else {
            return .failure(usage)
        }

        guard !question.hasPrefix("--") else {
            return .failure(usage)
        }

        return .success(Command(question: question, modelSelection: modelSelection))
    }

    public struct Command: Equatable {
        public let question: String
        public let modelSelection: ModelSelection

        public init(question: String, modelSelection: ModelSelection) {
            self.question = question
            self.modelSelection = modelSelection
        }
    }

    public enum ModelSelection: Equatable {
        case foundationModels
        case coreAI(modelPath: String)
    }

    public enum ParseResult: Equatable {
        case success(Command)
        case failure(String)
    }
}

public enum CoreAIModelPathValidator {
    public static func validateDirectory(at path: String, fileManager: FileManager = .default) -> String? {
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return CLIOutput.coreAIModelPathNotFound(path)
        }

        return nil
    }
}

public enum CLIOutput {
    public static let foundationModelsAvailable = "Foundation Models: available"

    public static func foundationModelsUnavailable(reason: String) -> String {
        "Foundation Models: unavailable (\(reason))"
    }

    public static func coreAIModel(name: String = "qwen3-4b") -> String {
        "Model: Core AI \(name)"
    }

    public static func coreAIModelPath(_ path: String) -> String {
        "Model path: \(path)"
    }

    public static func coreAIModelPathNotFound(_ path: String) -> String {
        "Model path not found: \(path)"
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
