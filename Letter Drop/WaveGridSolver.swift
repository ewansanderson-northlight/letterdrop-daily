//
//  WaveGridSolver.swift
//  Letter Drop
//
//  Boggle-style DFS solver over a 5×5 grid.
//  Used by: best-word-flash (#3), results Today's Best (#8), Score vs Max (#9).
//

import Foundation

enum WaveGridSolver {

    private static let gridSize = 5
    private static let minLength = 3

    private static let directions: [(Int, Int)] = [
        (-1,-1),(-1, 0),(-1, 1),
        ( 0,-1),        ( 0, 1),
        ( 1,-1),( 1, 0),( 1, 1)
    ]

    // MARK: - Public API

    /// Returns the highest-scoring valid word reachable in the flat 25-letter grid.
    /// Runs synchronously — call from a background queue for large workloads.
    static func bestWord(in flat: [String]) -> (word: String, score: Int)? {
        let grid = reshape(flat)
        let validator = WordValidator.shared

        var bestWord: String?
        var bestScore = 0

        for r in 0..<gridSize {
            for c in 0..<gridSize {
                var visited = Array(repeating: Array(repeating: false, count: gridSize),
                                    count: gridSize)
                var path = ""
                dfs(grid: grid, validator: validator,
                    row: r, col: c,
                    visited: &visited, path: &path,
                    bestWord: &bestWord, bestScore: &bestScore)
            }
        }

        guard let word = bestWord else { return nil }
        return (word, bestScore)
    }

    // MARK: - DFS

    private static func dfs(grid: [[String]],
                            validator: WordValidator,
                            row: Int, col: Int,
                            visited: inout [[Bool]],
                            path: inout String,
                            bestWord: inout String?,
                            bestScore: inout Int) {
        path.append(Character(grid[row][col]))
        visited[row][col] = true

        defer {
            path.removeLast()
            visited[row][col] = false
        }

        guard validator.hasPrefix(path) else { return }

        if path.count >= minLength && validator.isValid(path) {
            let s = ScoreCalculator.score(for: path)
            if s > bestScore { bestScore = s; bestWord = path }
        }

        for (dr, dc) in directions {
            let nr = row + dr, nc = col + dc
            guard nr >= 0, nr < gridSize, nc >= 0, nc < gridSize,
                  !visited[nr][nc] else { continue }
            dfs(grid: grid, validator: validator,
                row: nr, col: nc,
                visited: &visited, path: &path,
                bestWord: &bestWord, bestScore: &bestScore)
        }
    }

    // MARK: - Helpers

    private static func reshape(_ flat: [String]) -> [[String]] {
        (0..<gridSize).map { r in
            Array(flat[(r * gridSize)..<(r * gridSize + gridSize)])
        }
    }
}
