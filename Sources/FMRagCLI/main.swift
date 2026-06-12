import CoreAILanguageModels
import Darwin
import FMRagCore
import Foundation
import FoundationModels

let result = CLIArguments.parse(Array(CommandLine.arguments.dropFirst()))

switch result {
case .success(let command):
    await answer(command)
case .failure(let message):
    fputs("\(message)\n", stderr)
    exit(1)
}

private func answer(_ command: CLIArguments.Command) async {
    let question = command.question
    print("Question: \(question)")
    fflush(stdout)

    let client = TesseraMCPClient()
    let trace = ToolCallTrace()

    do {
        let tools = TesseraFoundationToolFactory.makeTools(client: client, trace: trace)

        switch command.modelSelection {
        case .foundationModels:
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                print(CLIOutput.foundationModelsAvailable)
                fflush(stdout)
            case .unavailable(let reason):
                print(CLIOutput.foundationModelsUnavailable(reason: availabilityReasonDescription(reason)))
                fflush(stdout)
                exit(1)
            @unknown default:
                print(CLIOutput.foundationModelsUnavailable(reason: "unknown"))
                fflush(stdout)
                exit(1)
            }

            let session = LanguageModelSession(
                model: model,
                tools: tools,
                instructions: TesseraPromptAssembly.instructions
            )
            let response = try await session.respond(to: question)
            await printAnswer(response.content, trace: trace, errorPrefix: "Foundation Models generation failed")

        case .coreAI(let modelPath):
            if let validationError = CoreAIModelPathValidator.validateDirectory(at: modelPath) {
                fputs("\(validationError)\n", stderr)
                exit(1)
            }

            print(CLIOutput.coreAIModel())
            print(CLIOutput.coreAIModelPath(modelPath))
            fflush(stdout)

            let modelURL = URL(fileURLWithPath: modelPath, isDirectory: true)
            let model = try await CoreAILanguageModel(resourcesAt: modelURL)
            let session = LanguageModelSession(
                model: model,
                tools: tools,
                instructions: TesseraPromptAssembly.instructions
            )
            let response = try await session.respond(
                to: question,
                options: GenerationOptions(maximumResponseTokens: 768)
            )
            await printAnswer(response.content, trace: trace, errorPrefix: "Core AI generation failed")
        }
    } catch {
        await printTraceLines(from: trace)
        let errorPrefix: String
        switch command.modelSelection {
        case .foundationModels:
            errorPrefix = "Foundation Models generation failed"
        case .coreAI:
            errorPrefix = "Core AI generation failed"
        }
        fputs("\(errorPrefix): \(error)\n", stderr)
        exit(1)
    }
}

private func printAnswer(_ content: String, trace: ToolCallTrace, errorPrefix: String) async {
    let answer = CLIOutput.normalizedAnswerContent(content)

    guard !answer.isEmpty else {
        await printTraceLines(from: trace)
        fputs("\(errorPrefix): empty response\n", stderr)
        exit(1)
    }

    await printTraceLines(from: trace)
    print(CLIOutput.answer(answer))
}

private func printTraceLines(from trace: ToolCallTrace) async {
    for line in await trace.lines() {
        print(line)
    }
    fflush(stdout)
}

private func availabilityReasonDescription(
    _ reason: SystemLanguageModel.Availability.UnavailableReason
) -> String {
    switch reason {
    case .appleIntelligenceNotEnabled:
        "appleIntelligenceNotEnabled"
    case .deviceNotEligible:
        "deviceNotEligible"
    case .modelNotReady:
        "modelNotReady"
    @unknown default:
        "unknown"
    }
}
