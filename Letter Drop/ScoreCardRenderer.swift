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
    let combosFound: Int
    let totalWaves: Int
    let streak: Int
    let dateString: String

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()

                // App name + tagline
                VStack(spacing: 10) {
                    Text("LETTER DROP")
                        .font(Constants.Fonts.rounded(72, weight: .bold))
                        .foregroundStyle(Constants.Colors.tile)
                        .tracking(8)
                    Text("Swipe Fast, Play Daily.")
                        .font(Constants.Fonts.rounded(28, weight: .medium))
                        .foregroundStyle(Constants.Colors.tile.opacity(0.50))
                }
                .padding(.bottom, 64)

                // Score
                Text("\(score)")
                    .font(Constants.Fonts.rounded(180, weight: .bold))
                    .foregroundStyle(Constants.Colors.scoreGold)
                    .monospacedDigit()
                    .padding(.bottom, 36)

                // Combos + Streak
                HStack(spacing: 20) {
                    Text("\(combosFound)/\(totalWaves) Combos")
                    Text("·")
                        .foregroundStyle(Constants.Colors.tile.opacity(0.30))
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(Constants.Colors.scoreGold)
                        Text("Day \(streak) Streak")
                    }
                }
                .font(Constants.Fonts.rounded(36, weight: .semibold))
                .foregroundStyle(Constants.Colors.tile.opacity(0.75))
                .padding(.bottom, 52)

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
        .background(Constants.Colors.background)
        .frame(width: 1080, height: 1080)
    }
}

// MARK: - Renderer

@MainActor
func renderScoreCard(
    score: Int,
    combosFound: Int,
    totalWaves: Int,
    streak: Int,
    dateString: String
) -> UIImage? {
    let view = ScoreCardView(
        score: score,
        combosFound: combosFound,
        totalWaves: totalWaves,
        streak: streak,
        dateString: dateString
    )
    let renderer = ImageRenderer(content: view)
    renderer.scale = 1.0
    return renderer.uiImage
}
