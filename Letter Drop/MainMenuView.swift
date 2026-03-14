//
//  MainMenuView.swift
//  Letter Drop
//

import SwiftUI

// MARK: - Root

struct MainMenuView: View {
    @EnvironmentObject var gameState: GameState

    @State private var appeared = false
    @State private var showHowToPlay = false
    @State private var showStats = false

    var body: some View {
        ZStack {
            // Drifting tile silhouettes in the background
            MenuBackground()

            // Main content
            VStack(spacing: 0) {
                Spacer()

                titleSection

                Spacer()

                bottomSection
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            appeared = false
            // Brief pause so the crossfade from results settles
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                appeared = true
            }
        }
        .sheet(isPresented: $showHowToPlay) { HowToPlaySheet() }
        .sheet(isPresented: $showStats)     { StatsSheet().environmentObject(gameState) }
    }

    // MARK: - Title section

    private var titleSection: some View {
        VStack(spacing: 16) {
            // "LETTER" — spaced cream text
            Text("LETTER")
                .font(Constants.Fonts.rounded(44, weight: .bold))
                .foregroundStyle(Constants.Colors.tile)
                .tracking(8)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -20)
                .animation(.spring(response: 0.5, dampingFraction: 0.72), value: appeared)

            // "DROP" — spelled as individual game tiles, staggered drop-in
            HStack(spacing: 8) {
                ForEach(Array("DROP".enumerated()), id: \.offset) { index, char in
                    DropTitleTile(letter: String(char), index: index, appeared: appeared)
                }
            }

            // Tagline
            Text("Build words before they fall away.")
                .font(Constants.Fonts.rounded(15, weight: .regular))
                .foregroundStyle(Constants.Colors.tile.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.35), value: appeared)
        }
    }

    // MARK: - Bottom section

    private var bottomSection: some View {
        VStack(spacing: 0) {
            // Best score badge — only show after first game
            if gameState.bestScore > 0 {
                BestScoreBadge(score: gameState.bestScore)
                    .padding(.bottom, 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(0.4), value: appeared)
            }

            // Date chip
            DateChip()
                .padding(.bottom, 28)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.45), value: appeared)

            // Play button — clock icon shown if already played today
            Button { gameState.startRound() } label: {
                HStack(spacing: 8) {
                    if gameState.hasPlayedToday {
                        Image(systemName: "clock")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(gameState.hasPlayedToday ? "Play Again" : "Play")
                        .font(Constants.Fonts.rounded(20, weight: .bold))
                }
                .foregroundStyle(Constants.Colors.tileText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Constants.Colors.tile, in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(MenuPrimaryButtonStyle())
            .padding(.bottom, 20)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(.spring(response: 0.45, dampingFraction: 0.7).delay(0.5), value: appeared)

            // Secondary row
            HStack(spacing: 40) {
                MenuSecondaryButton(title: "How to Play", icon: "questionmark.circle") {
                    showHowToPlay = true
                }
                MenuSecondaryButton(title: "Stats", icon: "chart.bar") {
                    showStats = true
                }
            }
            .padding(.bottom, 20)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.3).delay(0.6), value: appeared)

            Text("by unserious.games")
                .font(Constants.Fonts.rounded(13, weight: .regular))
                .foregroundStyle(Constants.Colors.tile.opacity(0.18))
                .padding(.bottom, 36)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.70), value: appeared)
        }
    }
}

// MARK: - Drop title tile

/// One of the four cream letter tiles that spell "DROP" in the title.
private struct DropTitleTile: View {
    let letter: String
    let index: Int
    let appeared: Bool

    // Each tile drops down sequentially
    private var delay: Double { 0.15 + Double(index) * 0.07 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13)
                .fill(Constants.Colors.tile)
                .shadow(color: Constants.Colors.tileShadow.opacity(0.45), radius: 4, x: 2, y: 4)

            Text(letter)
                .font(Constants.Fonts.rounded(38, weight: .bold))
                .foregroundStyle(Constants.Colors.tileText)
        }
        .frame(width: 64, height: 64)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -28)
        .animation(
            .spring(response: 0.48, dampingFraction: 0.6).delay(delay),
            value: appeared
        )
    }
}

// MARK: - Best score badge

private struct BestScoreBadge: View {
    let score: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Constants.Colors.success)
            Text("Best  \(score) pts")
                .font(Constants.Fonts.rounded(13, weight: .semibold))
                .foregroundStyle(Constants.Colors.tile.opacity(0.65))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .strokeBorder(Constants.Colors.tile.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Date chip

private struct DateChip: View {
    private var dateString: String {
        Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Constants.Colors.tile.opacity(0.35))
            Text(dateString)
                .font(Constants.Fonts.rounded(14, weight: .medium))
                .foregroundStyle(Constants.Colors.tile.opacity(0.55))
        }
    }
}

// MARK: - Secondary button

private struct MenuSecondaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                Text(title)
                    .font(Constants.Fonts.rounded(12, weight: .medium))
            }
            .foregroundStyle(Constants.Colors.tile.opacity(0.4))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Button styles

private struct MenuPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Background drifting tiles

private struct MenuBackground: View {
    // Letter, x-fraction, fall duration, initial-y fraction (0=top, 1=bottom)
    private let tiles: [(String, CGFloat, Double, CGFloat)] = [
        ("L", 0.11, 11.0, 0.0),
        ("E", 0.32, 9.0,  0.45),
        ("T", 0.54, 13.0, 0.2),
        ("D", 0.74, 10.5, 0.7),
        ("R", 0.90, 8.5,  0.1),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(tiles.indices, id: \.self) { i in
                let (letter, xFrac, duration, startFrac) = tiles[i]
                DriftingTileSilhouette(
                    letter: letter,
                    x: geo.size.width * xFrac,
                    duration: duration,
                    startY: -70 + (geo.size.height + 140) * startFrac,
                    endY: geo.size.height + 70
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct DriftingTileSilhouette: View {
    let letter: String
    let x: CGFloat
    let duration: Double
    let startY: CGFloat
    let endY: CGFloat

    @State private var y: CGFloat

    init(letter: String, x: CGFloat, duration: Double, startY: CGFloat, endY: CGFloat) {
        self.letter = letter
        self.x = x
        self.duration = duration
        self.startY = startY
        self.endY = endY
        _y = State(initialValue: startY)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Constants.Colors.tile)
                .frame(width: 50, height: 50)
            Text(letter)
                .font(Constants.Fonts.rounded(24, weight: .semibold))
                .foregroundStyle(Constants.Colors.tileText)
        }
        .opacity(0.06)
        .position(x: x, y: y)
            .onAppear {
                withAnimation(
                    .linear(duration: duration * (1.0 - Double((startY + 70) / (endY + 70))))
                    .repeatForever(autoreverses: false)
                ) {
                    y = endY
                }
            }
            }
        }

// MARK: - Preview

#Preview("First launch") {
    ZStack {
        Constants.Colors.background.ignoresSafeArea()
        MainMenuView().environmentObject(GameState())
    }
}

#Preview("With best score") {
    let state = GameState()
    state.bestScore = 74
    state.gamesPlayed = 7
    return ZStack {
        Constants.Colors.background.ignoresSafeArea()
        MainMenuView().environmentObject(state)
    }
}
