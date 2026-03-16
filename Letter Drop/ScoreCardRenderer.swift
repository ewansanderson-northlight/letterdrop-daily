//
//  ScoreCardRenderer.swift
//  Letter Drop
//
//  Renders a 1080×1080 SwiftUI score card to UIImage for sharing.
//  No network calls — everything comes from local GameState values.
//

import SwiftUI

// MARK: - Card view

struct ScoreCardView: View {
    let score: Int
    let maxScore: Int
    let bestWord: FoundWord?
    let dateString: String

    private var starCount: Int {
        guard maxScore > 0 else { return 1 }
        let pct = Double(score) / Double(maxScore)
        return pct >= 0.70 ? 3 : pct >= 0.35 ? 2 : 1
    }

    var body: some View {
        ZStack {
            Constants.Colors.background

            VStack(spacing: 0) {
                Spacer()

                // App name + tagline
                VStack(spacing: 10) {
                    Text("LETTER DROP")
                        .font(Constants.Fonts.rounded(72, weight: .bold))
                        .foregroundStyle(Constants.Colors.tile)
                        .tracking(8)
                    Text("Daily Word Challenge")
                        .font(Constants.Fonts.rounded(28, weight: .medium))
                        .foregroundStyle(Constants.Colors.tile.opacity(0.50))
                }
                .padding(.bottom, 64)

                // Score
                VStack(spacing: 14) {
                    Text("\(score)")
                        .font(Constants.Fonts.rounded(180, weight: .bold))
                        .foregroundStyle(Constants.Colors.scoreGold)
                        .monospacedDigit()
                    if maxScore > 0 {
                        Text("/ \(maxScore) max")
                            .font(Constants.Fonts.rounded(34, weight: .regular))
                            .foregroundStyle(Constants.Colors.tile.opacity(0.38))
                    }
                    HStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: "star.fill")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(Constants.Colors.gold.opacity(i < starCount ? 1.0 : 0.15))
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(.bottom, 60)

                // Best word pill
                if let best = bestWord {
                    HStack(spacing: 18) {
                        Text("BEST WORD")
                            .font(Constants.Fonts.rounded(22, weight: .semibold))
                            .foregroundStyle(Constants.Colors.tile.opacity(0.45))
                        Text(best.word)
                            .font(Constants.Fonts.rounded(30, weight: .bold))
                            .foregroundStyle(Constants.Colors.tile)
                        Text("+\(best.score) pts")
                            .font(Constants.Fonts.rounded(22, weight: .semibold))
                            .foregroundStyle(Constants.Colors.scoreGold)
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 22)
                    .background(Constants.Colors.trayBackground, in: RoundedRectangle(cornerRadius: 22))
                    .padding(.bottom, 44)
                }

                // Date
                Text(dateString)
                    .font(Constants.Fonts.rounded(26, weight: .medium))
                    .foregroundStyle(Constants.Colors.tile.opacity(0.32))

                Spacer()

                // Branding strip
                Rectangle()
                    .fill(Constants.Colors.tile.opacity(0.08))
                    .frame(height: 1)
                    .padding(.horizontal, 80)
                    .padding(.bottom, 26)

                Text("letterdrops.app")
                    .font(Constants.Fonts.rounded(24, weight: .medium))
                    .foregroundStyle(Constants.Colors.tile.opacity(0.22))
                    .padding(.bottom, 56)
            }
        }
        .frame(width: 1080, height: 1080)
    }
}

// MARK: - Renderer

@MainActor
func renderScoreCard(
    score: Int,
    maxScore: Int,
    bestWord: FoundWord?,
    dateString: String
) -> UIImage? {
    let view = ScoreCardView(
        score: score,
        maxScore: maxScore,
        bestWord: bestWord,
        dateString: dateString
    )
    let renderer = ImageRenderer(content: view)
    renderer.scale = 1.0
    return renderer.uiImage
}
