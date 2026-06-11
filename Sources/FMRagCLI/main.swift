import Darwin
import FMRagCore
import FoundationModels

let result = CLIArguments.parse(Array(CommandLine.arguments.dropFirst()))

switch result {
case .success(let question):
    await answer(question)
case .failure(let message):
    fputs("\(message)\n", stderr)
    exit(1)
}

private func answer(_ question: String) async {
    print("Question: \(question)")
    fflush(stdout)

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

    do {
        let session = LanguageModelSession(model: model, tools: [])
        let response = try await session.respond(to: question)
        let answer = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !answer.isEmpty else {
            fputs("Foundation Models generation failed: empty response\n", stderr)
            exit(1)
        }

        print(CLIOutput.answer(answer))
    } catch {
        fputs("Foundation Models generation failed: \(error)\n", stderr)
        exit(1)
    }
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
