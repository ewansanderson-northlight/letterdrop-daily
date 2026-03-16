// Validator.swift — schema + difficulty validation for a Puzzle

import Foundation

struct Validator {

    private let trie: Trie
    private let filter: ProfanityFilter

    init(trie: Trie, filter: ProfanityFilter) {
        self.trie = trie
        self.filter = filter
    }

    // MARK: - Full puzzle

    func validate(puzzle: Puzzle) -> [ValidationResult] {
        var results: [ValidationResult] = []

        // Schema checks
        if puzzle.date.isEmpty {
            results.append(schemaError("Missing date"))
            return results
        }
        if puzzle.waves.count != 6 {
            results.append(schemaError("Expected 6 waves, got \(puzzle.waves.count)"))
            return results
        }

        for (i, wave) in puzzle.waves.enumerated() {
            let r = validateWave(wave, index: i)
            results.append(r)
        }
        return results
    }

    // MARK: - Single wave

    func validateWave(_ wave: Wave, index: Int) -> ValidationResult {
        var errors: [String] = []

        // Dimension check
        if wave.grid.count != 5 {
            errors.append("Wave \(index): expected 5 rows, got \(wave.grid.count)")
            return ValidationResult(isValid: false, errors: errors,
                                    wordCount: 0, longestWord: "", allWords: [])
        }
        for (r, row) in wave.grid.enumerated() {
            if row.count != 5 {
                errors.append("Wave \(index) row \(r): expected 5 cols, got \(row.count)")
            }
            for cell in row {
                if cell.count != 1 || !cell.first!.isLetter {
                    errors.append("Wave \(index): invalid cell '\(cell)'")
                }
            }
        }
        guard errors.isEmpty else {
            return ValidationResult(isValid: false, errors: errors,
                                    wordCount: 0, longestWord: "", allWords: [])
        }

        // Solve
        let words = Solver.solve(grid: wave.grid, trie: trie)
        let longestWord = words.first ?? ""
        let hasLongWord = words.contains { $0.count >= 6 }

        // Difficulty threshold
        if words.count < wave.difficulty.minWords {
            errors.append("Wave \(index) [\(wave.difficulty.rawValue)]: needs ≥\(wave.difficulty.minWords) words, found \(words.count)")
        }
        if !hasLongWord {
            errors.append("Wave \(index) [\(wave.difficulty.rawValue)]: needs ≥1 word of length 6+, none found")
        }

        // Target word present
        if !words.contains(wave.targetWord) {
            errors.append("Wave \(index): targetWord '\(wave.targetWord)' not solvable in grid")
        }

        // Profanity — word list
        let blockedWords = words.filter { filter.isBlocked($0) }
        for word in blockedWords {
            errors.append("Wave \(index): blocked word '\(word)' in scoreable word list")
        }

        // Profanity — grid
        let blockedInGrid = filter.scanGrid(wave.grid)
        for word in blockedInGrid {
            errors.append("Wave \(index): blocked word '\(word)' readable in block grid")
        }

        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            wordCount: words.count,
            longestWord: longestWord,
            allWords: words
        )
    }

    // MARK: - Helpers

    private func schemaError(_ msg: String) -> ValidationResult {
        ValidationResult(isValid: false, errors: [msg],
                         wordCount: 0, longestWord: "", allWords: [])
    }
}
