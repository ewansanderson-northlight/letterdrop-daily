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

            // Best word flash
            if let flash = gameState.bestWordFlash {
                BestWordOverlay(flash: flash)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            // Ready-Set-Go countdown
            if let count = gameState.countdownValue {
                CountdownOverlay(value: count)
                    .allowsHitTesting(false)
            }

            // Word preview — above the active block
            if !gameState.currentSelection.isEmpty {
                WordPreviewOverlay(
                    word:          gameState.currentSelection,
                    multiplier:    gameState.currentMultiplier,
                    blockTopUIKitY: gameState.blockTopUIKitY
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

            // Combo boost flash — centre screen on multiplier increase
            if let boost = gameState.comboBoostFlash {
                ComboBoostOverlay(multiplier: boost)
                    .transition(.opacity.combined(with: .scale(scale: 0.75)))
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: gameState.showMissFeedback)
        .animation(.easeOut(duration: 0.55), value: gameState.bestWordFlash != nil)
        .animation(.easeOut(duration: 0.25),   value: gameState.countdownValue)
        .animation(.spring(response: 0.28, dampingFraction: 0.75),
                   value: gameState.currentSelection.isEmpty)
        .animation(.easeOut(duration: 0.55),
                   value: gameState.isSlowMoActive)
        .animation(.spring(response: 0.28, dampingFraction: 0.70),
                   value: gameState.waveBanner != nil)
        .animation(.spring(response: 0.30, dampingFraction: 0.65),
                   value: gameState.comboBoostFlash != nil)
    }
}

// MARK: - Word preview overlay (above the active block)

private struct WordPreviewOverlay: View {
    let word          : String
    let multiplier    : Int
    let blockTopUIKitY: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            // Push down to just above the block's top edge (min 140 to stay below header)
            Spacer()
                .frame(height: blockTopUIKitY > 0
                       ? max(140, blockTopUIKitY - 64)
                       : 280)
            SelectionPreview(word: word, multiplier: multiplier)
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
        .onChange(of: value) { _ in scale = 0.35; opacity = 0; pop() }
    }

    private func pop() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.62)) {
            scale = 1.0; opacity = 1.0
        }
    }
}

// MARK: - Best word flash overlay

private struct BestWordOverlay: View {
    let flash: GameState.BestWordFlash

    var body: some View {
        VStack {
            Spacer()
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
            .padding(.bottom, 110)
        }
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
            .onChange(of: consecutiveSolves) { newVal in
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

// MARK: - Combo boost overlay

private struct ComboBoostOverlay: View {
    let multiplier: Int

    @State private var scale:   CGFloat = 0.6
    @State private var opacity: Double  = 0

    var body: some View {
        VStack(spacing: 2) {
            Text("COMBO BOOST")
                .font(Constants.Fonts.rounded(13, weight: .semibold))
                .foregroundStyle(Constants.Colors.tile.opacity(0.65))
                .tracking(3)
            Text("×\(multiplier)")
                .font(Constants.Fonts.rounded(76, weight: .bold))
                .foregroundStyle(Constants.Colors.gold)
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.62)) {
                scale = 1.0; opacity = 1.0
            }
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
                        MultiplierBadge(multiplier: gameState.currentMultiplier)
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
        .onChange(of: isActive) { active in
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
    private var isWarning: Bool { phase == .block && blockTime <= 15 && blockTime > 5 }
    private var isUrgent : Bool { phase == .block && blockTime <= 5 }

    @State private var pulse = false

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
        .onChange(of: isWarning) { warn in
            if warn && !isUrgent {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
        .onChange(of: isUrgent) { urgent in
            if urgent {
                withAnimation(.easeInOut(duration: 0.28).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            } else if !isWarning {
                withAnimation(.default) { pulse = false }
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

// MARK: - Multiplier badge

/// Shown when the player has a streak of 2+ consecutive solved waves.
private struct MultiplierBadge: View {
    let multiplier: Int

    @State private var popped = false

    var body: some View {
        if multiplier > 1 {
            HStack(spacing: 3) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("×\(multiplier)")
                    .font(Constants.Fonts.rounded(15, weight: .bold))
            }
            .foregroundStyle(Constants.Colors.tileText)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Constants.Colors.gold, in: Capsule())
            .scaleEffect(popped ? 1.0 : 0.6)
            .opacity(popped ? 1 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: popped)
            .onAppear { popped = true }
            .onChange(of: multiplier) { _ in
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
    let multiplier: Int

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
                let boosted = base * multiplier
                Group {
                    if multiplier > 1 {
                        Text("+\(boosted)  ×\(multiplier)")
                            .foregroundStyle(Constants.Colors.gold)
                    } else {
                        Text("+\(base)")
                            .foregroundStyle(Constants.Colors.gold)
                    }
                }
                .font(Constants.Fonts.rounded(15, weight: .semibold))
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
