//
//  GameContainerView.swift
//  Letter Drop
//
//  SwiftUI wrapper that embeds GameViewController (SpriteKit + HUD).
//  GamePlayView wraps it with all gameplay overlays.
//

import SwiftUI

// MARK: - GamePlayView (used by RootView for the .playing phase)

struct GamePlayView: View {
    @EnvironmentObject var gameState: GameState

    var body: some View {
        ZStack {
            GameContainerView()

            // Multiplier streak pulse — gold screen-edge ring
            StreakPulseOverlay(consecutiveSolves: gameState.consecutiveSolves)
                .allowsHitTesting(false)

            // Miss feedback
            if gameState.showMissFeedback {
                MissOverlay()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            // Ready-Set-Go countdown
            if let count = gameState.countdownValue {
                CountdownOverlay(value: count)
                    .allowsHitTesting(false)
            }

            // Word preview: live swiping OR frozen submitted tiles (with best word below)
            let previewWord = !gameState.currentSelection.isEmpty
                ? gameState.currentSelection
                : (gameState.submittedWordDisplay?.word ?? "")
            let previewStreakBonus = !gameState.currentSelection.isEmpty
                ? gameState.currentStreakBonus
                : (gameState.submittedWordDisplay?.streakBonus ?? 0)

            if !previewWord.isEmpty {
                WordPreviewOverlay(
                    word:           previewWord,
                    streakBonus:    previewStreakBonus,
                    blockTopUIKitY: gameState.blockTopUIKitY,
                    bestWordFlash:  gameState.currentSelection.isEmpty ? gameState.bestWordFlash : nil
                )
                .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .bottom)))
                .allowsHitTesting(false)
            }

            // CRAWLING banner — slides in when slow-mo is active, out on release
            if gameState.isSlowMoActive {
                CrawlingBannerOverlay()
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal:   .opacity
                    ))
                    .allowsHitTesting(false)
            }

            // Wave banner
            if let banner = gameState.waveBanner {
                WaveBannerOverlay(text: banner)
                    .transition(.scale(scale: 0.80).combined(with: .opacity))
                    .allowsHitTesting(false)
            }

        }
        .animation(.easeInOut(duration: 0.18), value: gameState.showMissFeedback)
        .animation(.easeOut(duration: 0.25),   value: gameState.countdownValue)
        .animation(.spring(response: 0.28, dampingFraction: 0.75),
                   value: gameState.currentSelection.isEmpty)
        .animation(.spring(response: 0.28, dampingFraction: 0.75),
                   value: gameState.submittedWordDisplay != nil)
        .animation(.easeOut(duration: 0.55),
                   value: gameState.isSlowMoActive)
        .animation(.spring(response: 0.28, dampingFraction: 0.70),
                   value: gameState.waveBanner != nil)
    }
}

// MARK: - Word preview overlay (above the active block)
// Shows the live swipe preview OR the frozen tile row after submit.
// bestWordFlash is only passed when the word is frozen (not during live swiping).

private struct WordPreviewOverlay: View {
    let word          : String
    let streakBonus   : Int
    let blockTopUIKitY: CGFloat
    var bestWordFlash : GameState.BestWordFlash? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Push down to just above the block's top edge (min 140 to stay below header)
            Spacer()
                .frame(height: blockTopUIKitY > 0
                       ? max(140, blockTopUIKitY - 64)
                       : 280)
            VStack(spacing: 8) {
                SelectionPreview(word: word, streakBonus: streakBonus)

                // Best word badge floats in below the frozen tile row
                if let flash = bestWordFlash {
                    BestWordBadge(flash: flash)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal:   .opacity
                        ))
                }
            }
            .animation(.easeOut(duration: 0.35), value: bestWordFlash != nil)

            Spacer()
        }
    }
}

// MARK: - Ready-Set-Go countdown overlay

private struct CountdownOverlay: View {
    let value: Int

    @State private var scale:   CGFloat = 0.35
    @State private var opacity: Double  = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.40).ignoresSafeArea()

            Text(value == 0 ? "GO" : "\(value)")
                .font(Constants.Fonts.rounded(100, weight: .bold))
                .foregroundStyle(value == 0 ? Constants.Colors.gold : Constants.Colors.tile)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .onAppear { pop() }
        .onChange(of: value) { scale = 0.35; opacity = 0; pop() }
    }

    private func pop() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.62)) {
            scale = 1.0; opacity = 1.0
        }
    }
}

// MARK: - Best word badge (floats in below the frozen tile preview)

private struct BestWordBadge: View {
    let flash: GameState.BestWordFlash

    var body: some View {
        HStack(spacing: 5) {
            Text("Best was:")
                .font(Constants.Fonts.rounded(13, weight: .regular))
                .foregroundStyle(Constants.Colors.tile.opacity(0.65))
            Text(flash.word)
                .font(Constants.Fonts.rounded(13, weight: .bold))
                .foregroundStyle(Constants.Colors.tile)
            Text("+\(flash.score)")
                .font(Constants.Fonts.rounded(13, weight: .semibold))
                .foregroundStyle(Constants.Colors.gold)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Constants.Colors.trayBackground, in: Capsule())
    }
}

// MARK: - Multiplier streak pulse overlay

private struct StreakPulseOverlay: View {
    let consecutiveSolves: Int

    @State private var borderOpacity: Double = 0
    @State private var prevSolves:    Int    = 0

    var body: some View {
        Rectangle()
            .strokeBorder(Constants.Colors.gold.opacity(borderOpacity), lineWidth: 16)
            .ignoresSafeArea()
            .onChange(of: consecutiveSolves) { _, newVal in
                guard newVal > prevSolves, newVal >= 2 else { prevSolves = newVal; return }
                prevSolves    = newVal
                borderOpacity = 0.75
                withAnimation(.easeOut(duration: 0.55)) { borderOpacity = 0 }
            }
    }
}

// MARK: - Miss feedback overlay

private struct MissOverlay: View {
    var body: some View {
        VStack {
            Spacer()
            Text("MISS")
                .font(Constants.Fonts.rounded(17, weight: .bold))
                .foregroundStyle(Constants.Colors.failure)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Constants.Colors.trayBackground, in: Capsule())
                .padding(.bottom, 160)
        }
    }
}

// MARK: - CRAWLING banner overlay (shown while slow-mo is active)

private struct CrawlingBannerOverlay: View {
    @State private var scale:   CGFloat = 0.80
    @State private var opacity: Double  = 0

    var body: some View {
        VStack {
            Spacer().frame(height: 160)
            Text("CRAWLING")
                .font(Constants.Fonts.rounded(22, weight: .bold))
                .foregroundStyle(Constants.Colors.tile)
                .tracking(6)
                .padding(.horizontal, 28)
                .padding(.vertical, 11)
                .background(Capsule().fill(Constants.Colors.trayBackground.opacity(0.90)))
                .scaleEffect(scale)
                .opacity(opacity)
                .onAppear {
                    // Slow, deliberate ease-in to match the mode's pace
                    withAnimation(.easeOut(duration: 0.55)) {
                        scale   = 1.0
                        opacity = 1.0
                    }
                }
            Spacer()
        }
    }
}

// MARK: - Wave banner overlay

private struct WaveBannerOverlay: View {
    let text: String

    @State private var scale:   CGFloat = 0.7
    @State private var opacity: Double  = 0

    var body: some View {
        VStack {
            Spacer().frame(height: 160)
            Text(text)
                .font(Constants.Fonts.rounded(24, weight: .bold))
                .foregroundStyle(Constants.Colors.tile)
                .tracking(5)
                .padding(.horizontal, 28)
                .padding(.vertical, 11)
                .background(Capsule().fill(Constants.Colors.trayBackground.opacity(0.90)))
                .scaleEffect(scale)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
                        scale = 1.0; opacity = 1.0
                    }
                }
            Spacer()
        }
    }
}

// MARK: - Container (UIViewControllerRepresentable)

struct GameContainerView: UIViewControllerRepresentable {
    @EnvironmentObject var gameState: GameState

    func makeUIViewController(context: Context) -> GameViewController {
        let vc = GameViewController()
        vc.gameState = gameState
        return vc
    }

    func updateUIViewController(_ uiViewController: GameViewController, context: Context) {
        // GameState is shared by reference — no manual sync needed.
    }
}

// MARK: - In-game HUD

/// Transparent overlay on top of the SpriteKit scene.
/// Shows timer, score, multiplier badge, and wave-progress dots.
struct GameHUDView: View {
    @ObservedObject var gameState: GameState

    var body: some View {
        VStack(spacing: 0) {

            // ── Fixed header bar ────────────────────────────────────────────
            VStack(spacing: 0) {

                // Row 1: Slow-mo (leading) · Timer (centre, large) · Score (trailing)
                ZStack {
                    TimerView(
                        blockTime:  gameState.currentBlockTimeRemaining,
                        bankedTime: gameState.bankedTime,
                        phase:      gameState.timerPhase
                    )
                    HStack {
                        SlowMoIndicator(
                            allowance: gameState.slowMoAllowance,
                            isActive:  gameState.isSlowMoActive
                        )
                        Spacer()
                        ScoreView(score: gameState.score)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)

                // Row 2: Wave dots always centred; badge floats to trailing edge
                ZStack {
                    WaveDotsView(
                        total:         Constants.Game.wavesPerRound,
                        solvedIndices: Set(gameState.foundWords.map(\.waveIndex)),
                        activeIndex:   gameState.timerPhase != .none ? gameState.currentWaveIndex : nil
                    )
                    HStack {
                        Spacer()
                        StreakBadge(consecutiveSolves: gameState.consecutiveSolves)
                            .padding(.trailing, 20)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 14)
            }
            .background(
                Constants.Colors.headerBar
                    .ignoresSafeArea(edges: .top)
                    .shadow(color: .black.opacity(0.45), radius: 10, x: 0, y: 4)
            )

            Spacer()
        }
    }
}

// MARK: - Slow-motion indicator

private struct SlowMoIndicator: View {
    let allowance: Double
    let isActive : Bool

    private var isExhausted: Bool { allowance <= 0 }
    private var displaySeconds: Int { max(0, Int(allowance.rounded(.up))) }

    @State private var breathe    = false
    @State private var activating = false   // brief burst scale on activation

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "tortoise.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(
                    isActive    ? Constants.Colors.gold :
                    isExhausted ? Constants.Colors.tile.opacity(0.25) :
                                  Constants.Colors.tile
                )
                .scaleEffect(
                    activating ? 1.85 :
                    isActive   ? (breathe ? 1.65 : 1.45) :
                                 1.0
                )
                .animation(.spring(response: 0.22, dampingFraction: 0.55), value: activating)
                .animation(.spring(response: 0.40, dampingFraction: 0.60), value: isActive)

            Text("\(displaySeconds)s")
                .font(Constants.Fonts.rounded(17, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .foregroundStyle(
                    isExhausted ? Constants.Colors.tile.opacity(0.3) :
                    isActive    ? Constants.Colors.gold :
                                  Constants.Colors.tile
                )
        }
        .opacity(isExhausted ? 0.45 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isExhausted)
        .onChange(of: isActive) { _, active in
            if active {
                activating = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                    activating = false
                    withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) {
                        breathe = true
                    }
                }
            } else {
                activating = false
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    breathe = false
                }
            }
        }
    }
}

// MARK: - Timer (two-phase: bank drains first in gold, then block time)

private struct TimerView: View {
    let blockTime : Double
    let bankedTime: Double
    let phase     : GameState.TimerPhase

    private var isBank   : Bool   { phase == .banked }
    private var display  : Double { isBank ? bankedTime : blockTime }
    private var displaySeconds: Int { max(0, Int(ceil(display))) }
    private var isWarning: Bool { phase == .block && blockTime <= 10 && blockTime > 3 }
    private var isUrgent : Bool { phase == .block && blockTime <= 3 }

    @State private var pulse           = false
    @State private var spikeScale      : CGFloat = 1.0
    @State private var firedThresholds : Set<Int> = []

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: isBank ? "banknote" : "timer")
                    .font(.system(size: 20, weight: .bold))
                Text(timeString(displaySeconds))
                    .font(Constants.Fonts.rounded(40, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
            }
            .foregroundStyle(
                isBank    ? Constants.Colors.gold    :
                isUrgent  ? Constants.Colors.failure :
                isWarning ? Constants.Colors.warning :
                            Constants.Colors.tile
            )
            .scaleEffect(pulse ? (isUrgent ? 1.12 : 1.06) : 1.0)
            .scaleEffect(spikeScale)
            .animation(.easeInOut(duration: 0.2), value: isBank)
            .animation(.easeInOut(duration: 0.2), value: isWarning)
            .animation(.easeInOut(duration: 0.2), value: isUrgent)

            // When bank is active, show upcoming block time in dim white
            if isBank && blockTime > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "timer")
                        .font(.system(size: 10, weight: .medium))
                    Text(timeString(Int(ceil(blockTime))))
                        .font(Constants.Fonts.rounded(12, weight: .medium))
                        .monospacedDigit()
                }
                .foregroundStyle(Constants.Colors.tile.opacity(0.45))
                .transition(.opacity)
            }
        }
        .onChange(of: isWarning) { _, warn in
            if warn && !isUrgent {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
        .onChange(of: isUrgent) { _, urgent in
            if urgent {
                withAnimation(.easeInOut(duration: 0.28).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            } else if !isWarning {
                withAnimation(.default) { pulse = false }
            }
        }
        // Reset fired set when a new block starts (phase leaves .none)
        .onChange(of: phase) { _, newPhase in
            if newPhase != .none { firedThresholds = [] }
        }
        // One-shot tension spikes — fires once per threshold per block
        .onChange(of: blockTime) { _, newVal in
            guard phase == .block else { return }
            let secs = Int(ceil(newVal))
            checkThresholds(secs)
        }
    }

    private func checkThresholds(_ secs: Int) {
        let entries: [(threshold: Int, peak: CGFloat, totalDuration: Double, haptic: () -> Void)] = [
            (10, 1.10, 0.30, HapticManager.timerWarning),
            (5,  1.15, 0.30, HapticManager.timerUrgent),
            (3,  1.30, 0.25, HapticManager.timerCritical),
            (2,  1.30, 0.25, HapticManager.timerCritical),
            (1,  1.30, 0.25, HapticManager.timerCritical),
        ]
        for entry in entries where secs <= entry.threshold && !firedThresholds.contains(entry.threshold) {
            firedThresholds.insert(entry.threshold)
            fireSpike(peak: entry.peak, totalDuration: entry.totalDuration)
            entry.haptic()
        }
    }

    private func fireSpike(peak: CGFloat, totalDuration: Double) {
        let riseTime = totalDuration * 0.30
        withAnimation(.easeOut(duration: riseTime)) { spikeScale = peak }
        DispatchQueue.main.asyncAfter(deadline: .now() + riseTime) {
            withAnimation(.spring(response: totalDuration * 0.70, dampingFraction: 0.60)) {
                spikeScale = 1.0
            }
        }
    }

    private func timeString(_ secs: Int) -> String {
        secs >= 60
            ? String(format: "%d:%02d", secs / 60, secs % 60)
            : "\(secs)s"
    }
}

// MARK: - Score

private struct ScoreView: View {
    let score: Int

    var body: some View {
        Text("\(score)")
            .font(Constants.Fonts.rounded(26, weight: .bold))
            .foregroundStyle(Constants.Colors.tile)
            .contentTransition(.numericText())
            .animation(.spring(response: 0.3), value: score)
    }
}

// MARK: - Streak badge

/// Shown when the player has solved at least 1 wave in a row.
private struct StreakBadge: View {
    let consecutiveSolves: Int

    @State private var popped = false

    var body: some View {
        if consecutiveSolves >= 1 {
            Text("🔥 \(consecutiveSolves)")
                .font(Constants.Fonts.rounded(15, weight: .bold))
                .foregroundStyle(Constants.Colors.tileText)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Constants.Colors.gold, in: Capsule())
                .scaleEffect(popped ? 1.0 : 0.6)
                .opacity(popped ? 1 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: popped)
                .onAppear { popped = true }
                .onChange(of: consecutiveSolves) {
                    popped = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { popped = true }
                }
        }
    }
}

// MARK: - Wave dots

private struct WaveDotsView: View {
    let total: Int
    let solvedIndices: Set<Int>
    var activeIndex: Int? = nil

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<total, id: \.self) { i in
                let solved = solvedIndices.contains(i)
                let active = activeIndex == i && !solved
                Circle()
                    .fill(solved ? Constants.Colors.gold :
                          active ? Constants.Colors.tile.opacity(0.55) :
                                   Constants.Colors.tile.opacity(0.20))
                    .frame(width: 11, height: 11)
                    .shadow(color: solved ? Constants.Colors.gold.opacity(0.60) : .clear,
                            radius: 6, x: 0, y: 0)
                    .scaleEffect(solved ? 1.15 : active ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: solved)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: active)
            }
        }
    }
}

// MARK: - Selection preview

private struct SelectionPreview: View {
    let word: String
    let streakBonus: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(word.enumerated()), id: \.offset) { _, char in
                Text(String(char))
                    .font(Constants.Fonts.rounded(22, weight: .bold))
                    .foregroundStyle(Constants.Colors.tileText)
                    .frame(width: 36, height: 36)
                    .background(Constants.Colors.gold,
                                in: RoundedRectangle(cornerRadius: 8))
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }

            let base = ScoreCalculator.score(for: word)
            if base > 0 {
                let total = base + streakBonus
                Text(streakBonus > 0 ? "+\(total)  🔥" : "+\(base)")
                    .font(Constants.Fonts.rounded(15, weight: .semibold))
                    .foregroundStyle(Constants.Colors.gold)
                    .padding(.leading, 4)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Constants.Colors.trayBackground)
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.65), value: word)
    }
}
