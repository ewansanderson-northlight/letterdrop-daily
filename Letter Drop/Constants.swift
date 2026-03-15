//
//  Constants.swift
//  Letter Drop
//

import SwiftUI

enum Constants {

    enum Colors {
        static let background     = Color(red: 0.09, green: 0.12, blue: 0.22)
        static let tile           = Color(red: 0.96, green: 0.94, blue: 0.88)
        static let tileText       = Color(red: 0.13, green: 0.13, blue: 0.18)
        static let tileShadow     = Color(red: 0.05, green: 0.07, blue: 0.14)
        static let success        = Color(red: 0.35, green: 0.78, blue: 0.55)
        static let failure        = Color(red: 0.90, green: 0.35, blue: 0.35)
        static let trayBackground = Color(red: 0.12, green: 0.16, blue: 0.28)
        static let gold           = Color(red: 1.00, green: 0.80, blue: 0.20)
        /// Warm orange — used for <15 s low-time warning.
        static let warning        = Color(red: 1.00, green: 0.58, blue: 0.08)
        /// Deep antique gold (#D4A017) — used for all score numbers on the results screen.
        static let scoreGold      = Color(red: 0.831, green: 0.627, blue: 0.090)
        /// Header bar background — slightly darker than the game field to create clear separation.
        static let headerBar      = Color(red: 0.06, green: 0.08, blue: 0.17)
    }

    enum Fonts {
        static func rounded(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }
    }

    enum Game {
        /// Per-block time limits in seconds — blocks 1–6, increasing difficulty.
        static let blockTimeLimits: [Double] = [28, 24, 22, 18, 16, 12]
        static let wavesPerRound    = 6
        static let gridSize         = 5
        static let tileGap: CGFloat = 6
        static let tileMargin: CGFloat = 8      // horizontal margin on each side
        static let tileCorner: CGFloat = 10
    }

    // Keep Layout for backward-compat with LetterTile (still in project)
    enum Layout {
        static let tileSize: CGFloat    = 56
        static let tileCorner: CGFloat  = 12
        static let tilePadding: CGFloat = 8
    }
}

/// Scrabble-style point values for each letter.
enum LetterValues {
    static let values: [Character: Int] = [
        "A": 1, "E": 1, "I": 1, "O": 1, "U": 1,
        "L": 1, "N": 1, "S": 1, "T": 1, "R": 1,
        "D": 2, "G": 2,
        "B": 3, "C": 3, "M": 3, "P": 3,
        "F": 4, "H": 4, "V": 4, "W": 4, "Y": 4,
        "K": 5,
        "J": 8, "X": 8,
        "Q": 10, "Z": 10
    ]

    static func value(for letter: String) -> Int {
        guard let char = letter.uppercased().first else { return 1 }
        return values[char] ?? 1
    }
}
