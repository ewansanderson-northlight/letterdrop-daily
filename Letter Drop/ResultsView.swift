//
//  ResultsView.swift
//  Letter Drop
//

import SwiftUI

// MARK: - Root

struct ResultsView: View {
    @EnvironmentObject var gameState: GameState

    @State private var revealed      = false
    @State private var displayScore  = 0

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                ResultsHeader(revealed: revealed)
                    .padding(.bottom, 32)

                // ── Score card ───────────────────────────────────────────────
                ScoreCard(displayScore: displayScore,
                          maxScore: gameState.theoreticalMaxScore,
                          revealed: revealed)
                    .padding(.bottom, 28)

                // ── Word grid ────────────────────────────────────────────────
                SectionLabel(title: "WORDS FOUND")
                    .padding(.bottom, 10)
                    .opacity(revealed ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(0.15), value: revealed)

                WaveResultsGrid(foundWords: gameState.foundWords,
                               optimalWords: gameState.waveOptimalWords,
                               revealed: revealed)
                    .padding(.bottom, 28)

                // ── Word stats ───────────────────────────────────────────────
                if !gameState.foundWords.isEmpty {
                    SectionLabel(title: "HIGHLIGHTS")
                        .padding(.bottom, 10)
                        .opacity(revealed ? 1 : 0)
                        .animation(.easeOut(duration: 0.3).delay(0.40), value: revealed)

                    WordHighlightsCard(
                        shortest: gameState.shortestFoundWord,
                        longest:  gameState.longestFoundWord,
                        revealed: revealed
                    )
                    .padding(.bottom, 28)
                }

                // ── CTA buttons ──────────────────────────────────────────────
                CTASection(shareText: shareText)
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed ? 0 : 16)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(ctaDelay),
                               value: revealed)
            }
            .padding(.horizontal, 24)
            .padding(.top, 64)
            .padding(.bottom, 52)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                revealed = true
            }
            scheduleScoreCountUp()
        }
    }

    // MARK: - Helpers

    private var ctaDelay: Double {
        0.45 + Double(max(1, gameState.foundWords.count)) * 0.08
    }

    private func scheduleScoreCountUp() {
        let target = gameState.score
        guard target > 0 else { return }
        let steps        = min(target, 30)
        let startDelay   = ctaDelay - 0.2
        let duration     = 0.65
        let stepInterval = duration / Double(steps)
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(
                deadline: .now() + startDelay + stepInterval * Double(i)
            ) {
                withAnimation(.linear(duration: stepInterval)) {
                    displayScore = Int(round(Double(target) * Double(i) / Double(steps)))
                }
            }
        }
    }

    private var shareText: String {
        let date  = Date.now.formatted(.dateTime.month(.wide).day().year())
        let found = gameState.foundWords.count
        var lines = [
            "Letter Drop · \(date)",
            "\(found)/\(Constants.Game.wavesPerRound) waves · \(gameState.score) pts",
            ""
        ]
        for fw in gameState.foundWords.sorted(by: { $0.waveIndex < $1.waveIndex }) {
            let pad = String(repeating: " ", count: max(0, 10 - fw.word.count))
            lines.append("\(fw.word)\(pad)+\(fw.score)")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Header

private struct ResultsHeader: View {
    let revealed: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text("ROUND OVER")
                .font(Constants.Fonts.rounded(11, weight: .semibold))
                .foregroundStyle(Constants.Colors.tile.opacity(0.35))
                .tracking(3)

            Text("Nice work")
                .font(Constants.Fonts.rounded(34, weight: .bold))
                .foregroundStyle(Constants.Colors.tile)
        }
        .frame(maxWidth: .infinity)
        .opacity(revealed ? 1 : 0)
        .offset(y: revealed ? 0 : 10)
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: revealed)
    }
}

// MARK: - Score card

private struct ScoreCard: View {
    let displayScore: Int
    let maxScore: Int
    let revealed: Bool

    private var starCount: Int {
        guard maxScore > 0 else { return 0 }
        let pct = Double(displayScore) / Double(maxScore)
        return pct >= 0.70 ? 3 : pct >= 0.35 ? 2 : 1
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("\(displayScore)")
                .font(Constants.Fonts.rounded(76, weight: .bold))
                .foregroundStyle(Constants.Colors.scoreGold)
                .monospacedDigit()
                .contentTransition(.numericText())
            if maxScore > 0 {
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: "star.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Constants.Colors.gold.opacity(i < starCount ? 1.0 : 0.15))
                            .animation(.spring(response: 0.4), value: starCount)
                    }
                }
                Text("\(displayScore) / \(maxScore) max")
                    .font(Constants.Fonts.rounded(13, weight: .regular))
                    .foregroundStyle(Constants.Colors.tile.opacity(0.35))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .padding(.top, 2)
            } else {
                Text("points")
                    .font(Constants.Fonts.rounded(17, weight: .regular))
                    .foregroundStyle(Constants.Colors.tile.opacity(0.45))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Constants.Colors.trayBackground, in: RoundedRectangle(cornerRadius: 20))
        .opacity(revealed ? 1 : 0)
        .offset(y: revealed ? 0 : 14)
        .animation(.spring(response: 0.45, dampingFraction: 0.72).delay(0.05), value: revealed)
    }
}

// MARK: - Wave results grid

/// Shows all 6 wave slots — filled if a word was found, empty if not.
private struct WaveResultsGrid: View {
    let foundWords: [FoundWord]
    let optimalWords: [GameState.WaveOptimal?]
    let revealed: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    private func word(for waveIndex: Int) -> FoundWord? {
        foundWords.first(where: { $0.waveIndex == waveIndex })
    }

    private func optimal(for waveIndex: Int) -> GameState.WaveOptimal? {
        guard waveIndex < optimalWords.count else { return nil }
        return optimalWords[waveIndex]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<Constants.Game.wavesPerRound, id: \.self) { i in
                WaveResultCell(waveIndex: i,
                               found: word(for: i),
                               optimal: optimal(for: i),
                               revealed: revealed)
            }
        }
    }
}

private struct WaveResultCell: View {
    let waveIndex: Int
    let found: FoundWord?
    let optimal: GameState.WaveOptimal?
    let revealed: Bool

    /// True when the player found a different (or no) word vs the best available.
    private var showOptimal: Bool {
        guard let opt = optimal else { return false }
        if let fw = found { return fw.word != opt.word }
        return true   // missed wave — always show best
    }

    var body: some View {
        VStack(spacing: 3) {
            if let fw = found {
                Text(fw.word)
                    .font(Constants.Fonts.rounded(15, weight: .bold))
                    .foregroundStyle(Constants.Colors.tileText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("+\(fw.score)")
                    .font(Constants.Fonts.rounded(12, weight: .semibold))
                    .foregroundStyle(Constants.Colors.scoreGold)
            } else {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Constants.Colors.tile.opacity(0.20))
            }

            if showOptimal, let opt = optimal {
                HStack(spacing: 3) {
                    Text("best:")
                        .font(Constants.Fonts.rounded(9, weight: .medium))
                        .foregroundStyle(Constants.Colors.success.opacity(0.65))
                    Text(opt.word)
                        .font(Constants.Fonts.rounded(10, weight: .bold))
                        .foregroundStyle(Constants.Colors.success.opacity(0.90))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Constants.Colors.success.opacity(0.13), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 56)
        .padding(.vertical, showOptimal ? 8 : 0)
        .background(
            found != nil
                ? Constants.Colors.tile
                : Constants.Colors.trayBackground,
            in: RoundedRectangle(cornerRadius: 12)
        )
        .opacity(revealed ? 1 : 0)
        .offset(y: revealed ? 0 : 12)
        .animation(
            .spring(response: 0.42, dampingFraction: 0.72)
                .delay(0.18 + Double(waveIndex) * 0.07),
            value: revealed
        )
    }
}

// MARK: - Word highlights

private struct WordHighlightsCard: View {
    let shortest: String?
    let longest:  String?
    let revealed: Bool

    var body: some View {
        VStack(spacing: 2) {
            if let w = shortest {
                HighlightRow(label: "Shortest", word: w,
                             revealDelay: 0.42, revealed: revealed)
            }
            if let w = longest, w != shortest {
                HighlightRow(label: "Longest", word: w,
                             revealDelay: 0.48, revealed: revealed)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct HighlightRow: View {
    let label: String
    let word: String
    let revealDelay: Double
    let revealed: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(Constants.Fonts.rounded(15, weight: .regular))
                .foregroundStyle(Constants.Colors.tile.opacity(0.6))
            Spacer()
            Text(word)
                .font(Constants.Fonts.rounded(16, weight: .bold))
                .foregroundStyle(Constants.Colors.tile)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Constants.Colors.trayBackground)
        .opacity(revealed ? 1 : 0)
        .offset(x: revealed ? 0 : 16)
        .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(revealDelay),
                   value: revealed)
    }
}

// MARK: - CTA section

private struct CTASection: View {
    let shareText: String
    @EnvironmentObject var gameState: GameState

    var body: some View {
        VStack(spacing: 12) {
            ShareLink(item: shareText) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Share Results")
                        .font(Constants.Fonts.rounded(16, weight: .semibold))
                }
                .foregroundStyle(Constants.Colors.tile.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Constants.Colors.tile.opacity(0.15), lineWidth: 1.5)
                )
            }

            Button { gameState.startRound() } label: {
                Text("Play Again")
                    .font(Constants.Fonts.rounded(17, weight: .semibold))
                    .foregroundStyle(Constants.Colors.tileText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Constants.Colors.tile,
                                in: RoundedRectangle(cornerRadius: 14))
            }

            Button { gameState.returnToMenu() } label: {
                Text("Main Menu")
                    .font(Constants.Fonts.rounded(16, weight: .medium))
                    .foregroundStyle(Constants.Colors.tile.opacity(0.4))
                    .padding(.vertical, 8)
            }
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

// MARK: - Preview

#Preview {
    let state = GameState()
    state.score = 31
    state.foundWords = [
        FoundWord(word: "RAIN",  score: 5,  waveIndex: 0),
        FoundWord(word: "MIST",  score: 5,  waveIndex: 2),
        FoundWord(word: "CLOUD", score: 8,  waveIndex: 4),
    ]
    state.waveOptimalWords = [
        GameState.WaveOptimal(word: "RAINS",  score: 7),
        nil,
        GameState.WaveOptimal(word: "MIST",   score: 5),
        nil,
        GameState.WaveOptimal(word: "CLOUDS", score: 10),
        nil,
    ]
    state.theoreticalMaxScore = 88
    return ZStack {
        Constants.Colors.background.ignoresSafeArea()
        ResultsView().environmentObject(state)
    }
}
