// Generator.swift — deterministic daily puzzle generator
//
// Uses a seeded LCG so the same date always produces the same puzzle.
// Letter distribution is Scrabble-weighted.

import Foundation

struct Generator {

    // MARK: - Public entry point

    /// Generate a full 6-wave puzzle for `dateString` ("YYYY-MM-DD").
    /// Throws if any wave fails to meet its difficulty threshold after `maxRetries`.
    static func generate(dateString: String, trie: Trie) throws -> Puzzle {
        let seed = dateSeed(dateString)
        let layout: [DifficultyLevel] = [.green, .amber, .red, .green, .amber, .red]

        var waves: [Wave] = []
        for (i, difficulty) in layout.enumerated() {
            let wave = try generateWave(difficulty: difficulty,
                                        waveSeed: seed &+ UInt64(i * 1_000_003),
                                        trie: trie)
            waves.append(wave)
        }

        return Puzzle(date: dateString, waves: waves)
    }

    // MARK: - Single wave

    private static func generateWave(difficulty: DifficultyLevel,
                                     waveSeed: UInt64,
                                     trie: Trie,
                                     maxRetries: Int = 400) throws -> Wave {
        for attempt in 0..<maxRetries {
            // Each retry gets its own sub-seed so we don't repeat identical grids
            var innerRNG = LCG(seed: waveSeed &+ UInt64(attempt) &* 999_983)
            let grid = randomGrid(rng: &innerRNG)

            let words = Solver.solve(grid: grid, trie: trie)
            let hasLongWord = words.contains { $0.count >= 6 }

            guard words.count >= difficulty.minWords, hasLongWord else { continue }

            // Pick a target word: prefer length 5–7, else longest available
            let target = words.first { (5...7).contains($0.count) } ?? words[0]

            return Wave(grid: grid, targetWord: target, difficulty: difficulty)
        }

        throw GeneratorError.thresholdNotMet(difficulty: difficulty, maxRetries: maxRetries)
    }

    // MARK: - Random grid

    private static func randomGrid(rng: inout LCG) -> [[String]] {
        var rows: [[String]] = []
        for _ in 0..<5 {
            var row: [String] = []
            for _ in 0..<5 {
                row.append(String(weightedLetter(rng: &rng)))
            }
            rows.append(row)
        }
        return rows
    }

    // MARK: - Scrabble-weighted letter picker

    private static let letterPool: [Character] = {
        let distribution: [(Character, Int)] = [
            ("E", 12), ("A", 9), ("I", 9), ("O", 8), ("N", 6),
            ("R", 6),  ("T", 6), ("L", 4), ("S", 4), ("U", 4),
            ("D", 4),  ("G", 3), ("B", 2), ("C", 2), ("M", 2),
            ("P", 2),  ("F", 2), ("H", 2), ("V", 2), ("W", 2),
            ("Y", 2),  ("K", 1), ("J", 1), ("X", 1), ("Q", 1),
            ("Z", 1)
        ]
        return distribution.flatMap { (ch, count) in Array(repeating: ch, count: count) }
    }()

    private static func weightedLetter(rng: inout LCG) -> Character {
        let idx = Int(rng.next() % UInt64(letterPool.count))
        return letterPool[idx]
    }

    // MARK: - Date → seed

    /// Converts "YYYY-MM-DD" to a stable UInt64 seed.
    private static func dateSeed(_ date: String) -> UInt64 {
        // Remove hyphens, parse as integer, then mix bits
        let digits = date.filter { $0.isNumber }
        let base   = UInt64(digits) ?? 20240101
        // Simple bit-mix (SplitMix64 finaliser)
        var x = base &+ 0x9e3779b97f4a7c15
        x = (x ^ (x >> 30)) &* 0xbf58476d1ce4e5b9
        x = (x ^ (x >> 27)) &* 0x94d049bb133111eb
        return x ^ (x >> 31)
    }
}

// MARK: - LCG (Linear Congruential Generator)

/// Simple, deterministic 64-bit LCG.  Same seed → same sequence.
struct LCG {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 1 : seed }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}

// MARK: - Errors

enum GeneratorError: Error, CustomStringConvertible {
    case thresholdNotMet(difficulty: DifficultyLevel, maxRetries: Int)

    var description: String {
        switch self {
        case .thresholdNotMet(let d, let r):
            return "Could not generate \(d.rawValue) wave after \(r) attempts"
        }
    }
}
