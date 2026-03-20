// AnalyticsManager.swift
// Privacy-first PostHog wrapper for your daily word game.

import Foundation
import PostHog

enum GameEvent {
    case appOpened(date: String)
    case puzzleStarted(date: String)
    case puzzleCompleted(date: String, score: Int, maxScore: Int,
                         wordsFound: Int, bestWord: String, wavesScored: Int)
    case puzzleAbandoned(score: Int, waveIndex: Int)
    case resultShared(date: String)
    case howToPlayViewed
    case streakUpdated(currentStreak: Int, isNewBest: Bool)

    var name: String {
        switch self {
        case .appOpened:        return "app_opened"
        case .puzzleStarted:    return "puzzle_started"
        case .puzzleCompleted:  return "puzzle_completed"
        case .puzzleAbandoned:  return "puzzle_abandoned"
        case .resultShared:     return "result_shared"
        case .howToPlayViewed:  return "how_to_play_viewed"
        case .streakUpdated:    return "streak_updated"
        }
    }

    var properties: [String: Any] {
        switch self {
        case .appOpened(let date):
            return ["puzzle_date": date]
        case .puzzleStarted(let date):
            return ["puzzle_date": date]
        case .puzzleCompleted(let date, let score, let maxScore,
                              let wordsFound, let bestWord, let wavesScored):
            return [
                "puzzle_date":  date,
                "score":        score,
                "max_score":    maxScore,
                "words_found":  wordsFound,
                "best_word":    bestWord,
                "waves_scored": wavesScored,
            ]
        case .puzzleAbandoned(let score, let waveIndex):
            return [
                "score_at_abandonment": score,
                "wave_at_abandonment":  waveIndex,
            ]
        case .resultShared(let date):
            return ["puzzle_date": date]
        case .howToPlayViewed:
            return [:]
        case .streakUpdated(let currentStreak, let isNewBest):
            return [
                "current_streak": currentStreak,
                "is_new_best":    isNewBest,
            ]
        }
    }
}

final class AnalyticsManager {
    static let shared = AnalyticsManager()
    private init() {}

    func setup() {
        let config = PostHogConfig(
            apiKey: Secrets.postHogApiKey,
            host: "https://eu.i.posthog.com"
        )
        config.captureScreenViews = false
        config.captureApplicationLifecycleEvents = false
        config.sessionReplay = false
        PostHogSDK.shared.setup(config)
    }

    func track(_ event: GameEvent) {
        PostHogSDK.shared.capture(event.name, properties: event.properties)
    }
}
