import Foundation
import FoundationModels

enum Mode {
    case generateMessage
    case summarizeFile
}

// MARK: - Guided output shapes

@Generable
struct CommitMessage {
    @Guide(
        description:
            "Imperative-mood summary of what the change does. First word is one of: Add, Fix, Refactor, Remove, Update, Rename, Move, Replace, Document, Test. Never past tense or gerund (no 'Added', 'Adds', 'Adding', 'Will add'). Maximum 72 characters."
    )
    let summary: String

    @Guide(
        description:
            "Conventional Commit type, chosen by what the change accomplishes:\n- feat: adds new user-visible functionality\n- fix: corrects a bug\n- refactor: restructures code without changing behavior\n- docs: documentation only\n- test: tests only\n- chore: build, tooling, dependencies, project setup, gitignore\n- perf: performance improvement\n- style: formatting only, no code change\nReturn empty string if none of these clearly fits."
    )
    let type: String

    @Guide(
        description:
            "Explanatory body: 2-5 short lines describing what the change accomplishes and any context not obvious from the diff. Empty string for trivial changes like typos, one-line fixes, or version bumps."
    )
    let body: String
}

@Generable
struct FileSummary {
    @Guide(
        description:
            "One-line, imperative-mood description of what changed in this file. 60-80 characters. No filename prefix, no markdown."
    )
    let summary: String
}

// MARK: - Entry point

@main
struct SaftHelper {
    static func main() async {
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
                fputs("saft-helper: unknown argument: \(arg)\n", stderr)
                printUsage()
                exit(64)
            }
        }

        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            fputs("saft-helper: Apple Intelligence unavailable: \(reason)\n", stderr)
            exit(2)
        }

        let stdinData = FileHandle.standardInput.readDataToEndOfFile()
        guard let input = String(data: stdinData, encoding: .utf8),
            !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            fputs("saft-helper: empty or non-UTF8 input on stdin\n", stderr)
            exit(1)
        }

        do {
            switch mode {
            case .generateMessage:
                try await runGenerateMessage(input: input)
            case .summarizeFile:
                try await runSummarizeFile(input: input)
            }
        } catch {
            fputs("saft-helper: generation failed: \(error)\n", stderr)
            exit(1)
        }
    }

    static func runGenerateMessage(input: String) async throws {
        let session = LanguageModelSession(instructions: generateMessageInstructions)
        let response = try await session.respond(
            to: "Diff or change summary:\n\n\(input)",
            generating: CommitMessage.self
        )
        let msg = response.content

        // Belt-and-suspenders: enforce imperative mood even if the model slipped.
        let cleanedSummary = forceImperative(msg.summary)

        let firstLine: String
        if msg.type.isEmpty {
            firstLine = cleanedSummary
        } else {
            firstLine = "\(msg.type): \(cleanedSummary)"
        }

        if msg.body.isEmpty {
            print(firstLine)
        } else {
            print(firstLine)
            print("")
            print(forceImperative(msg.body))
        }
    }

    static func runSummarizeFile(input: String) async throws {
        let session = LanguageModelSession(instructions: summarizeFileInstructions)
        let response = try await session.respond(
            to: "File diff:\n\n\(input)",
            generating: FileSummary.self
        )
        print(forceImperative(response.content.summary))
    }

    /// Replaces common past/gerund forms at the start of each line with imperative forms.
    /// The model usually gets it right; this catches the cases it doesn't.
    static func forceImperative(_ text: String) -> String {
        let replacements: [(String, String)] = [
            ("Added ", "Add "),
            ("Adds ", "Add "),
            ("Adding ", "Add "),
            ("Fixed ", "Fix "),
            ("Fixes ", "Fix "),
            ("Fixing ", "Fix "),
            ("Refactored ", "Refactor "),
            ("Refactors ", "Refactor "),
            ("Removed ", "Remove "),
            ("Removes ", "Remove "),
            ("Updated ", "Update "),
            ("Updates ", "Update "),
            ("Renamed ", "Rename "),
            ("Renames ", "Rename "),
            ("Changed ", "Change "),
            ("Changes ", "Change "),
            ("Moved ", "Move "),
            ("Moves ", "Move "),
            ("Replaced ", "Replace "),
            ("Replaces ", "Replace "),
        ]
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        for i in lines.indices {
            for (from, to) in replacements {
                if lines[i].hasPrefix(from) {
                    lines[i] = to + lines[i].dropFirst(from.count)
                    break
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    static func printUsage() {
        let usage = """
            usage: saft-helper [--mode=MODE]

            Reads input on stdin, writes output to stdout. Errors go to stderr.

            Modes:
              default | generate-message  Write a Git commit message from a diff
                                          or from a list of per-file summaries.
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

// MARK: - Instructions

private let generateMessageInstructions = """
    You write Git commit messages from a diff or from a list of per-file summaries.

    Determine what the change accomplishes by reading the input. Produce:
    - A summary line in imperative mood (first word is "Add", "Fix", "Refactor", "Remove", "Update", "Rename", or similar).
    - A Conventional Commit type when one clearly fits: feat for new functionality, fix for bug fixes, refactor for restructuring without behavior change, docs for documentation, test for tests, chore for tooling and build, perf for performance, style for formatting. Leave the type empty when none clearly fits.
    - A body only if the change is non-trivial; otherwise leave the body empty.

    The summary describes what the code does, not what the diff operation is. A new file is described by its purpose, derived from its contents, not by the fact that it is new.
    """

private let summarizeFileInstructions = """
    You summarize what changed in one file of a Git commit.

    Read the file's diff and produce one short, imperative-mood line describing the change. This summary will be combined with summaries of other files to write a commit message later.

    Describe what the code does, not the mechanics of the diff. A new file is described by its purpose, derived from its contents.
    """
