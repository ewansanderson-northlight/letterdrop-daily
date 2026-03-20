//
//  ScoreCalculator.swift
//  Letter Drop
//
//  Length-based scoring: word.count × 10.
//  Streak bonuses are additive and applied in GameScene/GameState.
//

import Foundation

enum ScoreCalculator {

    static func score(for word: String) -> Int {
        return word.count * 10
    }
}
