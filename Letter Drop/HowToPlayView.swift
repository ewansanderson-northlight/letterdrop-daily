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

/// Animated 3×3 grid showing a swipe path S→W→I→P→E spelling "SWIPE".
private struct GameplayDemoCard: View {

    // 3×3 letter grid
    private let grid: [[String]] = [
        ["S", "W", "X"],
        ["Y", "I", "P"],
        ["Z", "Q", "E"]
    ]
    // (row, col) steps forming the swipe path
    private let pathSteps: [(Int, Int)] = [(0,0), (0,1), (1,1), (1,2), (2,2)]

    private let tileSize: CGFloat = 48
    private let tileGap:  CGFloat = 7

    @State private var revealedCount = 0   // how many path tiles are highlighted
    @State private var cleared       = false  // brief flash-clear on submit

    var body: some View {
        VStack(spacing: 0) {
            // ── Grid + swipe trail ──────────────────────────────────────
            GeometryReader { geo in
                ZStack {
                    // Trail line connecting highlighted tiles
                    SwipeTrailShape(
                        steps:    Array(pathSteps.prefix(revealedCount)),
                        tileSize: tileSize,
                        gap:      tileGap
                    )
                    .stroke(
                        Constants.Colors.gold.opacity(cleared ? 0 : 0.65),
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                    )
                    .animation(.easeOut(duration: 0.12), value: revealedCount)
                    .animation(.easeOut(duration: 0.15), value: cleared)

                    // All 9 tiles
                    ForEach(0..<9, id: \.self) { idx in
                        let row    = idx / 3
                        let col    = idx % 3
                        let posIdx = pathSteps.firstIndex(where: { $0.0 == row && $0.1 == col })
                        let isLit  = (posIdx.map { $0 < revealedCount } ?? false) && !cleared
                        DemoTileView(letter: grid[row][col], highlighted: isLit)
                            .position(tileCenter(row: row, col: col, in: geo.size))
                            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: isLit)
                    }

                    // "Swipe!" hint — fades out once the swipe begins
                    VStack {
                        Spacer()
                        Text("Swipe!")
                            .font(Constants.Fonts.rounded(11, weight: .semibold))
                            .foregroundStyle(Constants.Colors.success.opacity(0.75))
                            .opacity(revealedCount == 0 ? 1 : 0)
                            .animation(.easeOut(duration: 0.15), value: revealedCount == 0)
                            .padding(.bottom, 8)
                    }
                }
            }
            .frame(height: 190)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Constants.Colors.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Constants.Colors.tile.opacity(0.08), lineWidth: 1)
                    )
            )

            // ── Mini tray — shows word building as swipe progresses ─────
            DemoTrayView(
                letters:    pathSteps.prefix(cleared ? 0 : revealedCount).map { grid[$0.0][$0.1] },
                totalSlots: 6
            )
            .padding(.top, 10)
        }
        .task { await runLoop() }
    }

    // MARK: Helpers

    private func tileCenter(row: Int, col: Int, in size: CGSize) -> CGPoint {
        let totalW = CGFloat(3) * tileSize + CGFloat(2) * tileGap
        let totalH = CGFloat(3) * tileSize + CGFloat(2) * tileGap
        let ox = (size.width  - totalW) / 2 + tileSize / 2
        let oy = (size.height - totalH) / 2 + tileSize / 2
        return CGPoint(
            x: ox + CGFloat(col) * (tileSize + tileGap),
            y: oy + CGFloat(row) * (tileSize + tileGap)
        )
    }

    // MARK: Animation loop

    private func runLoop() async {
        while !Task.isCancelled {
            // Pause before swipe begins
            try? await Task.sleep(for: .seconds(1.0))
            // Reveal tiles one by one
            for count in 1...pathSteps.count {
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    revealedCount = count
                }
                try? await Task.sleep(for: .seconds(0.32))
            }
            // Hold full word briefly
            try? await Task.sleep(for: .seconds(0.85))
            // Flash-clear (simulate submit)
            withAnimation(.easeOut(duration: 0.15)) { cleared = true }
            try? await Task.sleep(for: .seconds(0.45))
            // Reset for next loop
            withAnimation(.spring(response: 0.3)) {
                revealedCount = 0
                cleared       = false
            }
        }
    }
}

// MARK: - Swipe trail shape

/// Draws a polyline through the centres of the given grid steps.
private struct SwipeTrailShape: Shape {
    let steps:    [(Int, Int)]
    let tileSize: CGFloat
    let gap:      CGFloat

    func path(in rect: CGRect) -> Path {
        guard steps.count > 1 else { return Path() }
        let totalW = CGFloat(3) * tileSize + CGFloat(2) * gap
        let totalH = CGFloat(3) * tileSize + CGFloat(2) * gap
        let ox = (rect.width  - totalW) / 2 + tileSize / 2
        let oy = (rect.height - totalH) / 2 + tileSize / 2
        func pt(_ s: (Int, Int)) -> CGPoint {
            CGPoint(x: ox + CGFloat(s.1) * (tileSize + gap),
                    y: oy + CGFloat(s.0) * (tileSize + gap))
        }
        var p = Path()
        p.move(to: pt(steps[0]))
        steps.dropFirst().forEach { p.addLine(to: pt($0)) }
        return p
    }
}

// MARK: - Demo tile

private struct DemoTileView: View {
    let letter: String
    var highlighted: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 9)
                .fill(highlighted ? Constants.Colors.gold : Constants.Colors.tile)
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
        .scaleEffect(highlighted ? 1.07 : 1.0)
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
         "Combos",
         "Hit a word in every wave to build your combo streak. Each consecutive wave adds a bonus to your score. Miss one and your streak resets."),

        ("tortoise.fill",
         "Slow motion",
         "Hold anywhere on screen (not on a tile) to slow everything down. You have 15 seconds total — use them carefully. The clock pauses while you hold."),

        ("banknote",
         "Banked time",
         "Submit a word before your wave timer runs out and the spare seconds are split across all waves still to come."),

        ("star.fill",
         "Score",
         "Words score points based on their length. Build a combo streak to add bonus points on top. Hit all 6 waves for a Perfect Round bonus."),
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
