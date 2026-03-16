// AnalyticsManager.swift
// Privacy-first PostHog wrapper for your daily word game.

import Foundation
import PostHog

enum GameEvent {
    case appOpened(date: String)
    case puzzleStarted(date: String)
    case puzzleCompleted(date: String, attempts: Int, success: Bool)
    case puzzleAbandoned(date: String, attempts: Int)
    case resultShared(date: String)
    case howToPlayViewed

    var name: String {
        switch self {
        case .appOpened:        return "app_opened"
        case .puzzleStarted:    return "puzzle_started"
        case .puzzleCompleted:  return "puzzle_completed"
        case .puzzleAbandoned:  return "puzzle_abandoned"
        case .resultShared:     return "result_shared"
        case .howToPlayViewed:  return "how_to_play_viewed"
        }
    }

    var properties: [String: Any] {
        switch self {
        case .appOpened(let date):
            return ["puzzle_date": date]
        case .puzzleStarted(let date):
            return ["puzzle_date": date]
        case .puzzleCompleted(let date, let attempts, let success):
            return ["puzzle_date": date, "attempts": attempts, "success": success]
        case .puzzleAbandoned(let date, let attempts):
            return ["puzzle_date": date, "attempts_before_quit": attempts]
        case .resultShared(let date):
            return ["puzzle_date": date]
        case .howToPlayViewed:
            return [:]
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
