// Generator.swift — deterministic daily puzzle generator
//
// Uses a seeded LCG so the same date always produces the same puzzle.
// Letter distribution is Scrabble-weighted with centre-3×3 vowel boost.

import Foundation

struct Generator {

    // MARK: - Public entry point

    static func generate(dateString: String,
                         trie: Trie,
                         filter: ProfanityFilter,
                         easyMode: Bool = false) throws -> Puzzle {
        let seed = dateSeed(dateString)
        let layout: [DifficultyLevel] = [.green, .amber, .red, .green, .amber, .red]

        var waves: [Wave] = []
        for (i, difficulty) in layout.enumerated() {
            let wave = try generateWave(difficulty: difficulty,
                                        waveSeed: seed &+ UInt64(i * 1_000_003),
                                        trie: trie,
                                        filter: filter,
                                        easyMode: easyMode)
            waves.append(wave)
        }

        return Puzzle(date: dateString, waves: waves)
    }

    // MARK: - Single wave

    private static func generateWave(difficulty: DifficultyLevel,
                                     waveSeed: UInt64,
                                     trie: Trie,
                                     filter: ProfanityFilter,
                                     easyMode: Bool = false,
                                     maxRetries: Int = 800) throws -> Wave {
        // Easy mode raises all waves to green-level minimums
        let minWords  = easyMode ? max(difficulty.minWords,  40) : difficulty.minWords
        let min4Plus  = easyMode ? 15                            : difficulty.min4PlusWords
        let min6Plus  = easyMode ? max(difficulty.min6PlusWords, 2) : difficulty.min6PlusWords

        for attempt in 0..<maxRetries {
            var innerRNG = LCG(seed: waveSeed &+ UInt64(attempt) &* 999_983)
            let grid = randomGrid(rng: &innerRNG, easyMode: easyMode)

            let blockedInGrid = filter.scanGrid(grid)
            if !blockedInGrid.isEmpty { continue }

            let words = Solver.solve(grid: grid, trie: trie)

            let count4Plus = words.filter { $0.count >= 4 }.count
            let count6Plus = words.filter { $0.count >= 6 }.count

            guard words.count >= minWords   else { continue }
            guard count4Plus  >= min4Plus   else { continue }
            guard count6Plus  >= min6Plus   else { continue }

            // Distribution quality gate: majority of findable words should be 3–6 letters.
            // Avoid grids dominated by very long obscure paths.
            let shortWords    = words.filter { (3...6).contains($0.count) }
            let veryLongWords = words.filter { $0.count >= 9 }
            let shortRatio    = Double(shortWords.count) / Double(words.count)

            let enforceQuality = attempt < (maxRetries * 3 / 4)
            if enforceQuality {
                guard shortRatio    >= 0.60 else { continue }
                guard veryLongWords.isEmpty  else { continue }
            }

            let target = words.first { (4...6).contains($0.count) } ?? words[0]
            return Wave(grid: grid, targetWord: target, difficulty: difficulty)
        }

        throw GeneratorError.thresholdNotMet(difficulty: difficulty, maxRetries: maxRetries)
    }

    // MARK: - Random grid (centre-3×3 gets extra vowels)

    private static func randomGrid(rng: inout LCG, easyMode: Bool = false) -> [[String]] {
        var rows: [[String]] = []
        for r in 0..<5 {
            var row: [String] = []
            for c in 0..<5 {
                let isCentre = (1...3).contains(r) && (1...3).contains(c)
                let pool: [Character]
                if isCentre {
                    pool = easyMode ? centreLetterPoolEasy : centreLetterPool
                } else {
                    pool = letterPool
                }
                let idx = Int(rng.next() % UInt64(pool.count))
                row.append(String(pool[idx]))
            }
            rows.append(row)
        }
        return rows
    }

    // MARK: - Letter pools

    // Base pool — boosted RSTLN, halved V W, rare consonants kept at 1
    private static let letterPool: [Character] = {
        let distribution: [(Character, Int)] = [
            ("E", 12), ("A", 9), ("I", 9), ("O", 8),
            ("N", 7),  ("R", 7), ("T", 7),
            ("L", 5),  ("S", 5), ("U", 4), ("D", 4), ("G", 3),
            ("B", 2),  ("C", 2), ("F", 2), ("H", 2), ("M", 2),
            ("P", 2),  ("Y", 2),
            ("V", 1),  ("W", 1), ("J", 1), ("K", 1),
            ("Q", 1),  ("X", 1), ("Z", 1),
        ]
        return distribution.flatMap { Array(repeating: $0.0, count: $0.1) }
    }()

    // Centre 3×3 pool — adds extra vowels (~52 % vowels vs ~42 % for edges)
    private static let centreLetterPool: [Character] = {
        var pool = letterPool
        let extra: [(Character, Int)] = [("E",6),("A",5),("I",5),("O",4),("U",2)]
        for (ch, n) in extra { pool.append(contentsOf: Array(repeating: ch, count: n)) }
        return pool
    }()

    // Easy-mode centre pool — additional ~5 pp vowel boost on top
    private static let centreLetterPoolEasy: [Character] = {
        var pool = centreLetterPool
        let extra: [(Character, Int)] = [("E",3),("A",3),("I",3),("O",2),("U",1)]
        for (ch, n) in extra { pool.append(contentsOf: Array(repeating: ch, count: n)) }
        return pool
    }()

    // MARK: - Date → seed

    private static func dateSeed(_ date: String) -> UInt64 {
        let digits = date.filter { $0.isNumber }
        let base   = UInt64(digits) ?? 20240101
        var x = base &+ 0x9e3779b97f4a7c15
        x = (x ^ (x >> 30)) &* 0xbf58476d1ce4e5b9
        x = (x ^ (x >> 27)) &* 0x94d049bb133111eb
        return x ^ (x >> 31)
    }
}

// MARK: - LCG

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
