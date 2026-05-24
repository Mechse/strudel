import Foundation
import FoundationModels

enum Mode {
    case generateMessage
    case summarizeFile
}

@main
struct StrudelHelper {
    static func main() async {
        // 1. Parse mode from args. Default mode if no flag.
        let args = CommandLine.arguments.dropFirst()
        var mode: Mode = .generateMessage
        for arg in args {
            switch arg {
            case "--mode=default", "--mode=generate-message":
                mode = .generateMessage
            case "--mode=summarize-file":
                mode = .summarizeFile
            case "-h", "--help":
                printUsage()
                exit(0)
            default:
                fputs("strudel-helper: unknown argument: \(arg)\n", stderr)
                printUsage()
                exit(64)  // EX_USAGE
            }
        }

        // 2. Check model availability.
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            fputs("strudel-helper: Apple Intelligence unavailable: \(reason)\n", stderr)
            exit(2)
        }

        // 3. Read stdin.
        let stdinData = FileHandle.standardInput.readDataToEndOfFile()
        guard let input = String(data: stdinData, encoding: .utf8),
            !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            fputs("strudel-helper: empty or non-UTF8 input on stdin\n", stderr)
            exit(1)
        }

        // 4. Pick the right prompt and user-message wrapping for this mode.
        let instructions: String
        let userMessage: String
        switch mode {
        case .generateMessage:
            instructions = generateMessageInstructions
            userMessage = "Diff or change summary:\n\n\(input)"
        case .summarizeFile:
            instructions = summarizeFileInstructions
            userMessage = "File diff:\n\n\(input)"
        }

        // 5. Run the model.
        let session = LanguageModelSession(instructions: instructions)
        do {
            let response = try await session.respond(to: userMessage)
            print(response.content)
        } catch {
            fputs("strudel-helper: generation failed: \(error)\n", stderr)
            exit(1)
        }
    }

    static func printUsage() {
        let usage = """
            usage: strudel-helper [--mode=MODE]

            Reads input on stdin, writes output to stdout. Errors go to stderr.

            Modes:
              default | generate-message  Write a Git commit message from a diff
                                          or from a list of per-file summaries.
                                          (This is the default.)
              summarize-file              Write one short line summarizing the
                                          changes in a single file's diff.

            Exit codes:
              0  success
              1  generation failure or empty input
              2  Apple Intelligence unavailable
             64  invalid arguments
            """
        print(usage)
    }
}

// MARK: - Prompts

private let generateMessageInstructions = """
    You write Git commit messages.

    Input is either a raw Git diff, OR a list of lines in the form
    "filename: short summary" describing the files in one commit. Treat
    both shapes the same way: figure out what the commit does and write
    a message for it.

    Rules:
    - Output ONLY the commit message. No quotes, no markdown, no preamble, no closing remark.
    - First line: a short summary in imperative mood ("Add", "Fix", "Refactor" — never "Added", "Adds", "Adding"). Aim for 50 characters, hard maximum 72.
    - Describe what the code DOES, not what the diff operation IS. "Add new file: foo.swift" is wrong. "Add Swift helper that wraps FoundationModels" is right.
    - For a new file, read its contents (the + lines) and describe its purpose.
    - For a non-trivial change, follow the summary with a blank line and a 2-5 line body explaining context that isn't obvious from the diff.
    - Use a Conventional Commit prefix (feat:, fix:, refactor:, docs:, test:, chore:, perf:, style:) ONLY when clearly appropriate. Otherwise omit it.
    - Describe what is actually in the input. Do not invent intent.

    Example for adding a new utility module:

    feat: add token counter for diff truncation

    Adds a small helper that estimates token count from byte length
    so we can warn the user before sending oversize diffs to the model.

    Example for an initial commit:

    chore: initial commit

    Sets up the project skeleton: a Swift helper that pipes Git diffs
    through Apple's FoundationModels framework to generate commit
    messages, plus a placeholder for the Odin CLI that will drive it.
    """

private let summarizeFileInstructions = """
    You summarize one file's diff in a single short line.

    This summary will be combined with summaries of other files to write
    a Git commit message, so be precise about what changed in this file
    specifically. Do not write a commit message — that's a later step.

    Rules:
    - Output ONLY a single line. No filename prefix, no quotes, no markdown, no preamble.
    - Use imperative mood ("Add X", "Remove Y", "Rename Z to W").
    - Aim for 60-80 characters. One sentence.
    - Describe what changed in the code, not the diff mechanics. "Add MFA branch to login()" is right. "Add 5 lines to login.ts" is wrong.
    - If the file is new, describe its purpose based on its contents.
    - If the file is deleted, say "Remove <what it was for>".
    - Do not invent intent that isn't visible in the diff.

    Examples:

    Add MFA challenge branch to login() when user has mfaEnabled
    Rename getUserById to findUserById and update all call sites
    Remove deprecated v1 token parser
    Add Swift helper that wraps FoundationModels for commit-message generation
    """
