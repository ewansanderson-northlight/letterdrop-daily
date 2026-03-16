//
//  MainMenuView.swift
//  Letter Drop
//

import SwiftUI
import Combine

// MARK: - Root

struct MainMenuView: View {
    @EnvironmentObject var gameState: GameState

    @State private var appeared           = false
    @State private var showHowToPlay      = false
    @State private var showStats          = false
    @State private var showAbout          = false
    @State private var buttonsHighlighted = false

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

            // About overlay
            if showAbout {
                UnseriousAboutOverlay(isPresented: $showAbout)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .onAppear {
            appeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                appeared = true
            }
            // Pulse secondary buttons gold 3× after main animations settle
            for i in 0..<3 {
                let on  = 0.90 + Double(i) * 0.55
                let off = on  + 0.32
                DispatchQueue.main.asyncAfter(deadline: .now() + on)  { buttonsHighlighted = true  }
                DispatchQueue.main.asyncAfter(deadline: .now() + off) { buttonsHighlighted = false }
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
                MenuSecondaryButton(title: "How to Play", icon: "questionmark.circle",
                                    highlighted: buttonsHighlighted) {
                    showHowToPlay = true
                }
                MenuSecondaryButton(title: "Stats", icon: "chart.bar",
                                    highlighted: buttonsHighlighted) {
                    showStats = true
                }
            }
            .padding(.bottom, 20)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.3).delay(0.6), value: appeared)

            Button { showAbout = true } label: {
                Text("by unserious.games")
                    .font(Constants.Fonts.rounded(13, weight: .medium))
                    .foregroundStyle(Constants.Colors.tile.opacity(0.18))
            }
            .buttonStyle(.plain)
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

private struct MenuBackground: View {
    // x-fraction, fall duration, initial-y fraction (0=top, 1=bottom)
    private let grids: [(CGFloat, Double, CGFloat)] = [
        (0.15, 16.0, 0.0),
        (0.48, 12.0, 0.55),
        (0.78, 18.0, 0.25),
        (0.93, 10.5, 0.75),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(grids.indices, id: \.self) { i in
                let (xFrac, duration, startFrac) = grids[i]
                DriftingGridSilhouette(
                    x:        geo.size.width * xFrac,
                    duration: duration,
                    startY:   -60 + (geo.size.height + 120) * startFrac,
                    endY:     geo.size.height + 60
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct DriftingGridSilhouette: View {
    let x: CGFloat
    let duration: Double
    let startY: CGFloat
    let endY: CGFloat

    private let cellSize: CGFloat = 9
    private let cellGap:  CGFloat = 2
    private let n = 5

    @State private var y: CGFloat

    init(x: CGFloat, duration: Double, startY: CGFloat, endY: CGFloat) {
        self.x = x; self.duration = duration; self.startY = startY; self.endY = endY
        _y = State(initialValue: startY)
    }

    var body: some View {
        VStack(spacing: cellGap) {
            ForEach(0..<n, id: \.self) { _ in
                HStack(spacing: cellGap) {
                    ForEach(0..<n, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Constants.Colors.tile)
                            .frame(width: cellSize, height: cellSize)
                    }
                }
            }
        }
        .opacity(0.07)
        .position(x: x, y: y)
        .onAppear {
            withAnimation(
                .linear(duration: duration * (1.0 - Double((startY + 60) / (endY + 60))))
                .repeatForever(autoreverses: false)
            ) {
                y = endY
            }
        }
    }
}

// MARK: - Unserious Games about overlay

private struct UnseriousAboutOverlay: View {
    @Binding var isPresented: Bool

    @State private var cardAppeared = false
    @State private var dotPhase     = 0

    private var dotsString: String {
        String(repeating: ".", count: dotPhase + 1)
    }

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.60)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Card
            VStack(spacing: 0) {
                // Close button row
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Constants.Colors.tileText.opacity(0.35))
                            .padding(9)
                            .background(Constants.Colors.tileText.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 16)
                .padding(.top, 16)

                // Logo
                Image("Unserious Games Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 210)
                    .padding(.top, 4)
                    .padding(.bottom, 4)

                // Tagline
                Text("Human ideas, robot tools")
                    .font(Constants.Fonts.rounded(15, weight: .semibold))
                    .foregroundStyle(Constants.Colors.tileText.opacity(0.70))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)

                // Animated "More coming soon..."
                HStack(spacing: 0) {
                    Text("More coming soon")
                        .font(Constants.Fonts.rounded(13, weight: .regular))
                        .foregroundStyle(Constants.Colors.tileText.opacity(0.38))
                    Text(dotsString)
                        .font(Constants.Fonts.rounded(13, weight: .regular))
                        .foregroundStyle(Constants.Colors.tileText.opacity(0.38))
                        .frame(minWidth: 18, alignment: .leading)
                        .animation(.none, value: dotsString)
                }
                .padding(.bottom, 32)
            }
            .background(Constants.Colors.tile, in: RoundedRectangle(cornerRadius: 26))
            .padding(.horizontal, 36)
            .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 8)
            .scaleEffect(cardAppeared ? 1.0 : 0.72)
            .opacity(cardAppeared ? 1.0 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.60)) {
                cardAppeared = true
            }
        }
        .onReceive(Timer.publish(every: 0.48, on: .main, in: .common).autoconnect()) { _ in
            dotPhase = (dotPhase + 1) % 3
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.16)) {
            cardAppeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            isPresented = false
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
