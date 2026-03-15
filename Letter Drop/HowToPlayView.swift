//
//  HowToPlayView.swift
//  Letter Drop
//

import SwiftUI

// MARK: - Sheet root

struct HowToPlaySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var revealed = false

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // ── Animated demo ──────────────────────────────
                        SectionHeader(title: "HOW IT WORKS")
                            .padding(.bottom, 12)
                            .revealEffect(revealed: revealed, delay: 0.0)

                        GameplayDemoCard()
                            .padding(.bottom, 32)
                            .revealEffect(revealed: revealed, delay: 0.05)

                        // ── Rules ───────────────────────────────────────
                        SectionHeader(title: "THE RULES")
                            .padding(.bottom, 12)
                            .revealEffect(revealed: revealed, delay: 0.1)

                        RulesSection(revealed: revealed)
                            .padding(.bottom, 32)

                        // ── Letter values ───────────────────────────────
                        SectionHeader(title: "LETTER VALUES")
                            .padding(.bottom, 4)
                            .revealEffect(revealed: revealed, delay: 0.45)

                        Text("Rarer letters score more. Longer words earn a bonus multiplier.")
                            .font(Constants.Fonts.rounded(13, weight: .regular))
                            .foregroundStyle(Constants.Colors.tile.opacity(0.4))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 12)
                            .revealEffect(revealed: revealed, delay: 0.48)

                        LetterValueGrid()
                            .padding(.bottom, 32)
                            .revealEffect(revealed: revealed, delay: 0.5)

                        // ── Dismiss ─────────────────────────────────────
                        Button { dismiss() } label: {
                            Text("Got it")
                                .font(Constants.Fonts.rounded(17, weight: .semibold))
                                .foregroundStyle(Constants.Colors.tileText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Constants.Colors.tile,
                                            in: RoundedRectangle(cornerRadius: 14))
                        }
                        .revealEffect(revealed: revealed, delay: 0.55)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 44)
                }
            }
            .navigationTitle("How to Play")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Constants.Colors.background, for: .navigationBar)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                revealed = true
            }
        }
    }
}

// MARK: - Reveal modifier

private extension View {
    /// Fades in and slides up when `revealed` becomes true, with an optional delay.
    func revealEffect(revealed: Bool, delay: Double) -> some View {
        self
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 14)
            .animation(.spring(response: 0.45, dampingFraction: 0.75).delay(delay),
                       value: revealed)
    }
}

// MARK: - Section header

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(Constants.Fonts.rounded(11, weight: .semibold))
            .foregroundStyle(Constants.Colors.tile.opacity(0.4))
            .tracking(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Gameplay demo card

private struct GameplayDemoCard: View {

    // Falling tile sequence — spells "WORD" with the pre-filled "W"
    private let sequence = ["O", "R", "D"]

    @State private var trayLetters: [String] = ["W"]
    @State private var sequenceIndex  = 0
    @State private var tileVisible    = true   // false while "collecting"

    // Independent bobbing offsets for each tile
    @State private var bob1: CGFloat = 0
    @State private var bob2: CGFloat = 3
    @State private var bob3: CGFloat = -3

    // Tap ring pulsing
    @State private var ringScale:   CGFloat = 0.85
    @State private var ringOpacity: CGFloat = 0.75

    private var currentLetter: String { sequence[sequenceIndex % sequence.count] }

    var body: some View {
        VStack(spacing: 0) {
            // ── Falling tiles area ──────────────────────────────────────
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                // Static tile B
                DemoTileView(letter: "T")
                    .position(x: w * 0.58, y: h * 0.38 + bob2)

                // Static tile C
                DemoTileView(letter: "A")
                    .position(x: w * 0.83, y: h * 0.55 + bob3)

                // Featured tile — tap target
                ZStack {
                    // Pulsing ring
                    Circle()
                        .strokeBorder(Constants.Colors.success, lineWidth: 2)
                        .frame(width: 54, height: 54)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity * (tileVisible ? 1 : 0))

                    // The tile itself
                    DemoTileView(letter: currentLetter)
                        .scaleEffect(tileVisible ? 1.0 : 1.3)
                        .opacity(tileVisible ? 1.0 : 0.0)
                }
                .position(x: w * 0.24, y: h * 0.42 + bob1)

                // "Tap!" hint
                Text("Tap!")
                    .font(Constants.Fonts.rounded(11, weight: .semibold))
                    .foregroundStyle(Constants.Colors.success.opacity(0.75))
                    .position(x: w * 0.24, y: h * 0.42 + bob1 + 36)
                    .opacity(tileVisible ? 1 : 0)
            }
            .frame(height: 130)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Constants.Colors.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Constants.Colors.tile.opacity(0.08), lineWidth: 1)
                    )
            )

            // ── Mini tray ───────────────────────────────────────────────
            DemoTrayView(letters: trayLetters, totalSlots: 6)
                .padding(.top, 10)
        }
        .task {
            startBobbing()
            startRingPulse()
            await runCollectionLoop()
        }
    }

    // MARK: Bobbing

    private func startBobbing() {
        withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
            bob1 = 9
        }
        withAnimation(.easeInOut(duration: 2.3).repeatForever(autoreverses: true)) {
            bob2 = -11
        }
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            bob3 = 7
        }
    }

    // MARK: Tap ring pulse

    private func startRingPulse() {
        withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
            ringScale   = 1.85
            ringOpacity = 0
        }
    }

    // MARK: Async collection loop

    private func runCollectionLoop() async {
        while !Task.isCancelled {
            // Idle — let the ring pulse for a beat
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { break }

            // Collect: tile scales up and disappears
            withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) {
                tileVisible = false
            }
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { break }

            // Tray gains the letter
            let letter = sequence[sequenceIndex % sequence.count]
            withAnimation(.spring(response: 0.38, dampingFraction: 0.62)) {
                trayLetters.append(letter)
            }
            sequenceIndex += 1

            // Tile respawns
            try? await Task.sleep(for: .seconds(0.25))
            withAnimation(.spring(response: 0.3)) {
                tileVisible = true
            }

            // Pause before next collect
            try? await Task.sleep(for: .seconds(1.0))
            guard !Task.isCancelled else { break }

            // Tray full → clear and restart
            if trayLetters.count >= 4 {
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation(.spring(response: 0.4)) {
                    trayLetters  = ["W"]
                    sequenceIndex = 0
                }
                try? await Task.sleep(for: .seconds(0.6))
            }
        }
    }
}

// MARK: - Demo tile

private struct DemoTileView: View {
    let letter: String

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 9)
                .fill(Constants.Colors.tile)
                .shadow(color: Constants.Colors.tileShadow.opacity(0.35), radius: 3, x: 1, y: 2)

            Text(letter)
                .font(Constants.Fonts.rounded(21, weight: .semibold))
                .foregroundStyle(Constants.Colors.tileText)
                .frame(width: 42, height: 42)

            Text("\(LetterValues.value(for: letter))")
                .font(Constants.Fonts.rounded(8, weight: .regular))
                .foregroundStyle(Constants.Colors.tileText.opacity(0.45))
                .padding(.trailing, 3)
                .padding(.bottom, 2)
        }
        .frame(width: 42, height: 42)
    }
}

// MARK: - Demo tray

private struct DemoTrayView: View {
    let letters: [String]
    let totalSlots: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<totalSlots, id: \.self) { i in
                if i < letters.count {
                    DemoTrayTile(letter: letters[i])
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.15, anchor: .bottom)
                                    .combined(with: .opacity),
                                removal: .opacity
                            )
                        )
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Constants.Colors.tile.opacity(0.13), lineWidth: 1.5)
                        .frame(width: 32, height: 32)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Constants.Colors.trayBackground, in: RoundedRectangle(cornerRadius: 12))
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: letters.count)
    }
}

private struct DemoTrayTile: View {
    let letter: String
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Constants.Colors.tile)
            Text(letter)
                .font(Constants.Fonts.rounded(16, weight: .semibold))
                .foregroundStyle(Constants.Colors.tileText)
                .frame(width: 32, height: 32)
            Text("\(LetterValues.value(for: letter))")
                .font(Constants.Fonts.rounded(7, weight: .regular))
                .foregroundStyle(Constants.Colors.tileText.opacity(0.45))
                .padding(.trailing, 2)
                .padding(.bottom, 1)
        }
        .frame(width: 32, height: 32)
    }
}

// MARK: - Rules section

private struct RulesSection: View {
    let revealed: Bool

    private let steps: [(String, String, String)] = [
        ("hand.draw",
         "Build a word",
         "Swipe across adjacent letters to form a word — up, down, sideways or diagonal. No tile can be used twice."),

        ("exclamationmark.circle.fill",
         "One shot per wave",
         "Each wave gives you one submission. Choose wisely — a miss resets your combo."),

        ("timer",
         "Beat the clock",
         "Every wave has its own timer. Submit early and your leftover time is shared equally across the remaining waves."),

        ("bolt.fill",
         "Combo multiplier",
         "String together successful waves to build your combo. Miss one and it resets."),

        ("tortoise.fill",
         "Slow motion",
         "Hold anywhere on screen (not on a tile) to slow everything down. You have 15 seconds total — use them carefully. The clock pauses while you hold."),

        ("banknote",
         "Banked time",
         "Submit a word before your wave timer runs out and the spare seconds are split across all waves still to come."),

        ("star.fill",
         "Score",
         "Your score is word length × combo multiplier. The harder the wave, the bigger the words available."),
    ]

    var body: some View {
        VStack(spacing: 2) {
            ForEach(steps.indices, id: \.self) { i in
                let (icon, title, detail) = steps[i]
                RuleStepRow(icon: icon, title: title, detail: detail, index: i)
                    .revealEffect(revealed: revealed, delay: 0.15 + Double(i) * 0.06)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct RuleStepRow: View {
    let icon: String
    let title: String
    let detail: String
    let index: Int

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Icon badge
            ZStack {
                Circle()
                    .fill(Constants.Colors.success.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Constants.Colors.success)
            }
            .padding(.top, 2)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Constants.Fonts.rounded(15, weight: .semibold))
                    .foregroundStyle(Constants.Colors.tile)
                Text(detail)
                    .font(Constants.Fonts.rounded(13, weight: .regular))
                    .foregroundStyle(Constants.Colors.tile.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Constants.Colors.trayBackground)
    }
}

// MARK: - Letter value grid

private struct LetterValueGrid: View {
    // All 26 letters sorted ascending by point value, then alphabetically
    private let letters: [String] = {
        let all: [(String, Int)] = [
            ("A",1),("B",3),("C",3),("D",2),("E",1),("F",4),("G",2),("H",4),
            ("I",1),("J",8),("K",5),("L",1),("M",3),("N",1),("O",1),("P",3),
            ("Q",10),("R",1),("S",1),("T",1),("U",1),("V",4),("W",4),("X",8),
            ("Y",4),("Z",10)
        ]
        return all.sorted { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0 < $1.0 }.map(\.0)
    }()

    private let columns = Array(repeating: GridItem(.fixed(38), spacing: 6), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(letters, id: \.self) { letter in
                    LetterValueTile(letter: letter)
                }
            }

            // Legend
            HStack(spacing: 16) {
                legendItem(color: Constants.Colors.tile.opacity(0.9), label: "Common  1–2 pts")
                legendItem(color: Constants.Colors.tile.opacity(0.65), label: "Uncommon  3–5 pts")
                legendItem(color: Constants.Colors.success.opacity(0.85), label: "Rare  8–10 pts")
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(Constants.Colors.trayBackground, in: RoundedRectangle(cornerRadius: 14))
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(Constants.Fonts.rounded(10, weight: .regular))
                .foregroundStyle(Constants.Colors.tile.opacity(0.4))
        }
    }
}

private struct LetterValueTile: View {
    let letter: String
    private var value: Int { LetterValues.value(for: letter) }

    // Rare letters (8+) get a subtle green tint to signal high value
    private var tileColor: Color {
        value >= 8 ? Constants.Colors.success.opacity(0.25) : Constants.Colors.tile
    }
    private var textColor: Color {
        value >= 8 ? Constants.Colors.success : Constants.Colors.tileText
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 8)
                .fill(tileColor)

            Text(letter)
                .font(Constants.Fonts.rounded(18, weight: .semibold))
                .foregroundStyle(textColor)
                .frame(width: 38, height: 38)

            Text("\(value)")
                .font(Constants.Fonts.rounded(8, weight: .regular))
                .foregroundStyle(textColor.opacity(0.55))
                .padding(.trailing, 3)
                .padding(.bottom, 2)
        }
        .frame(width: 38, height: 38)
    }
}

// MARK: - Preview

#Preview {
    HowToPlaySheet()
}
