//
//  StatsView.swift
//  Letter Drop
//

import SwiftUI

// MARK: - Sheet root

struct StatsSheet: View {
    @EnvironmentObject var gameState: GameState
    @Environment(\.dismiss) private var dismiss

    @State private var revealed = false
    @State private var showResetConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.background.ignoresSafeArea()

                if gameState.gamesPlayed == 0 {
                    EmptyStatsView()
                } else {
                    statsContent
                }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Constants.Colors.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(Constants.Fonts.rounded(16, weight: .semibold))
                        .foregroundStyle(Constants.Colors.tile)
                }
            }
            .confirmationDialog(
                "This will permanently delete all your stats.",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset Stats", role: .destructive) { gameState.resetStats() }
                Button("Cancel", role: .cancel) { }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { revealed = true }
        }
    }

    // MARK: - Stats content

    private var statsContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // ── Primary stat grid ──────────────────────────────────
                StatGrid(gameState: gameState, revealed: revealed)
                    .padding(.bottom, 28)

                // ── Lifetime section ───────────────────────────────────
                SectionLabel(title: "LIFETIME")
                    .padding(.bottom, 10)
                    .opacity(revealed ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(0.38), value: revealed)

                lifetimeRows
                    .padding(.bottom, 32)

                // ── Best word ──────────────────────────────────────────
                if gameState.bestWordScore > 0 {
                    SectionLabel(title: "BEST WORD")
                        .padding(.bottom, 10)
                        .opacity(revealed ? 1 : 0)
                        .animation(.easeOut(duration: 0.3).delay(0.45), value: revealed)

                    BestWordRow(word: gameState.bestWord, score: gameState.bestWordScore)
                        .padding(.bottom, 32)
                        .opacity(revealed ? 1 : 0)
                        .offset(y: revealed ? 0 : 12)
                        .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.48), value: revealed)
                }

                // ── Reset ──────────────────────────────────────────────
                Button {
                    showResetConfirmation = true
                } label: {
                    Text("Reset Stats")
                        .font(Constants.Fonts.rounded(14, weight: .medium))
                        .foregroundStyle(Constants.Colors.failure.opacity(0.5))
                }
                .padding(.bottom, 8)
                .opacity(revealed ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.55), value: revealed)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 44)
        }
    }

    // MARK: - Lifetime rows

    private var lifetimeRows: some View {
        VStack(spacing: 2) {
            StatListRow(label: "Total Score",   value: "\(gameState.totalScore)",
                        suffix: " pts", revealDelay: 0.40, revealed: revealed)
            StatListRow(label: "Average Score", value: "\(gameState.averageScore)",
                        suffix: " pts", revealDelay: 0.44, revealed: revealed)
            StatListRow(label: "Total Words",   value: "\(gameState.totalWordsCompleted)",
                        suffix: nil,   revealDelay: 0.48, revealed: revealed)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Empty state

private struct EmptyStatsView: View {
    var body: some View {
        VStack(spacing: 16) {
            // Placeholder tile cluster
            HStack(spacing: 8) {
                ForEach(["?", "?", "?"], id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Constants.Colors.trayBackground)
                        .frame(width: 52, height: 52)
                        .overlay(
                            Text("?")
                                .font(Constants.Fonts.rounded(26, weight: .bold))
                                .foregroundStyle(Constants.Colors.tile.opacity(0.15))
                        )
                }
            }
            .padding(.bottom, 4)

            Text("No stats yet")
                .font(Constants.Fonts.rounded(20, weight: .semibold))
                .foregroundStyle(Constants.Colors.tile.opacity(0.55))

            Text("Play your first round to start tracking your progress.")
                .font(Constants.Fonts.rounded(14, weight: .regular))
                .foregroundStyle(Constants.Colors.tile.opacity(0.3))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Section label

private struct SectionLabel: View {
    let title: String
    var body: some View {
        Text(title)
            .font(Constants.Fonts.rounded(11, weight: .semibold))
            .foregroundStyle(Constants.Colors.tile.opacity(0.4))
            .tracking(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Primary stat grid (2 × 2)

private struct StatGrid: View {
    let gameState: GameState
    let revealed: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            StatCard(
                value: gameState.gamesPlayed,
                label: "GAMES PLAYED",
                suffix: nil,
                revealDelay: 0.10,
                revealed: revealed
            )
            StatCard(
                value: gameState.bestScore,
                label: "BEST SCORE",
                suffix: "pts",
                revealDelay: 0.16,
                revealed: revealed
            )
            StatCard(
                value: gameState.totalWordsCompleted,
                label: "WORDS FOUND",
                suffix: nil,
                revealDelay: 0.22,
                revealed: revealed
            )
            StatCard(
                value: gameState.perfectRounds,
                label: "PERFECT ROUNDS",
                suffix: nil,
                revealDelay: 0.28,
                revealed: revealed
            )
        }
    }
}

// MARK: - Stat card

private struct StatCard: View {
    let value: Int
    let label: String
    let suffix: String?
    let revealDelay: Double
    let revealed: Bool

    @State private var displayValue: Int = 0

    var body: some View {
        VStack(spacing: 2) {
            Spacer(minLength: 0)

            // Animated number + optional suffix
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(displayValue)")
                    .font(Constants.Fonts.rounded(40, weight: .bold))
                    .foregroundStyle(Constants.Colors.tile)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                if let suffix {
                    Text(suffix)
                        .font(Constants.Fonts.rounded(14, weight: .medium))
                        .foregroundStyle(Constants.Colors.tile.opacity(0.45))
                        .padding(.bottom, 4)
                }
            }

            Text(label)
                .font(Constants.Fonts.rounded(10, weight: .semibold))
                .foregroundStyle(Constants.Colors.tile.opacity(0.38))
                .tracking(1.5)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(Constants.Colors.trayBackground, in: RoundedRectangle(cornerRadius: 16))
        .opacity(revealed ? 1 : 0)
        .offset(y: revealed ? 0 : 16)
        .animation(.spring(response: 0.45, dampingFraction: 0.72).delay(revealDelay), value: revealed)
        .onChange(of: revealed) { _, isRevealed in
            if isRevealed { animateCountUp() }
        }
    }

    private func animateCountUp() {
        guard value > 0 else { return }
        let steps = min(value, 24)
        let startDelay = revealDelay + 0.05
        let duration   = 0.55
        let interval   = duration / Double(steps)

        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + startDelay + interval * Double(i)) {
                withAnimation(.linear(duration: interval)) {
                    displayValue = Int(round(Double(value) * Double(i) / Double(steps)))
                }
            }
        }
    }
}

// MARK: - Secondary stat list row

private struct StatListRow: View {
    let label: String
    let value: String
    let suffix: String?
    let revealDelay: Double
    var revealed: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(Constants.Fonts.rounded(15, weight: .regular))
                .foregroundStyle(Constants.Colors.tile.opacity(0.6))

            Spacer()

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(Constants.Fonts.rounded(16, weight: .bold))
                    .foregroundStyle(Constants.Colors.tile)
                if let suffix {
                    Text(suffix)
                        .font(Constants.Fonts.rounded(12, weight: .medium))
                        .foregroundStyle(Constants.Colors.tile.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Constants.Colors.trayBackground)
        .opacity(revealed ? 1 : 0)
        .offset(x: revealed ? 0 : 16)
        .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(revealDelay), value: revealed)
    }
}

// MARK: - Best word row

private struct BestWordRow: View {
    let word: String
    let score: Int

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(Array(word.uppercased().enumerated()), id: \.offset) { _, char in
                    BestWordTile(letter: String(char))
                }
            }

            Spacer(minLength: 12)

            Text("+\(score)")
                .font(Constants.Fonts.rounded(16, weight: .bold))
                .foregroundStyle(Constants.Colors.success)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Constants.Colors.trayBackground, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct BestWordTile: View {
    let letter: String
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 7)
                .fill(Constants.Colors.tile)
                .shadow(color: Constants.Colors.tileShadow.opacity(0.25), radius: 2, x: 1, y: 1)
            Text(letter)
                .font(Constants.Fonts.rounded(17, weight: .semibold))
                .foregroundStyle(Constants.Colors.tileText)
                .frame(width: 32, height: 32)
            Text("\(LetterValues.value(for: letter))")
                .font(Constants.Fonts.rounded(8, weight: .regular))
                .foregroundStyle(Constants.Colors.tileText.opacity(0.4))
                .padding(.trailing, 3)
                .padding(.bottom, 2)
        }
        .frame(width: 32, height: 32)
    }
}

// MARK: - Previews

#Preview("With data") {
    let state = GameState()
    state.gamesPlayed        = 12
    state.bestScore          = 88
    state.totalScore         = 620
    state.totalWordsCompleted = 47
    state.perfectRounds      = 3
    state.bestWord           = "FROSTY"
    state.bestWordScore      = 36
    return StatsSheet()
        .environmentObject(state)
}

#Preview("Empty") {
    StatsSheet()
        .environmentObject(GameState())
}
