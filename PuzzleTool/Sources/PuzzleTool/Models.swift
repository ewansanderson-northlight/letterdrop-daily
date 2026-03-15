// Models.swift — shared data types for PuzzleTool

import Foundation

// MARK: - Puzzle / Wave

/// Top-level JSON written to puzzles/puzzle-YYYY-MM-DD.json
struct Puzzle: Codable {
    let date: String          // "YYYY-MM-DD"
    let waves: [Wave]         // exactly 6
}

/// One 5×5 wave.  `grid` is row-major (grid[row][col]).
struct Wave: Codable {
    let grid: [[String]]      // 5 rows × 5 cols, each cell is one uppercase letter
    let targetWord: String    // solution word the puzzle is designed around
    let difficulty: DifficultyLevel

    /// Flat array of all 25 letters, row-major.
    var flat: [String] { grid.flatMap { $0 } }
}

// MARK: - Difficulty

enum DifficultyLevel: String, Codable, CaseIterable {
    case green  // easy  — ≥30 solvable words, ≥1 word of length 6+
    case amber  // medium — ≥20 solvable words, ≥1 word of length 6+
    case red    // hard  — ≥12 solvable words, ≥1 word of length 6+

    var minWords: Int {
        switch self {
        case .green: return 30
        case .amber: return 20
        case .red:   return 12
        }
    }
}

// MARK: - Validation result

struct ValidationResult {
    let isValid: Bool
    let errors: [String]
    let wordCount: Int
    let longestWord: String
    let allWords: [String]   // sorted by length desc, then alpha
}
