//
//  LetterTile.swift
//  Letter Drop
//
//  SpriteKit node representing a single falling letter tile.
//  All touch handling is done by GameScene — this node is purely visual.
//

import SpriteKit
import SwiftUI

final class LetterTile: SKNode {

    // MARK: - Properties

    let tileID: UUID
    let letter: String
    let pointValue: Int

    /// Set to true by GameScene the moment a tap is registered, preventing
    /// a second collection before the collect animation finishes.
    var isCollected: Bool = false

    // MARK: - Visual child nodes

    private let shadow: SKShapeNode
    private let tileBackground: SKShapeNode
    private let innerHighlight: SKShapeNode
    private let letterLabel: SKLabelNode
    private let scoreLabel: SKLabelNode

    // MARK: - Init

    init(letter: String, id: UUID = UUID()) {
        self.tileID = id
        self.letter = letter.uppercased()
        self.pointValue = LetterValues.value(for: letter)

        let side = Constants.Layout.tileSize
        let tileSize = CGSize(width: side, height: side)
        let radius = Constants.Layout.tileCorner
        let value = LetterValues.value(for: letter)

        // Drop shadow — deeper offset for added depth
        shadow = SKShapeNode(rectOf: tileSize, cornerRadius: radius)
        shadow.fillColor = UIColor(Constants.Colors.tileShadow).withAlphaComponent(0.45)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 2.5, y: -4)
        shadow.zPosition = -1

        // Tile background — warm-tinted for high-value letters
        tileBackground = SKShapeNode(rectOf: tileSize, cornerRadius: radius)
        tileBackground.fillColor = Self.tileColor(for: value)
        tileBackground.strokeColor = UIColor(Constants.Colors.tileShadow).withAlphaComponent(0.20)
        tileBackground.lineWidth = 1.0

        // Inner highlight — thin strip near the top edge gives a raised/bevel look
        let highlightSize = CGSize(width: side - 18, height: 4)
        innerHighlight = SKShapeNode(rectOf: highlightSize, cornerRadius: 2)
        innerHighlight.fillColor = UIColor.white.withAlphaComponent(0.20)
        innerHighlight.strokeColor = .clear
        innerHighlight.position = CGPoint(x: 0, y: side / 2 - 9)
        innerHighlight.zPosition = 1

        // Large centred letter glyph
        // "SFRounded-Semibold" resolves to SF Pro Rounded on device.
        // Fall back gracefully on simulator if the font is unavailable.
        letterLabel = SKLabelNode(text: letter.uppercased())
        letterLabel.fontName = "SFRounded-Semibold"
        letterLabel.fontSize = 26
        letterLabel.fontColor = UIColor(Constants.Colors.tileText)
        letterLabel.verticalAlignmentMode = .center
        letterLabel.horizontalAlignmentMode = .center
        letterLabel.position = CGPoint(x: 0, y: 3)

        // Small subscript Scrabble score — bottom-right corner
        // More visible on high-value tiles
        let scoreLabelAlpha: CGFloat = value >= 5 ? 0.65 : 0.45
        scoreLabel = SKLabelNode(text: "\(value)")
        scoreLabel.fontName = "SFRounded-Regular"
        scoreLabel.fontSize = 10
        scoreLabel.fontColor = UIColor(Constants.Colors.tileText).withAlphaComponent(scoreLabelAlpha)
        scoreLabel.verticalAlignmentMode = .bottom
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.position = CGPoint(x: side / 2 - 5, y: -side / 2 + 4)

        super.init()

        addChild(shadow)
        addChild(tileBackground)
        addChild(innerHighlight)
        addChild(letterLabel)
        addChild(scoreLabel)

        // isUserInteractionEnabled intentionally left false (default).
        // GameScene uses nodes(at:) for hit detection, which works regardless of this flag.
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not used")
    }

    // MARK: - Value-based tile colour

    /// Returns a cream-to-amber fill colour based on the letter's Scrabble value.
    /// High-value letters (K, J, X, Q, Z) have a warm amber hue so they stand out.
    private static func tileColor(for value: Int) -> UIColor {
        switch value {
        case 1...3:
            // Standard cream
            return UIColor(Constants.Colors.tile)
        case 4...5:
            // Warm cream — barely noticeable but slightly richer
            return UIColor(red: 0.97, green: 0.91, blue: 0.76, alpha: 1)
        default:
            // Amber gold for 8+ (J, X, Q, Z)
            return UIColor(red: 0.99, green: 0.87, blue: 0.58, alpha: 1)
        }
    }

    // MARK: - Animations

    /// Slides in from alpha 0 / scale 0.6 to full size. Call immediately after
    /// adding the tile to the scene (tile should already have alpha=0, scale=0.6).
    func playEntranceAnimation() {
        let appear = SKAction.group([
            SKAction.fadeIn(withDuration: 0.18),
            SKAction.sequence([
                SKAction.scale(to: 1.08, duration: 0.18),
                SKAction.scale(to: 1.00, duration: 0.08)
            ])
        ])
        appear.timingMode = .easeOut
        run(appear, withKey: "entrance")
    }

    /// Pops up and shrinks to nothing when collected into the tray.
    /// The completion fires once the tile has fully disappeared.
    func playCollectAnimation(completion: (() -> Void)? = nil) {
        // Brief float upward + scale punch, then shrink to zero
        let moveUp   = SKAction.moveBy(x: 0, y: 28, duration: 0.10)
        moveUp.timingMode = .easeOut
        let scaleUp  = SKAction.scale(to: 1.22, duration: 0.10)
        let punch    = SKAction.group([moveUp, scaleUp])
        let scaleOut = SKAction.scale(to: 0.0,  duration: 0.14)
        scaleOut.timingMode = .easeIn
        let fade     = SKAction.fadeOut(withDuration: 0.12)
        let dissolve = SKAction.group([scaleOut, fade])

        run(SKAction.sequence([punch, dissolve])) {
            completion?()
        }
    }

    /// Pops in from a small scale when re-dropped from the tray mid-screen.
    /// The tile should already be positioned; call after addChild.
    func playRespawnAnimation() {
        alpha = 0
        setScale(0.2)
        let appear = SKAction.group([
            SKAction.fadeIn(withDuration: 0.15),
            SKAction.sequence([
                SKAction.scale(to: 1.12, duration: 0.18),
                SKAction.scale(to: 1.00, duration: 0.08)
            ])
        ])
        appear.timingMode = .easeOut
        run(appear, withKey: "respawn")
    }

    /// A quick horizontal shake — intended for tray tiles on an invalid submission.
    func playShakeAnimation() {
        let dx: CGFloat = 7
        let shake = SKAction.sequence([
            SKAction.moveBy(x:  dx,      y: 0, duration: 0.04),
            SKAction.moveBy(x: -dx * 2,  y: 0, duration: 0.05),
            SKAction.moveBy(x:  dx * 2,  y: 0, duration: 0.05),
            SKAction.moveBy(x: -dx,      y: 0, duration: 0.04)
        ])
        run(shake, withKey: "shake")
    }

    /// Briefly dims the tile to give a visual press-state before collecting.
    func playPressHighlight() {
        tileBackground.run(
            SKAction.sequence([
                SKAction.fadeAlpha(to: 0.75, duration: 0.04),
                SKAction.fadeAlpha(to: 1.00, duration: 0.06)
            ]),
            withKey: "press"
        )
    }
}
