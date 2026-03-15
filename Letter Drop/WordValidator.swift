//
//  WordValidator.swift
//  Letter Drop
//
//  Validates English words using the ENABLE (Enhanced North American Benchmark
//  Lexicon) word list, bundled as "enable.txt" in the app target.
//
//  To add the word list:
//    1. Download the ENABLE list (public domain):
//       https://www.wordgamedictionary.com/enable/download/enable.txt
//    2. Drag "enable.txt" into the Xcode project, ensuring it is added to the
//       "Letter Drop" target (check the box in the file inspector).
//    3. The validator loads it once at app launch into a Set<String> for O(1)
//       lookup on every word check.
//

import Foundation

final class WordValidator {

    static let shared = WordValidator()

    private var wordSet:    Set<String> = []
    private var sortedWords: [String]   = []   // for O(log n) prefix checks

    private init() {
        loadWordList()
    }

    // MARK: - Prefix check (used by WaveGridSolver for DFS pruning)

    /// True if any word in the list starts with `prefix`.  O(log n) binary search.
    func hasPrefix(_ prefix: String) -> Bool {
        guard !prefix.isEmpty else { return true }
        var lo = 0, hi = sortedWords.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if sortedWords[mid] < prefix { lo = mid + 1 } else { hi = mid }
        }
        guard lo < sortedWords.count else { return false }
        return sortedWords[lo].hasPrefix(prefix)
    }

    // MARK: - Validation

    /// Returns true if `word` is a valid English word of at least 3 letters.
    func isValid(_ word: String) -> Bool {
        guard word.count >= 3 else { return false }
        let upper = word.uppercased()

        #if DEBUG
        // Accept any 3+ letter word so the UI can be tested without the word list.
        // Remove this branch once enable.txt is bundled.
        if wordSet.isEmpty { return upper.count >= 3 }
        #endif

        return wordSet.contains(upper)
    }

    // MARK: - Loading

    private func loadWordList() {
        guard let url = Bundle.main.url(forResource: "enable", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8)
        else { return }

        let words = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }

        wordSet     = Set(words)
        sortedWords = words.sorted()
    }
}
