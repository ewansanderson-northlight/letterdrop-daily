// Validator.swift — schema + difficulty validation for a Puzzle

import Foundation

struct Validator {

    private let trie: Trie
    private let filter: ProfanityFilter
    private let wordleSet: Set<String>   // for Wordle-tier annotation

    init(trie: Trie, filter: ProfanityFilter, wordleSet: Set<String> = []) {
        self.trie      = trie
        self.filter    = filter
        self.wordleSet = wordleSet
    }

    // MARK: - Full puzzle

    func validate(puzzle: Puzzle) -> [ValidationResult] {
        var results: [ValidationResult] = []

        if puzzle.date.isEmpty {
            results.append(schemaError("Missing date")); return results
        }
        if puzzle.waves.count != 6 {
            results.append(schemaError("Expected 6 waves, got \(puzzle.waves.count)")); return results
        }

        for (i, wave) in puzzle.waves.enumerated() {
            results.append(validateWave(wave, index: i))
        }
        return results
    }

    // MARK: - Single wave

    func validateWave(_ wave: Wave, index: Int) -> ValidationResult {
        var errors: [String] = []

        // Dimension checks
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
        let words       = Solver.solve(grid: wave.grid, trie: trie)
        let longestWord = words.first ?? ""

        // Bucket words by length
        let w3        = words.filter { $0.count == 3 }
        let w4        = words.filter { $0.count == 4 }
        let w5Wordle  = words.filter { $0.count == 5 &&  wordleSet.contains($0) }
        let w5Enable  = words.filter { $0.count == 5 && !wordleSet.contains($0) }
        let w6Plus    = words.filter { $0.count >= 6 }
        let w5All     = w5Wordle + w5Enable

        // Findability score
        let findability = min(w4.count * 2 + w5All.count * 3 + w6Plus.count * 5, 100)

        // Difficulty thresholds
        if words.count < wave.difficulty.minWords {
            errors.append("Wave \(index) [\(wave.difficulty.rawValue)]: needs ≥\(wave.difficulty.minWords) words, found \(words.count)")
        }
        if w4.count + w5All.count + w6Plus.count < wave.difficulty.min4PlusWords {
            errors.append("Wave \(index) [\(wave.difficulty.rawValue)]: needs ≥\(wave.difficulty.min4PlusWords) four-letter+ words, found \(w4.count + w5All.count + w6Plus.count)")
        }
        if w6Plus.count < wave.difficulty.min6PlusWords {
            errors.append("Wave \(index) [\(wave.difficulty.rawValue)]: needs ≥\(wave.difficulty.min6PlusWords) six-letter+ words, found \(w6Plus.count)")
        }

        // Target word present
        if !words.contains(wave.targetWord) {
            errors.append("Wave \(index): targetWord '\(wave.targetWord)' not solvable in grid")
        }

        // Profanity
        for word in words where filter.isBlocked(word) {
            errors.append("Wave \(index): blocked word '\(word)' in scoreable word list")
        }
        for word in filter.scanGrid(wave.grid) {
            errors.append("Wave \(index): blocked word '\(word)' readable in block grid")
        }

        return ValidationResult(
            isValid:          errors.isEmpty,
            errors:           errors,
            wordCount:        words.count,
            longestWord:      longestWord,
            allWords:         words,
            words3:           w3.count,
            words4:           w4.count,
            words5Wordle:     w5Wordle.count,
            words5EnableOnly: w5Enable.count,
            words6Plus:       w6Plus.count,
            findabilityScore: findability
        )
    }

    // MARK: - Helper

    private func schemaError(_ msg: String) -> ValidationResult {
        ValidationResult(isValid: false, errors: [msg],
                         wordCount: 0, longestWord: "", allWords: [])
    }
}
