import Darwin
import FMRagCore

let result = CLIArguments.parse(Array(CommandLine.arguments.dropFirst()))

switch result {
case .success(let question):
    print("Question: \(question)")
case .failure(let message):
    fputs("\(message)\n", stderr)
    exit(1)
}
