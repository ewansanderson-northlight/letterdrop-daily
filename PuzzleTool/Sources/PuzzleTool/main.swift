// CLI.swift — entry point for PuzzleTool
//
// Usage:
//   swift run PuzzleTool generate [--date YYYY-MM-DD] [--difficulty easy]
//   swift run PuzzleTool validate puzzles/puzzle-YYYY-MM-DD.json
//   swift run PuzzleTool preview  puzzles/puzzle-YYYY-MM-DD.json

import Foundation

// MARK: - Bootstrap

let filter    = ProfanityFilter()
let wordleSet = loadWordleSet()
let genTrie   = loadGeneratorTrie(filter: filter, wordleSet: wordleSet)
let validTrie = loadValidatorTrie(filter: filter)

guard CommandLine.arguments.count >= 2 else { printUsage(); exit(1) }

switch CommandLine.arguments[1] {
case "generate": runGenerate()
case "validate": runValidate()
case "preview":  runPreview()
default:         printUsage(); exit(1)
}

// MARK: - Commands

func runGenerate() {
    let args = CommandLine.arguments
    var dateString = todayString()
    var easyMode   = false

    if let idx = args.firstIndex(of: "--date"), idx + 1 < args.count {
        dateString = args[idx + 1]
    }
    if let idx = args.firstIndex(of: "--difficulty"), idx + 1 < args.count {
        easyMode = args[idx + 1].lowercased() == "easy"
    }

    guard isValidDateString(dateString) else {
        print("Error: invalid date '\(dateString)'. Expected YYYY-MM-DD."); exit(1)
    }
    dateString = normalizedDateString(dateString)

    let modeLabel = easyMode ? " [EASY MODE]" : ""
    print("Generating puzzle for \(dateString)\(modeLabel)…")

    do {
        let puzzle = try Generator.generate(dateString: dateString,
                                            trie: genTrie,
                                            filter: filter,
                                            easyMode: easyMode)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(puzzle)

        let outputDir = puzzlesDir()
        try FileManager.default.createDirectory(atPath: outputDir,
                                                withIntermediateDirectories: true)
        let path = (outputDir as NSString).appendingPathComponent("puzzle-\(dateString).json")
        try data.write(to: URL(fileURLWithPath: path))
        print("Written: \(path)\n")

        // Quick per-wave summary using the generator trie
        let validator = Validator(trie: genTrie, filter: filter, wordleSet: wordleSet)
        let results   = validator.validate(puzzle: puzzle)
        for (i, r) in results.enumerated() {
            let wave   = puzzle.waves[i]
            let status = r.isValid ? "✓" : "✗"
            print("  Wave \(i+1) [\(wave.difficulty.rawValue.uppercased())] \(status)  " +
                  "\(r.wordCount) words  4+: \(r.words4 + r.words5Total + r.words6Plus)  " +
                  "longest: \(r.longestWord)")
            for err in r.errors { print("    ⚠ \(err)") }
        }

        // Bonus word scan
        print("")
        var anyBonus = false
        for (i, wave) in puzzle.waves.enumerated() {
            let longWords = Solver.solve(grid: wave.grid, trie: genTrie).filter { $0.count >= 7 }
            if !longWords.isEmpty {
                anyBonus = true
                let veryLong = longWords.filter { $0.count >= 9 }
                let label    = veryLong.isEmpty ? "⚠️ " : "⚠️ ⚠️ "
                print("\(label)Wave \(i+1) long words (7+): \(longWords.joined(separator: ", "))")
                if !veryLong.isEmpty {
                    print("   ↳ Very long (9+): \(veryLong.joined(separator: ", "))")
                }
            }
        }
        if !anyBonus { print("✓ No 7+ letter words in any wave.") }

    } catch {
        print("Error: \(error)"); exit(1)
    }
}

func runValidate() {
    guard CommandLine.arguments.count >= 3 else {
        print("Usage: validate <filepath>"); exit(1)
    }
    let path   = CommandLine.arguments[2]
    let puzzle = loadPuzzle(from: path)

    let validator = Validator(trie: validTrie, filter: filter, wordleSet: wordleSet)
    let results   = validator.validate(puzzle: puzzle)

    var allValid = true
    for (i, r) in results.enumerated() {
        let wave       = puzzle.waves[i]
        let diff       = wave.difficulty
        let passStr    = r.isValid ? "PASS" : "FAIL"
        let statusIcon = r.isValid ? "✅" : "❌"

        print("Wave \(i+1) — \(diff.rawValue.uppercased()) \(statusIcon)")
        print("  Valid words: \(r.wordCount) | Longest: \(r.longestWord) | Status: \(passStr)")

        // Findability score
        let fsTarget  = diff.findabilityTarget
        let fsIcon    = r.findabilityScore >= fsTarget ? "✅" : "❌"
        print("")
        print("  Findability score: \(r.findabilityScore)/100 \(fsIcon) (target ≥ \(fsTarget))")

        // 3-letter
        print("    3-letter words: \(pad(r.words3))")

        // 4-letter with threshold check
        let total4Plus = r.words4 + r.words5Total + r.words6Plus
        let t4Icon = total4Plus >= diff.min4PlusWords ? "✅" : "❌"
        print("    4-letter words: \(pad(r.words4))  \(t4Icon) (target 4+: ≥ \(diff.min4PlusWords))")

        // 5-letter with Wordle-tier annotation
        let w5icon = r.words5Wordle > 0 ? "✅" : "⚠️ "
        var w5suffix = ""
        if r.words5Wordle > 0 {
            w5suffix = " (Wordle-tier: \(r.words5Wordle), ENABLE-only: \(r.words5EnableOnly))"
        } else if r.words5Total > 0 {
            w5suffix = " (ENABLE-only: \(r.words5EnableOnly), none Wordle-tier)"
        }
        print("    5-letter words: \(pad(r.words5Total))  \(w5icon)\(w5suffix)")

        // 6+ with threshold check
        let t6Icon = r.words6Plus >= diff.min6PlusWords ? "✅" : "❌"
        print("    6+ letter words:\(pad(r.words6Plus))  \(t6Icon) (target ≥ \(diff.min6PlusWords))")

        for err in r.errors { print("    ⚠ \(err)") }
        if !r.isValid { allValid = false }
        print("")
    }

    print(allValid ? "Puzzle is valid ✅" : "Puzzle has errors ❌")
    exit(allValid ? 0 : 1)
}

func runPreview() {
    guard CommandLine.arguments.count >= 3 else {
        print("Usage: preview <filepath>"); exit(1)
    }
    let path   = CommandLine.arguments[2]
    let puzzle = loadPuzzle(from: path)

    print("Puzzle: \(puzzle.date)  (\(puzzle.waves.count) waves)\n")

    let validator = Validator(trie: validTrie, filter: filter, wordleSet: wordleSet)

    for (i, wave) in puzzle.waves.enumerated() {
        print("── Wave \(i+1) [\(wave.difficulty.rawValue.uppercased())]  target: \(wave.targetWord)")
        for row in wave.grid { print("  " + row.joined(separator: " ")) }

        let result = validator.validateWave(wave, index: i)
        let top    = result.allWords.prefix(10).joined(separator: ", ")
        print("  Words (\(result.wordCount) total): \(top)\(result.wordCount > 10 ? ", …" : "")")
        for err in result.errors { print("  ⚠ \(err)") }
        print()
    }
}

// MARK: - Dictionary loading

func loadWordleSet() -> Set<String> {
    guard let url      = Bundle.module.url(forResource: "wordle5", withExtension: "txt"),
          let contents = try? String(contentsOf: url, encoding: .utf8) else {
        fputs("⚠ wordle5.txt not found — 5-letter Wordle tier will be empty\n", stderr)
        return []
    }
    var set = Set<String>()
    for line in contents.split(separator: "\n") {
        let word = line.trimmingCharacters(in: .whitespaces).uppercased()
        guard word.count == 5, word.allSatisfy(\.isLetter) else { continue }
        set.insert(word)
    }
    return set
}

/// Generator trie — three-tier filtered dictionary built from enable.txt + wordle5.txt.
func loadGeneratorTrie(filter: ProfanityFilter, wordleSet: Set<String>) -> Trie {
    guard let url      = Bundle.module.url(forResource: "enable", withExtension: "txt"),
          let contents = try? String(contentsOf: url, encoding: .utf8) else {
        fputs("Fatal: enable.txt not found\n", stderr); exit(1)
    }

    // Tier letter sets
    let tier1Excluded = Set<Character>(["J","K","Q","X","Z"])
    let tier3Allowed  = Set<Character>(["A","B","C","D","E","F","G","H","I",
                                        "L","M","N","O","P","R","S","T","U","W","Y"])
    let vowels        = Set<Character>(["A","E","I","O","U"])

    let trie = Trie()
    var t1 = 0, t2 = 0, t3 = 0

    for line in contents.split(separator: "\n") {
        let word = line.trimmingCharacters(in: .whitespaces).uppercased()
        guard word.count >= 3, !filter.isBlocked(word) else { continue }

        let chars = Array(word)

        switch word.count {
        case 3, 4:
            // Tier 1 — all 3-4 letter words, no J K Q X Z
            guard !chars.contains(where: { tier1Excluded.contains($0) }) else { continue }
            trie.insert(word); t1 += 1

        case 5:
            // Tier 2 — handled from wordleSet below; skip ENABLE 5-letter words
            break

        default:
            // Tier 3 — 6+ letter words: restricted alphabet + vowel minimums
            guard chars.allSatisfy({ tier3Allowed.contains($0) }) else { continue }
            let vowelCount = chars.filter { vowels.contains($0) }.count
            if word.count == 6 {
                guard vowelCount >= 2 else { continue }
            } else {
                guard vowelCount >= 3 else { continue }
            }
            trie.insert(word); t3 += 1
        }
    }

    // Tier 2 — Wordle / SGB 5-letter words
    for word in wordleSet {
        guard !filter.isBlocked(word) else { continue }
        trie.insert(word); t2 += 1
    }

    print("📚 Generator dictionary — T1(3-4): \(t1) | T2(5-letter): \(t2) | T3(6+): \(t3) | Total: \(t1+t2+t3)")
    return trie
}

/// Validator trie — full ENABLE dictionary for comprehensive word counts.
func loadValidatorTrie(filter: ProfanityFilter) -> Trie {
    guard let url      = Bundle.module.url(forResource: "enable", withExtension: "txt"),
          let contents = try? String(contentsOf: url, encoding: .utf8) else {
        fputs("Fatal: enable.txt not found\n", stderr); exit(1)
    }
    let trie = Trie()
    var removed: [String] = []
    for line in contents.split(separator: "\n") {
        let word = line.trimmingCharacters(in: .whitespaces).uppercased()
        guard word.count >= Solver.minLength else { continue }
        if filter.isBlocked(word) { removed.append(word) } else { trie.insert(word) }
    }
    if !removed.isEmpty {
        print("⚠ Profanity filter removed \(removed.count) word(s) from validator dictionary.")
    }
    return trie
}

// MARK: - Helpers

func loadPuzzle(from path: String) -> Puzzle {
    guard let data   = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
        print("Error: cannot read '\(path)'"); exit(1)
    }
    guard let puzzle = try? JSONDecoder().decode(Puzzle.self, from: data) else {
        print("Error: invalid JSON in '\(path)'"); exit(1)
    }
    return puzzle
}

func puzzlesDir() -> String {
    let cwd = FileManager.default.currentDirectoryPath
    if cwd.hasSuffix("PuzzleTool") {
        return (cwd as NSString).appendingPathComponent("../puzzles")
    }
    return (cwd as NSString).appendingPathComponent("puzzles")
}

func todayString() -> String {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    fmt.locale     = Locale(identifier: "en_US_POSIX")
    fmt.timeZone   = TimeZone(identifier: "UTC")
    return fmt.string(from: Date())
}

func isValidDateString(_ s: String) -> Bool {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    fmt.locale     = Locale(identifier: "en_US_POSIX")
    fmt.timeZone   = TimeZone(identifier: "UTC")
    return fmt.date(from: s) != nil
}

func normalizedDateString(_ s: String) -> String {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    fmt.locale     = Locale(identifier: "en_US_POSIX")
    fmt.timeZone   = TimeZone(identifier: "UTC")
    return fmt.date(from: s).map { fmt.string(from: $0) } ?? s
}

/// Right-pads a count to 3 characters for aligned output.
func pad(_ n: Int) -> String { String(format: "%3d", n) }

func printUsage() {
    print("""
    PuzzleTool — Letter Drop daily puzzle generator

    Commands:
      generate [--date YYYY-MM-DD] [--difficulty easy]   Generate puzzle
      validate <filepath>                                  Validate puzzle JSON
      preview  <filepath>                                  Print grid + top words
    """)
}
