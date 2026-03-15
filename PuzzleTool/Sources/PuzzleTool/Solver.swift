// Solver.swift — DFS word-finder over a 5×5 grid using the ENABLE trie

import Foundation

struct Solver {

    static let gridSize = 5
    static let minLength = 3

    private static let directions: [(Int, Int)] = [
        (-1,-1),(-1, 0),(-1, 1),
        ( 0,-1),        ( 0, 1),
        ( 1,-1),( 1, 0),( 1, 1)
    ]

    /// Returns all valid words found in `grid` (row-major, 5×5).
    static func solve(grid: [[String]], trie: Trie) -> [String] {
        var found = Set<String>()

        for startRow in 0..<gridSize {
            for startCol in 0..<gridSize {
                var visited = Array(repeating: Array(repeating: false, count: gridSize), count: gridSize)
                var path = ""
                dfs(grid: grid, trie: trie,
                    row: startRow, col: startCol,
                    visited: &visited, path: &path,
                    found: &found)
            }
        }

        return Array(found).sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs < rhs
        }
    }

    private static func dfs(grid: [[String]],
                            trie: Trie,
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

        if path.count >= minLength && trie.contains(path) {
            found.insert(path)
        }

        for (dr, dc) in directions {
            let nr = row + dr
            let nc = col + dc
            guard nr >= 0, nr < gridSize, nc >= 0, nc < gridSize else { continue }
            guard !visited[nr][nc] else { continue }
            dfs(grid: grid, trie: trie,
                row: nr, col: nc,
                visited: &visited, path: &path,
                found: &found)
        }
    }
}
