// Models.swift — shared data types for PuzzleTool

import Foundation

// MARK: - Puzzle / Wave

struct Puzzle: Codable {
    let date: String          // "YYYY-MM-DD"
    let waves: [Wave]         // exactly 6
}

struct Wave: Codable {
    let grid: [[String]]      // 5 rows × 5 cols, each cell is one uppercase letter
    let targetWord: String
    let difficulty: DifficultyLevel

    var flat: [String] { grid.flatMap { $0 } }
}

// MARK: - Difficulty

enum DifficultyLevel: String, Codable, CaseIterable {
    case green  // easy   — ≥40 words, ≥12 four-letter+, ≥2 six-letter+
    case amber  // medium — ≥28 words, ≥8  four-letter+, ≥1 six-letter+
    case red    // hard   — ≥18 words, ≥5  four-letter+, ≥1 six-letter+

    var minWords: Int {
        switch self {
        case .green: return 40
        case .amber: return 28
        case .red:   return 18
        }
    }

    var min4PlusWords: Int {
        switch self {
        case .green: return 12
        case .amber: return 8
        case .red:   return 5
        }
    }

    var min6PlusWords: Int {
        switch self {
        case .green: return 2
        case .amber: return 1
        case .red:   return 1
        }
    }

    var findabilityTarget: Int {
        switch self {
        case .green: return 60
        case .amber: return 40
        case .red:   return 25
        }
    }
}

// MARK: - Validation result

struct ValidationResult {
    let isValid: Bool
    let errors: [String]
    let wordCount: Int
    let longestWord: String
    let allWords: [String]      // sorted by length desc, then alpha

    // Findability breakdown
    let words3: Int
    let words4: Int
    let words5Wordle: Int       // 5-letter words present in the Wordle/SGB tier
    let words5EnableOnly: Int   // 5-letter words in ENABLE but not Wordle tier
    let words6Plus: Int
    let findabilityScore: Int   // (words4×2) + (words5×3) + (words6Plus×5), capped at 100

    // Convenience
    var words5Total: Int { words5Wordle + words5EnableOnly }

    // Default initialiser for error-only results
    init(isValid: Bool, errors: [String],
         wordCount: Int, longestWord: String, allWords: [String],
         words3: Int = 0, words4: Int = 0,
         words5Wordle: Int = 0, words5EnableOnly: Int = 0,
         words6Plus: Int = 0, findabilityScore: Int = 0) {
        self.isValid          = isValid
        self.errors           = errors
        self.wordCount        = wordCount
        self.longestWord      = longestWord
        self.allWords         = allWords
        self.words3           = words3
        self.words4           = words4
        self.words5Wordle     = words5Wordle
        self.words5EnableOnly = words5EnableOnly
        self.words6Plus       = words6Plus
        self.findabilityScore = findabilityScore
    }
}
