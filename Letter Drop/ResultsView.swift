//
//  ResultsView.swift
//  Letter Drop
//

import SwiftUI

// MARK: - Root

struct ResultsView: View {
    @EnvironmentObject var gameState: GameState

    @State private var revealed         = false
    @State private var displayScore     = 0
    @State private var definitionWord   : String? = nil
    @State private var showDefinition   = false

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {

                    // ── 1. Hero score ──────────────────────────────────────────
                    HeroScoreView(displayScore: displayScore, revealed: revealed)

                    // ── 2-4. Stats card (combos · best ever · streak) ──────────
                    StatsCard(
                        combosFound: gameState.foundWords.count,
                        totalWaves:  Constants.Game.wavesPerRound,
                        isNewBest:   gameState.isNewBestScore,
                        bestScore:   gameState.bestScore,
                        streak:      gameState.currentStreak,
                        revealed:    revealed
                    )

                    // ── 5. Best words per wave ─────────────────────────────────
                    if !gameState.foundWords.isEmpty {
                        BestWordsCard(
                            foundWords: gameState.foundWords,
                            onTap: { word in
                                definitionWord = word
                                showDefinition = true
                            }
                        )
                        .opacity(revealed ? 1 : 0)
                        .offset(y: revealed ? 0 : 12)
                        .animation(.spring(response: 0.45, dampingFraction: 0.72).delay(0.30),
                                   value: revealed)
                    }

                    // ── CTA buttons ────────────────────────────────────────────
                    CTASection()
                        .opacity(revealed ? 1 : 0)
                        .offset(y: revealed ? 0 : 16)
                        .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.50),
                                   value: revealed)
                }
                .padding(.horizontal, 24)
                .padding(.top, 72)
                .padding(.bottom, 52)
            }
            .sheet(isPresented: $showDefinition) {
                if let word = definitionWord {
                    WordDefinitionSheet(word: word, isPresented: $showDefinition)
                }
            }
            .onAppear {
                let delay: Double = gameState.showPerfectRoundCelebration ? 2.5 : 0.15
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    revealed = true
                }
                scheduleScoreCountUp()
            }

            // Perfect round celebration overlay — fades away before results reveal
            if gameState.showPerfectRoundCelebration {
                PerfectRoundCelebrationOverlay()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: gameState.showPerfectRoundCelebration)
    }

    // MARK: - Helpers

    private func scheduleScoreCountUp() {
        let target = gameState.score
        guard target > 0 else { return }
        let steps        = min(target, 30)
        let startDelay   = 0.30
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
}

// MARK: - Hero score

private struct HeroScoreView: View {
    let displayScore: Int
    let revealed: Bool

    var body: some View {
        Text("\(displayScore)")
            .font(Constants.Fonts.rounded(100, weight: .bold))
            .foregroundStyle(Constants.Colors.scoreGold)
            .monospacedDigit()
            .contentTransition(.numericText())
            .frame(maxWidth: .infinity)
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 14)
            .animation(.spring(response: 0.45, dampingFraction: 0.72).delay(0.05), value: revealed)
    }
}

// MARK: - Stats card

private struct StatsCard: View {
    let combosFound: Int
    let totalWaves:  Int
    let isNewBest:   Bool
    let bestScore:   Int
    let streak:      Int
    let revealed:    Bool

    var body: some View {
        VStack(spacing: 0) {
            CombosRow(found: combosFound, total: totalWaves)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

            Rectangle()
                .fill(Constants.Colors.tile.opacity(0.08))
                .frame(height: 1)

            BestScoreRow(isNewBest: isNewBest, bestScore: bestScore, revealed: revealed)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

            Rectangle()
                .fill(Constants.Colors.tile.opacity(0.08))
                .frame(height: 1)

            StreakRow(streak: streak)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
        .background(Constants.Colors.trayBackground, in: RoundedRectangle(cornerRadius: 20))
        .opacity(revealed ? 1 : 0)
        .offset(y: revealed ? 0 : 12)
        .animation(.spring(response: 0.45, dampingFraction: 0.72).delay(0.18), value: revealed)
    }
}

// MARK: - Combos row

private struct CombosRow: View {
    let found: Int
    let total: Int

    var body: some View {
        HStack {
            Text("COMBOS")
                .font(Constants.Fonts.rounded(11, weight: .semibold))
                .foregroundStyle(Constants.Colors.tile.opacity(0.40))
                .tracking(2)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Constants.Colors.scoreGold)
                Text("\(found)/\(total)")
            }
            .font(Constants.Fonts.rounded(20, weight: .bold))
            .foregroundStyle(Constants.Colors.tile)
        }
    }
}

// MARK: - Best score row

private struct BestScoreRow: View {
    let isNewBest: Bool
    let bestScore: Int
    let revealed:  Bool

    @State private var newBestPopped = false

    var body: some View {
        HStack {
            if isNewBest {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                    Text("NEW HIGH SCORE")
                }
                .font(Constants.Fonts.rounded(16, weight: .bold))
                .foregroundStyle(Constants.Colors.scoreGold)
                .frame(maxWidth: .infinity)
                    .scaleEffect(newBestPopped ? 1.0 : 0.55)
                    .opacity(newBestPopped ? 1.0 : 0)
                    .animation(.spring(response: 0.38, dampingFraction: 0.58), value: newBestPopped)
                    .onChange(of: revealed) { _, isRevealed in
                        if isRevealed {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                newBestPopped = true
                            }
                        }
                    }
            } else {
                Text("BEST EVER")
                    .font(Constants.Fonts.rounded(11, weight: .semibold))
                    .foregroundStyle(Constants.Colors.tile.opacity(0.40))
                    .tracking(2)
                Spacer()
                Text(formattedScore(bestScore))
                    .font(Constants.Fonts.rounded(20, weight: .bold))
                    .foregroundStyle(Constants.Colors.tile)
            }
        }
    }

    private func formattedScore(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: n as NSNumber) ?? "\(n)"
    }
}

// MARK: - Streak row

private struct StreakRow: View {
    let streak: Int

    var body: some View {
        HStack {
            Text("STREAK")
                .font(Constants.Fonts.rounded(11, weight: .semibold))
                .foregroundStyle(Constants.Colors.tile.opacity(0.40))
                .tracking(2)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Constants.Colors.scoreGold)
                Text("Day \(streak)")
            }
            .font(Constants.Fonts.rounded(20, weight: .bold))
            .foregroundStyle(Constants.Colors.tile)
        }
    }
}

// MARK: - Best words per wave

private struct BestWordsCard: View {
    let foundWords: [FoundWord]
    let onTap: (String) -> Void

    /// One best word per wave, sorted by wave index.
    private var bestPerWave: [FoundWord] {
        Dictionary(grouping: foundWords, by: \.waveIndex)
            .compactMapValues { $0.max(by: { $0.score < $1.score }) }
            .sorted(by: { $0.key < $1.key })
            .map(\.value)
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(bestPerWave.enumerated()), id: \.element.word) { idx, fw in
                if idx > 0 {
                    Rectangle()
                        .fill(Constants.Colors.tile.opacity(0.08))
                        .frame(height: 1)
                }
                BestWordRow(foundWord: fw, onTap: onTap)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
            }
        }
        .background(Constants.Colors.trayBackground, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct BestWordRow: View {
    let foundWord: FoundWord
    let onTap: (String) -> Void

    var body: some View {
        Button {
            onTap(foundWord.word)
        } label: {
            HStack {
                Text("WAVE \(foundWord.waveIndex + 1)")
                    .font(Constants.Fonts.rounded(11, weight: .semibold))
                    .foregroundStyle(Constants.Colors.tile.opacity(0.38))
                    .tracking(2)
                Spacer()
                Text(foundWord.word)
                    .font(Constants.Fonts.rounded(17, weight: .bold))
                    .foregroundStyle(Constants.Colors.tile)
                Text("+\(foundWord.score)")
                    .font(Constants.Fonts.rounded(14, weight: .semibold))
                    .foregroundStyle(Constants.Colors.scoreGold)
                    .padding(.leading, 4)
                Image(systemName: "info.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Constants.Colors.tile.opacity(0.35))
                    .padding(.leading, 6)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CTA section

private struct CTASection: View {
    @EnvironmentObject var gameState: GameState

    @State private var shareImage: UIImage? = nil
    @State private var showImageShare       = false
    @State private var showChallengeShare   = false

    private var shareCaption: String {
        let combos = gameState.foundWords.count
        let total  = Constants.Game.wavesPerRound
        let streak = gameState.currentStreak
        return "Letter Drop · \(gameState.score) · \(combos)/\(total) Combos · Day \(streak) 🔥 letterdrops.app"
    }

    private var challengeText: String {
        "I scored \(gameState.score) on today's Letter Drop Daily Challenge — think you can beat me? 🔤⬇️"
    }

    var body: some View {
        VStack(spacing: 12) {

            // Share Score → PNG image card
            Button {
                let fmt = DateFormatter()
                fmt.dateFormat = "d MMMM yyyy"
                if let img = renderScoreCard(
                    score:       gameState.score,
                    combosFound: gameState.foundWords.count,
                    totalWaves:  Constants.Game.wavesPerRound,
                    streak:      gameState.currentStreak,
                    dateString:  fmt.string(from: Date())
                ) {
                    shareImage = img
                    showImageShare = true
                    let dateFmt = DateFormatter(); dateFmt.dateFormat = "yyyy-MM-dd"
                    AnalyticsManager.shared.track(.resultShared(date: dateFmt.string(from: Date())))
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Share Score")
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
            .sheet(isPresented: $showImageShare) {
                if let img = shareImage {
                    ActivitySheet(items: [shareCaption, img], isPresented: $showImageShare)
                }
            }

            // Challenge Your Friends → text + URL
            Button {
                showChallengeShare = true
                let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
                AnalyticsManager.shared.track(.resultShared(date: fmt.string(from: Date())))
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.2")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Challenge Your Friends")
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
            .sheet(isPresented: $showChallengeShare) {
                ActivitySheet(
                    items: [challengeText, URL(string: "https://letterdrops.app")!],
                    isPresented: $showChallengeShare
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

// MARK: - Perfect round celebration overlay

private struct PerfectRoundCelebrationOverlay: View {
    @State private var scale:   CGFloat = 0.5
    @State private var opacity: Double  = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.60).ignoresSafeArea()

            VStack(spacing: 14) {
                Text("PERFECT ROUND")
                    .font(Constants.Fonts.rounded(13, weight: .semibold))
                    .foregroundStyle(Constants.Colors.tile.opacity(0.65))
                    .tracking(3)
                Text("+200")
                    .font(Constants.Fonts.rounded(88, weight: .bold))
                    .foregroundStyle(Constants.Colors.scoreGold)
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.62)) {
                    scale = 1.0; opacity = 1.0
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let state = GameState()
    state.score = 340
    state.foundWords = [
        FoundWord(word: "RAIN",  score: 40, waveIndex: 0),
        FoundWord(word: "MIST",  score: 40, waveIndex: 2),
        FoundWord(word: "CLOUD", score: 50, waveIndex: 4),
    ]
    state.bestScore      = 340
    state.isNewBestScore = true
    state.currentStreak  = 7
    return ZStack {
        Constants.Colors.background.ignoresSafeArea()
        ResultsView().environmentObject(state)
    }
}
