//
//  ScoreCalculator.swift
//  Letter Drop
//
//  Length-based scoring as per spec:
//    3 letters =  3 pts
//    4 letters =  5 pts
//    5 letters =  8 pts
//    6 letters = 12 pts
//    7+ letters = 16 pts
//

import Foundation

enum ScoreCalculator {

    static func score(for word: String) -> Int {
        switch word.count {
        case 3:     return 3
        case 4:     return 5
        case 5:     return 8
        case 6:     return 12
        case 7...:  return 16
        default:    return 0
        }
    }
}
