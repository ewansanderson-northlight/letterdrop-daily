//
//  HapticManager.swift
//  Letter Drop
//

import UIKit

enum HapticManager {

    /// Soft tap — finger lands on a tile during tracing.
    static func selectTile() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Success notification — valid word accepted.
    static func validWord() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Error buzz — invalid word rejected.
    static func invalidWord() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    /// Medium pulse — wave speed tier increases (waves 3 and 5).
    static func waveSpeedUp() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Heavy thud — slow-motion activates.
    static func slowMoActivate() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    // MARK: - Legacy (kept for LetterTile / old scene if still referenced)

    static func collectLetter() { selectTile() }
    static func removeLetter()  { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func submitWord()    { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
}
