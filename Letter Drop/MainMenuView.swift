//
//  MainMenuView.swift
//  Letter Drop
//
//  V2: DROP swipe animation · streak stat cards · URL brand link · sequential pulse
//

import SwiftUI
import Combine

// MARK: - Root

struct MainMenuView: View {
    @EnvironmentObject var gameState: GameState
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @State private var appeared           = false
    @State private var showHowToPlay      = false
    @State private var showStats          = false
    @State private var showHomeShare      = false

    // Sequential pulse states (How to Play → Stats → Share & Compete)
    @State private var howToPlayHighlighted = false
    @State private var statsHighlighted     = false
    @State private var shareHighlighted     = false

    // DROP swipe animation
    @State private var dropSwipePhase: Int  = 0
    @State private var dropSwipeAnimID      = UUID()

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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                appeared = true
            }
            if !reduceMotion {
                startDropSwipeAnimation()
                startPulseSequence()
            }
        }
        .sheet(isPresented: $showHowToPlay) { HowToPlaySheet() }
        .sheet(isPresented: $showStats)     { StatsSheet().environmentObject(gameState) }
    }

    // MARK: - DROP swipe animation

    private func startDropSwipeAnimation() {
        let id = UUID()
        dropSwipeAnimID = id

        func playOnce(after delay: Double) {
            // Each phase lights up one more tile (0=none, 1=D, 2=D-R trail, 3=D-R-O, 4=full)
            let phaseOffsets: [Double] = [0.0, 0.28, 0.56, 0.84]
            for (i, offset) in phaseOffsets.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay + offset) {
                    guard dropSwipeAnimID == id else { return }
                    withAnimation(.easeOut(duration: 0.12)) {
                        dropSwipePhase = i + 1
                    }
                }
            }
            // Reset after holding all tiles lit for ~1s
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 1.9) {
                guard dropSwipeAnimID == id else { return }
                withAnimation(.easeOut(duration: 0.35)) {
                    dropSwipePhase = 0
                }
                // Repeat every ~9 seconds
                playOnce(after: 9.0)
            }
        }

        // First play starts once the tiles have animated in (~0.65s after appear)
        playOnce(after: 0.65)
    }

    // MARK: - Sequential pulse sequence

    private func startPulseSequence() {
        // Starts after the DROP animation has played its first cycle (~1.8s)
        let base = 1.8
        DispatchQueue.main.asyncAfter(deadline: .now() + base) {
            withAnimation(.easeInOut(duration: 0.20)) { howToPlayHighlighted = true }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.20)) { howToPlayHighlighted = false }
                withAnimation(.easeInOut(duration: 0.20)) { statsHighlighted = true }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 0.20)) { statsHighlighted = false }
                    // Share & Compete gets the most prominent pulse (~0.7s)
                    withAnimation(.easeInOut(duration: 0.20)) { shareHighlighted = true }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        withAnimation(.easeInOut(duration: 0.25)) { shareHighlighted = false }
                    }
                }
            }
        }
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

            // "DROP" — individual game tiles with swipe trail overlay
            let tileW: CGFloat = 64
            let tileSpacing: CGFloat = 8

            HStack(spacing: tileSpacing) {
                ForEach(Array("DROP".enumerated()), id: \.offset) { index, char in
                    DropTitleTile(
                        letter:        String(char),
                        index:         index,
                        appeared:      appeared,
                        swipeSelected: dropSwipePhase >= index + 1
                    )
                }
            }
            .overlay(
                // Gold swipe trail connecting tiles as each is "selected"
                Canvas { ctx, size in
                    guard dropSwipePhase >= 2 else { return }
                    let step = tileW + tileSpacing
                    let cy   = size.height / 2
                    let centers = (0..<4).map { i in
                        CGPoint(x: CGFloat(i) * step + tileW / 2, y: cy)
                    }
                    var path = Path()
                    path.move(to: centers[0])
                    for i in 1..<min(dropSwipePhase, 4) {
                        path.addLine(to: centers[i])
                    }
                    // Outer glow pass
                    ctx.stroke(
                        path,
                        with: .color(Constants.Colors.gold.opacity(0.30)),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round)
                    )
                    // Inner glow pass
                    ctx.stroke(
                        path,
                        with: .color(Constants.Colors.gold.opacity(0.55)),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)
                    )
                    // Core line
                    ctx.stroke(
                        path,
                        with: .color(Constants.Colors.gold),
                        style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round)
                    )
                }
                .allowsHitTesting(false)
            )

            // Tagline
            Text("Swipe Fast, Play Daily.")
                .font(Constants.Fonts.rounded(15, weight: .regular))
                .foregroundStyle(Constants.Colors.tile.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.35), value: appeared)
        }
        .background(
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.0, green: 0.58, blue: 0.65).opacity(0.28),
                            Color(red: 0.05, green: 0.08, blue: 0.40).opacity(0.12),
                            .clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 145
                    )
                )
                .scaleEffect(x: 1.8, y: 1.0)
                .blur(radius: 24)
                .allowsHitTesting(false)
        )
    }

    // MARK: - Bottom section

    private var bottomSection: some View {
        VStack(spacing: 0) {

            // Best Score + Streak Days stat cards (always visible)
            StatCardRow(bestScore: gameState.bestScore, streakDays: gameState.currentStreak)
                .padding(.bottom, 20)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.4), value: appeared)

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
            .padding(.bottom, 12)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(.spring(response: 0.45, dampingFraction: 0.7).delay(0.5), value: appeared)

            // Share & Compete — pulses gold as climax of the sequence
            Button { showHomeShare = true } label: {
                HStack(spacing: 7) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Share & Compete!")
                        .font(Constants.Fonts.rounded(15, weight: .semibold))
                }
                .foregroundStyle(
                    shareHighlighted
                        ? Constants.Colors.gold
                        : Constants.Colors.tile.opacity(0.45)
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(shareHighlighted
                              ? Constants.Colors.gold.opacity(0.10)
                              : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            shareHighlighted
                                ? Constants.Colors.gold.opacity(0.70)
                                : Constants.Colors.tile.opacity(0.12),
                            lineWidth: shareHighlighted ? 1.5 : 1
                        )
                )
                .shadow(
                    color: shareHighlighted ? Constants.Colors.gold.opacity(0.35) : .clear,
                    radius: 10
                )
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.22), value: shareHighlighted)
            .padding(.bottom, 20)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.3).delay(0.55), value: appeared)
            .sheet(isPresented: $showHomeShare) {
                ActivitySheet(
                    items: [
                        "Join me in Letter Drop's Daily Challenge — can you beat my score? 🔤⬇️",
                        URL(string: "https://letterdrops.app")!
                    ],
                    isPresented: $showHomeShare
                )
            }

            // Secondary row — How to Play & Stats with sequential pulse
            HStack(spacing: 40) {
                MenuSecondaryButton(title: "How to Play", icon: "questionmark.circle",
                                    highlighted: howToPlayHighlighted) {
                    showHowToPlay = true
                    AnalyticsManager.shared.track(.howToPlayViewed)
                }
                MenuSecondaryButton(title: "Stats", icon: "chart.bar",
                                    highlighted: statsHighlighted) {
                    showStats = true
                }
            }
            .padding(.bottom, 20)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.3).delay(0.6), value: appeared)

            // Brand link — tapping opens unserious.games in browser
            Button {
                if let url = URL(string: "https://unserious.games") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("by unserious.games")
                    .font(Constants.Fonts.rounded(15, weight: .medium))
                    .foregroundStyle(Constants.Colors.tile.opacity(0.28))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 36)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.3).delay(0.70), value: appeared)
        }
    }
}

// MARK: - Drop title tile

/// One of the four cream letter tiles spelling "DROP" in the title.
/// `swipeSelected` switches the tile to a gold fill, mimicking in-game selection.
private struct DropTitleTile: View {
    let letter: String
    let index: Int
    let appeared: Bool
    let swipeSelected: Bool

    private var delay: Double { 0.15 + Double(index) * 0.07 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13)
                .fill(swipeSelected ? Constants.Colors.gold : Constants.Colors.tile)
                .shadow(
                    color: swipeSelected
                        ? Constants.Colors.gold.opacity(0.55)
                        : Constants.Colors.tileShadow.opacity(0.45),
                    radius: swipeSelected ? 10 : 4,
                    x: 2, y: 4
                )

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
        .animation(.easeOut(duration: 0.14), value: swipeSelected)
    }
}

// MARK: - Stat card row (Best Score + Streak Days)

private struct StatCardRow: View {
    let bestScore: Int
    let streakDays: Int

    var body: some View {
        HStack(spacing: 10) {
            StatCard(value: "\(bestScore)", label: "Best Score", icon: "star.fill",
                     iconColor: Constants.Colors.success)
            StatCard(value: "\(streakDays)", label: "Streak Days", icon: "flame.fill",
                     iconColor: Constants.Colors.gold)
        }
    }
}

private struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let iconColor: Color

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iconColor)
            Text(value)
                .font(Constants.Fonts.rounded(40, weight: .bold))
                .foregroundStyle(Constants.Colors.tile)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(Constants.Fonts.rounded(13, weight: .medium))
                .foregroundStyle(Constants.Colors.tile.opacity(0.50))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
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
    let highlighted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                Text(title)
                    .font(Constants.Fonts.rounded(12, weight: .medium))
            }
            .foregroundStyle(highlighted
                ? Constants.Colors.gold
                : Constants.Colors.tile.opacity(0.4))
            .scaleEffect(highlighted ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.22), value: highlighted)
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

// MARK: - Background drifting 5×5 grids

// MARK: - Background (falling grid watermark)

private struct MenuBackground: View {
    var body: some View {
        GeometryReader { geo in
            FallingGridBlock(screenSize: geo.size)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// A single 5×5 ghost grid that falls continuously down the centre of the screen.
/// Tile dimensions match the in-game formula exactly. The inter-block gap is
/// achieved geometrically: the block starts far enough above the viewport that
/// it spends `gapDuration` seconds invisible before entering from the top —
/// so one constant-speed `.repeatForever` animation handles everything.
private struct FallingGridBlock: View {

    let screenSize: CGSize

    @Environment(\.scenePhase) private var scenePhase

    // MARK: Geometry (matches GameScene's tile sizing formula)
    private let tileSize  : CGFloat
    private let blockSide : CGFloat   // width == height (square 5×5 grid)

    // MARK: Timing
    private let fallDuration : Double = 20.0  // seconds to traverse screen top→bottom
    private let gapDuration  : Double = 5.0   // seconds block is hidden above screen
    private var totalDuration: Double { fallDuration + gapDuration }

    // MARK: Y positions (block centre)
    private let startY: CGFloat   // well above screen — block is invisible here
    private let endY  : CGFloat   // just below screen

    // MARK: Fade zone (screen-space fractions, top→bottom)
    // Starts where the block reaches the top of the stat cards (~59% down),
    // fades to fully transparent over 175 pt — roughly Play button level.
    private var fadeTopFrac: Double { 0.59 }
    private var fadeBotFrac: Double { fadeTopFrac + 175 / Double(screenSize.height) }

    @State private var offsetY: CGFloat

    init(screenSize: CGSize) {
        self.screenSize = screenSize

        let gap    = Constants.Game.tileGap
        let margin = Constants.Game.tileMargin
        let ts     = (screenSize.width - 2 * margin - 4 * gap) / 5
        let side   = 5 * ts + 4 * gap
        tileSize  = ts
        blockSide = side

        // Speed so the visible traversal takes exactly `fallDuration` seconds.
        // The block also travels `gapDuration` seconds of distance while off-screen
        // above, which creates the pause between repetitions with zero extra timers.
        let speed     = Double(screenSize.height + side) / fallDuration
        let gapTravel = CGFloat(speed * gapDuration)
        let sy        = -(side / 2) - gapTravel

        startY  = sy
        endY    = screenSize.height + side / 2
        _offsetY = State(initialValue: sy)
    }

    var body: some View {
        VStack(spacing: Constants.Game.tileGap) {
            ForEach(0..<5, id: \.self) { _ in
                HStack(spacing: Constants.Game.tileGap) {
                    ForEach(0..<5, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: Constants.Game.tileCorner)
                            .fill(Constants.Colors.tile)
                            .overlay(
                                RoundedRectangle(cornerRadius: Constants.Game.tileCorner)
                                    .strokeBorder(Constants.Colors.tile, lineWidth: 1)
                            )
                            .frame(width: tileSize, height: tileSize)
                    }
                }
            }
        }
        .opacity(0.22)
        .position(x: screenSize.width / 2, y: offsetY)
        // Screen-space gradient mask: opaque above the stat cards, fades to
        // fully transparent ~175 pt lower (≈ Play button level).
        // Because .position() makes the view's layout frame equal the full
        // parent frame, this gradient is fixed in screen coordinates — the
        // block fades out as it descends into the lower UI zone regardless
        // of where it currently sits in its fall path.
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .white, location: 0),
                    .init(color: .white, location: fadeTopFrac),
                    .init(color: .clear,  location: fadeBotFrac),
                    .init(color: .clear,  location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear { beginFall() }
        .onChange(of: scenePhase) { _, phase in
            // Restart cleanly from off-screen when returning from background
            if phase == .active { beginFall() }
        }
    }

    /// Snaps the block to `startY` without animation, then starts the linear fall.
    private func beginFall() {
        var snap = Transaction(animation: nil)
        snap.disablesAnimations = true
        withTransaction(snap) { offsetY = startY }
        withAnimation(.linear(duration: totalDuration).repeatForever(autoreverses: false)) {
            offsetY = endY
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

#Preview("With best score and streak") {
    let state = GameState()
    state.bestScore = 74
    state.gamesPlayed = 7
    return ZStack {
        Constants.Colors.background.ignoresSafeArea()
        MainMenuView().environmentObject(state)
    }
}
