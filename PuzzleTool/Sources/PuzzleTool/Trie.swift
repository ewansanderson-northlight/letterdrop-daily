// Trie.swift — prefix trie loaded from enable.txt for solver pruning

final class Trie {

    private final class Node {
        var children: [Character: Node] = [:]
        var isTerminal = false
    }

    private let root = Node()

    // MARK: - Build

    func insert(_ word: String) {
        var node = root
        for ch in word {
            if let next = node.children[ch] {
                node = next
            } else {
                let next = Node()
                node.children[ch] = next
                node = next
            }
        }
        node.isTerminal = true
    }

    // MARK: - Query

    /// True if `prefix` is a valid prefix of at least one word in the trie.
    func hasPrefix(_ prefix: String) -> Bool {
        var node = root
        for ch in prefix {
            guard let next = node.children[ch] else { return false }
            node = next
        }
        return true
    }

    /// True if the exact word exists in the trie.
    func contains(_ word: String) -> Bool {
        var node = root
        for ch in word {
            guard let next = node.children[ch] else { return false }
            node = next
        }
        return node.isTerminal
    }
}
