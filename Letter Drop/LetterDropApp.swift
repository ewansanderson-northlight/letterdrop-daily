//
//  LetterDropApp.swift
//  Letter Drop
//

import SwiftUI
import PostHog

@main
struct LetterDropApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var gameState = GameState()

    init() {
        AnalyticsManager.shared.setup()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let today = fmt.string(from: Date())
        AnalyticsManager.shared.track(.appOpened(date: today))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(gameState)
        }
    }
}

/// Routes between screens based on GameState.phase
struct RootView: View {
    @EnvironmentObject var gameState: GameState

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            switch gameState.phase {
            case .loading:
                LoadingView()
            case .fetchError:
                FetchErrorView()
            case .menu:
                MainMenuView()
            case .playing:
                GamePlayView()
            case .results:
                ResultsView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: gameState.phase)
    }
}

// MARK: - Loading screen

private struct LoadingView: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Constants.Colors.tile)
                .scaleEffect(1.4)
                .scaleEffect(pulse ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }

            Text("Loading today's puzzle…")
                .font(Constants.Fonts.rounded(16, weight: .medium))
                .foregroundStyle(Constants.Colors.tile.opacity(0.55))
        }
    }
}

// MARK: - Fetch-error screen

private struct FetchErrorView: View {
    @EnvironmentObject var gameState: GameState

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "wifi.slash")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Constants.Colors.tile.opacity(0.35))
                .padding(.bottom, 24)

            Text("Could not load today's puzzle.")
                .font(Constants.Fonts.rounded(22, weight: .bold))
                .foregroundStyle(Constants.Colors.tile)
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)

            Text(gameState.fetchErrorMessage)
                .font(Constants.Fonts.rounded(15, weight: .regular))
                .foregroundStyle(Constants.Colors.tile.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 36)

            Button { gameState.retryPuzzleFetch() } label: {
                Text("Retry")
                    .font(Constants.Fonts.rounded(18, weight: .bold))
                    .foregroundStyle(Constants.Colors.tileText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Constants.Colors.tile, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}
