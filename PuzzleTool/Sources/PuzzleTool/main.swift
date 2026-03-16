// CLI.swift — entry point for PuzzleTool
//
// Usage:
//   swift run PuzzleTool generate --date 2024-06-15
//   swift run PuzzleTool validate puzzles/puzzle-2024-06-15.json
//   swift run PuzzleTool preview  puzzles/puzzle-2024-06-15.json

import Foundation

// MARK: - Bootstrap

let filter = ProfanityFilter()
let trie = loadTrie(filter: filter)

guard CommandLine.arguments.count >= 2 else {
    printUsage()
    exit(1)
}

let command = CommandLine.arguments[1]

switch command {
case "generate":
    runGenerate()
case "validate":
    runValidate()
case "preview":
    runPreview()
default:
    printUsage()
    exit(1)
}

// MARK: - Commands

func runGenerate() {
    var dateString = todayString()

    // Parse --date YYYY-MM-DD
    let args = CommandLine.arguments
    if let idx = args.firstIndex(of: "--date"), idx + 1 < args.count {
        dateString = args[idx + 1]
    }

    guard isValidDateString(dateString) else {
        print("Error: invalid date '\(dateString)'. Expected YYYY-MM-DD.")
        exit(1)
    }

    print("Generating puzzle for \(dateString)…")

    do {
        let puzzle = try Generator.generate(dateString: dateString, trie: trie, filter: filter)

        // Write JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(puzzle)

        let outputDir = puzzlesDir()
        try FileManager.default.createDirectory(atPath: outputDir,
                                                withIntermediateDirectories: true)
        let path = (outputDir as NSString).appendingPathComponent("puzzle-\(dateString).json")
        try data.write(to: URL(fileURLWithPath: path))

        print("Written: \(path)")

        // Quick validation summary
        let validator = Validator(trie: trie, filter: filter)
        let results = validator.validate(puzzle: puzzle)
        for (i, r) in results.enumerated() {
            let status = r.isValid ? "✓" : "✗"
            print("  Wave \(i+1) \(status)  \(r.wordCount) words  longest: \(r.longestWord)")
        }

    } catch {
        print("Error: \(error)")
        exit(1)
    }
}

func runValidate() {
    guard CommandLine.arguments.count >= 3 else {
        print("Usage: validate <filepath>")
        exit(1)
    }
    let path = CommandLine.arguments[2]
    let puzzle = loadPuzzle(from: path)

    let validator = Validator(trie: trie, filter: filter)
    let results = validator.validate(puzzle: puzzle)

    var allValid = true
    for (i, r) in results.enumerated() {
        let status = r.isValid ? "✓" : "✗"
        print("Wave \(i+1) \(status)  \(r.wordCount) words  longest: \(r.longestWord)")
        for err in r.errors { print("    ⚠ \(err)") }
        if !r.isValid { allValid = false }
    }

    print(allValid ? "\nPuzzle is valid." : "\nPuzzle has errors.")
    exit(allValid ? 0 : 1)
}

func runPreview() {
    guard CommandLine.arguments.count >= 3 else {
        print("Usage: preview <filepath>")
        exit(1)
    }
    let path = CommandLine.arguments[2]
    let puzzle = loadPuzzle(from: path)

    print("Puzzle: \(puzzle.date)  (\(puzzle.waves.count) waves)\n")

    let validator = Validator(trie: trie, filter: filter)

    for (i, wave) in puzzle.waves.enumerated() {
        print("── Wave \(i+1) [\(wave.difficulty.rawValue.uppercased())]  target: \(wave.targetWord)")
        for row in wave.grid {
            print("  " + row.joined(separator: " "))
        }

        let result = validator.validateWave(wave, index: i)
        let top = result.allWords.prefix(10).joined(separator: ", ")
        print("  Words (\(result.wordCount) total): \(top)\(result.wordCount > 10 ? ", …" : "")")
        for err in result.errors { print("  ⚠ \(err)") }
        print()
    }
}

// MARK: - Helpers

func loadTrie(filter: ProfanityFilter) -> Trie {
    guard let url = Bundle.module.url(forResource: "enable", withExtension: "txt") else {
        fputs("Fatal: enable.txt not found in bundle\n", stderr)
        exit(1)
    }
    guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
        fputs("Fatal: could not read enable.txt\n", stderr)
        exit(1)
    }

    let trie = Trie()
    var removed: [String] = []
    for line in contents.split(separator: "\n") {
        let word = line.trimmingCharacters(in: .whitespaces).uppercased()
        guard word.count >= Solver.minLength else { continue }
        if filter.isBlocked(word) {
            removed.append(word)
        } else {
            trie.insert(word)
        }
    }
    if !removed.isEmpty {
        print("⚠ Profanity filter: removed \(removed.count) word(s) from dictionary: \(removed.joined(separator: ", "))")
    }
    return trie
}

func loadPuzzle(from path: String) -> Puzzle {
    let url = URL(fileURLWithPath: path)
    guard let data = try? Data(contentsOf: url) else {
        print("Error: cannot read file at '\(path)'")
        exit(1)
    }
    guard let puzzle = try? JSONDecoder().decode(Puzzle.self, from: data) else {
        print("Error: invalid JSON in '\(path)'")
        exit(1)
    }
    return puzzle
}

/// Absolute path to the puzzles/ directory next to PuzzleTool/.
func puzzlesDir() -> String {
    // When run via `swift run` from PuzzleTool/, cwd is the package root.
    // The puzzles/ dir lives one level up alongside the Xcode project.
    let cwd = FileManager.default.currentDirectoryPath
    // If cwd ends in PuzzleTool, go up one level
    if cwd.hasSuffix("PuzzleTool") {
        return (cwd as NSString).appendingPathComponent("../puzzles")
    }
    return (cwd as NSString).appendingPathComponent("puzzles")
}

func todayString() -> String {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    fmt.timeZone = TimeZone(identifier: "UTC")
    return fmt.string(from: Date())
}

func isValidDateString(_ s: String) -> Bool {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    fmt.timeZone = TimeZone(identifier: "UTC")
    return fmt.date(from: s) != nil
}

func printUsage() {
    print("""
    PuzzleTool — Letter Drop daily puzzle generator

    Commands:
      generate [--date YYYY-MM-DD]   Generate puzzle (default: today)
      validate <filepath>            Validate an existing puzzle JSON
      preview  <filepath>            Print grid + top words for each wave
    """)
}
