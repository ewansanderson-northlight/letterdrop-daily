//
//  GridTile.swift
//  Letter Drop
//
//  A single cell in a falling 5×5 wave grid.
//  Visual states: normal → selected (gold border) → removed (pop-out animation).
//  Touch handling is done by GameScene via coordinate math; this node is visual only.
//

import SpriteKit
import SwiftUI

final class GridTile: SKNode {

    // MARK: - Properties

    let letter: String
    let tileSize: CGFloat

    var isSelected: Bool = false { didSet { updateVisual() } }

    // MARK: - Child nodes

    private let background: SKShapeNode
    private let borderRing: SKShapeNode
    private let letterLabel: SKLabelNode

    // MARK: - Init

    init(letter: String, tileSize: CGFloat) {
        self.letter   = letter.uppercased()
        self.tileSize = tileSize

        let rect   = CGSize(width: tileSize, height: tileSize)
        let radius = Constants.Game.tileCorner

        // Cream tile face
        background = SKShapeNode(rectOf: rect, cornerRadius: radius)
        background.fillColor   = UIColor(Constants.Colors.tile)
        background.strokeColor = UIColor(Constants.Colors.tileShadow).withAlphaComponent(0.20)
        background.lineWidth   = 0.5

        // Gold border shown when selected — inset slightly so it doesn't clip
        let ringRect = CGSize(width: tileSize - 5, height: tileSize - 5)
        borderRing = SKShapeNode(rectOf: ringRect, cornerRadius: radius - 2)
        borderRing.fillColor   = .clear
        borderRing.strokeColor = UIColor(Constants.Colors.gold)
        borderRing.lineWidth   = 2.5
        borderRing.isHidden    = true
        borderRing.zPosition   = 1

        // Letter label
        letterLabel = SKLabelNode(text: letter.uppercased())
        letterLabel.fontName                = "SFRounded-Semibold"
        letterLabel.fontSize                = tileSize * 0.42
        letterLabel.fontColor               = UIColor(Constants.Colors.tileText)
        letterLabel.verticalAlignmentMode   = .center
        letterLabel.horizontalAlignmentMode = .center
        letterLabel.zPosition               = 2

        super.init()
        addChild(background)
        addChild(borderRing)
        addChild(letterLabel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    // MARK: - Visual state

    private func updateVisual() {
        if isSelected {
            background.fillColor = UIColor(Constants.Colors.tile).withAlphaComponent(0.65)
            borderRing.isHidden  = false
        } else {
            background.fillColor = UIColor(Constants.Colors.tile)
            borderRing.isHidden  = true
        }
    }

    // MARK: - Difficulty tint

    /// Overlays a very subtle colour wash (green/amber/red) indicating block difficulty.
    func applyDifficultyTint(_ color: UIColor) {
        let overlay = SKShapeNode(rectOf: CGSize(width: tileSize, height: tileSize),
                                  cornerRadius: Constants.Game.tileCorner)
        overlay.fillColor   = color
        overlay.strokeColor = .clear
        overlay.zPosition   = 0.5   // above background (0), below border ring (1)
        addChild(overlay)
    }

    // MARK: - Animations

    /// Gold flash + scale pop + dissolve when a valid word removes this tile.
    func playRemoveAnimation(delay: TimeInterval = 0) {
        let wait = SKAction.wait(forDuration: delay)
        let goldFill = SKAction.run { [weak self] in
            self?.background.fillColor = UIColor(Constants.Colors.gold).withAlphaComponent(0.80)
            self?.borderRing.isHidden = true
        }
        let pop  = SKAction.scale(to: 1.18, duration: 0.08)
        let shrink = SKAction.group([
            SKAction.scale(to: 0.0, duration: 0.15),
            SKAction.fadeOut(withDuration: 0.15)
        ])
        shrink.timingMode = .easeIn

        run(SKAction.sequence([wait, goldFill, pop, shrink, .removeFromParent()]))
    }

    /// Subtle scale-up on finger contact.
    func playTouchDown() {
        removeAction(forKey: "touchScale")
        run(SKAction.scale(to: 1.05, duration: 0.08), withKey: "touchScale")
    }

    /// Reset scale on finger lift or deselect.
    func playTouchUp() {
        removeAction(forKey: "touchScale")
        run(SKAction.scale(to: 1.0, duration: 0.10), withKey: "touchScale")
    }

    /// Left-right shake used on invalid word submission.
    func playShake() {
        let d: CGFloat = 5
        run(SKAction.sequence([
            SKAction.moveBy(x: -d, y: 0, duration: 0.05),
            SKAction.moveBy(x:  d, y: 0, duration: 0.05),
            SKAction.moveBy(x: -d, y: 0, duration: 0.05),
            SKAction.moveBy(x:  d, y: 0, duration: 0.05),
            SKAction.moveBy(x:  0, y: 0, duration: 0)
        ]))
    }

    /// Gold glow on a tile the finger has already passed through during a swipe.
    func playGhostTrail() {
        background.removeAllActions()
        background.fillColor   = UIColor(Constants.Colors.gold).withAlphaComponent(0.58)
        background.strokeColor = UIColor(Constants.Colors.gold).withAlphaComponent(0.85)
        background.glowWidth   = 8.0
        background.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.55),
            SKAction.run { [weak self] in
                self?.background.fillColor   = UIColor(Constants.Colors.tile).withAlphaComponent(0.65)
                self?.background.strokeColor = UIColor(Constants.Colors.tileShadow).withAlphaComponent(0.20)
                self?.background.glowWidth   = 0
            }
        ]))
    }

    /// Cancels any running ghost-trail animation and lets updateVisual() reset colour.
    func cancelGhostTrail() {
        background.removeAllActions()
        background.strokeColor = UIColor(Constants.Colors.tileShadow).withAlphaComponent(0.20)
        background.glowWidth   = 0
    }

    /// Brief red-tinted deselect when an invalid word is rejected.
    func playInvalidFlash() {
        isSelected = false
        let original = UIColor(Constants.Colors.tile)
        background.fillColor = UIColor(Constants.Colors.failure).withAlphaComponent(0.40)
        background.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.14),
            SKAction.run { [weak self] in self?.background.fillColor = original }
        ]))
    }
}
