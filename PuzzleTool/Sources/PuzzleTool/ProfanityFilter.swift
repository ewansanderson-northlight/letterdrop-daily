// ProfanityFilter.swift — generation-time profanity screening
//
// Loads blocklist.txt from the bundle (one lowercase word per line).
// Used to:
//   1. Strip blocked words from the scoreable word list before finalising a wave.
//   2. Scan the letter-block grid for blocked words readable via any 8-direction
//      DFS path — the same movement the in-game word finder uses.

import Foundation

struct ProfanityFilter {

    /// Uppercase blocked words for O(1) lookup.
    private let blocked: Set<String>
    /// Trie of blocked words (uppercase) for efficient grid scanning.
    private let trie: Trie

    // MARK: - Init

    init() {
        guard let url = Bundle.module.url(forResource: "blocklist", withExtension: "txt") else {
            fputs("Fatal: blocklist.txt not found in bundle\n", stderr)
            exit(1)
        }
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            fputs("Fatal: could not read blocklist.txt\n", stderr)
            exit(1)
        }

        var set = Set<String>()
        let trie = Trie()
        for line in contents.split(separator: "\n") {
            let word = line.trimmingCharacters(in: .whitespaces).uppercased()
            guard !word.isEmpty else { continue }
            set.insert(word)
            trie.insert(word)
        }
        self.blocked = set
        self.trie = trie
    }

    // MARK: - Word check

    /// Returns true if `word` (case-insensitive) is on the blocklist.
    func isBlocked(_ word: String) -> Bool {
        blocked.contains(word.uppercased())
    }

    // MARK: - Grid scan

    /// Returns all blocked words traceable through `grid` via 8-direction DFS
    /// (the same movement rules as the in-game word finder).
    func scanGrid(_ grid: [[String]]) -> [String] {
        var found = Set<String>()
        let size = Solver.gridSize

        for startRow in 0..<size {
            for startCol in 0..<size {
                var visited = Array(repeating: Array(repeating: false, count: size), count: size)
                var path = ""
                dfs(grid: grid, row: startRow, col: startCol,
                    visited: &visited, path: &path, found: &found)
            }
        }

        return Array(found).sorted()
    }

    // MARK: - Private DFS

    private static let directions: [(Int, Int)] = [
        (-1,-1), (-1, 0), (-1, 1),
        ( 0,-1),          ( 0, 1),
        ( 1,-1), ( 1, 0), ( 1, 1)
    ]

    private func dfs(grid: [[String]],
                     row: Int,
                     col: Int,
                     visited: inout [[Bool]],
                     path: inout String,
                     found: inout Set<String>) {
        let letter = Character(grid[row][col])
        path.append(letter)
        visited[row][col] = true

        defer {
            path.removeLast()
            visited[row][col] = false
        }

        guard trie.hasPrefix(path) else { return }

        if trie.contains(path) {
            found.insert(path)
        }

        let size = Solver.gridSize
        for (dr, dc) in ProfanityFilter.directions {
            let nr = row + dr
            let nc = col + dc
            guard nr >= 0, nr < size, nc >= 0, nc < size else { continue }
            guard !visited[nr][nc] else { continue }
            dfs(grid: grid, row: nr, col: nc,
                visited: &visited, path: &path, found: &found)
        }
    }
}
