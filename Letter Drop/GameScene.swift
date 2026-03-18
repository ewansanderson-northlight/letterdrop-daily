//
//  GameScene.swift
//  Letter Drop
//
//  Six 5×5 letter-grid blocks arrive sequentially. Each has its own countdown.
//  Submitting early banks leftover time equally across remaining blocks.
//  Blocks fly in from the top, rest at centre while the player interacts,
//  then rush off downward on submit or timeout.
//

import SpriteKit
import SwiftUI

// MARK: - Safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - TileCoord

private struct TileCoord: Hashable {
    let waveIndex: Int
    let row: Int    // 0 = top row of wave
    let col: Int    // 0 = left column
}

// MARK: - Block phase state machine

private enum BlockPhase {
    case idle
    case waitingForCountdown    // frozen during 3-2-1-GO
    case flyingIn(Int)          // block index, animating to play position
    case playing(Int)           // block index, timer running, player can interact
    case flyingOut(Int)         // block index, animating off screen
    case bestWordPause          // brief pause before next block
}

// MARK: - GameScene

final class GameScene: SKScene {

    // MARK: - Dependencies
    weak var gameState: GameState?

    // MARK: - Block phase
    private var blockPhase: BlockPhase = .idle

    // MARK: - Wave management
    private var challengeWaveLetters: [[String]] = []
    private var activeWaveNodes: [Int: WaveNode] = [:]

    // MARK: - Selection state
    private var selectionPath = [TileCoord]()
    private var trailNode     : SKShapeNode!
    private var flashOverlay  : SKSpriteNode!

    // MARK: - Geometry (set in startGame)
    private var tileSize  : CGFloat = 0
    private var waveWidth : CGFloat = 0
    private var waveHeight: CGFloat = 0
    private var waveLeft  : CGFloat = 0

    /// Y position of the block's bottom edge while in the play zone (centred in playable area).
    private var playY: CGFloat {
        let headerClearance: CGFloat = 130
        return max(20, (size.height - headerClearance - waveHeight) / 2)
    }

    // MARK: - Slow motion
    private var slowMoTouch         : UITouch?     = nil
    private var slowMoTouchStartTime: TimeInterval = -1
    private var wasSlowMoActive     : Bool         = false
    private static let slowMoThreshold: TimeInterval = 0.3

    // MARK: - Timing
    private var lastUpdateTime: TimeInterval = 0

    // MARK: - Convenience

    private var isPlaying: Bool {
        if case .playing = blockPhase { return true }
        return false
    }

    // MARK: - Scene lifecycle

    override func didMove(to view: SKView) {
        backgroundColor      = UIColor(Constants.Colors.background)
        scaleMode            = .resizeFill
        physicsWorld.gravity = .zero
        setupTrail()
        setupFlashOverlay()
    }

    override func willMove(from view: SKView) {
        blockPhase = .idle
    }

    // MARK: - Public API

    func startGame(with waveLetters: [[String]]) {
        // Clean slate
        for (_, node) in activeWaveNodes { node.removeFromParent() }
        activeWaveNodes.removeAll()
        selectionPath.removeAll()
        trailNode.path       = nil
        lastUpdateTime       = 0
        slowMoTouch          = nil
        slowMoTouchStartTime = -1
        challengeWaveLetters = waveLetters

        let gap    = Constants.Game.tileGap
        let margin = Constants.Game.tileMargin
        tileSize   = (size.width - 2 * margin - 4 * gap) / 5
        waveWidth  = 5 * tileSize + 4 * gap
        waveHeight = 5 * tileSize + 4 * gap
        waveLeft   = (size.width - waveWidth) / 2

        blockPhase = .waitingForCountdown

        // Publish block-top UIKit Y so SwiftUI overlays can anchor to it
        DispatchQueue.main.async {
            self.gameState?.blockTopUIKitY = self.size.height - (self.playY + self.waveHeight)
        }

        // Pre-position block 0 at play zone so the player sees it during 3-2-1-GO
        spawnBlock(0, at: CGPoint(x: waveLeft, y: playY))
    }

    func stopGame() {
        blockPhase = .idle
        for (_, node) in activeWaveNodes { node.removeFromParent() }
        activeWaveNodes.removeAll()
        selectionPath.removeAll()
        trailNode.path = nil
        gameState?.currentSelection = ""
    }

    // MARK: - Block state machine

    /// Spawn the next block flying in from off-screen top.
    private func startBlock(_ index: Int) {
        guard index < challengeWaveLetters.count else {
            gameState?.endRound()
            blockPhase = .idle
            return
        }
        // Clear previous wave's frozen tile preview and best word badge as new wave arrives
        gameState?.submittedWordDisplay = nil
        gameState?.bestWordFlash = nil
        spawnBlock(index, at: CGPoint(x: waveLeft, y: size.height))
        blockPhase = .flyingIn(index)
        showWaveBanner(index: index)

        guard let node = activeWaveNodes[index] else { return }
        let dest   = CGPoint(x: waveLeft, y: playY)
        let flyIn  = SKAction.move(to: dest, duration: 0.55)
        flyIn.timingMode = .easeOut
        node.run(flyIn) { [weak self] in
            guard let self else { return }
            node.animateIn()
            self.blockPhase = .playing(index)
            self.gameState?.currentWaveIndex = index
            self.gameState?.startBlockTimer(blockIndex: index)
            if index == 2 || index == 4 { HapticManager.waveSpeedUp() }
        }
    }

    /// Rush the current block off screen, then pause before the next one.
    private func exitBlock(_ index: Int, solved: Bool) {
        clearSelectionVisuals()
        selectionPath.removeAll()
        trailNode.path = nil
        gameState?.currentSelection = ""
        blockPhase = .flyingOut(index)

        guard let node = activeWaveNodes[index] else {
            proceedAfterBlock(index, solved: solved)
            return
        }
        let exitPos  = CGPoint(x: waveLeft, y: -waveHeight - 20)
        let flyOut   = SKAction.move(to: exitPos, duration: solved ? 0.35 : 0.50)
        flyOut.timingMode = .easeIn
        node.run(flyOut) { [weak self] in
            guard let self else { return }
            node.removeFromParent()
            self.activeWaveNodes.removeValue(forKey: index)
            self.proceedAfterBlock(index, solved: solved)
        }
    }

    private func proceedAfterBlock(_ index: Int, solved: Bool) {
        blockPhase = .bestWordPause
        // Best word flash shows for 1.5 s (triggered in trySubmit); timed-out blocks
        // get a shorter pause so the game keeps flowing.
        let pause: TimeInterval = solved ? 1.5 : 0.45
        DispatchQueue.main.asyncAfter(deadline: .now() + pause) { [weak self] in
            guard let self else { return }
            let next = index + 1
            if next < Constants.Game.wavesPerRound {
                self.startBlock(next)
            } else {
                self.gameState?.endRound()
                self.blockPhase = .idle
            }
        }
    }

    /// Create and add a WaveNode at the given scene position.
    private func spawnBlock(_ index: Int, at position: CGPoint) {
        guard index < challengeWaveLetters.count else { return }
        let node = WaveNode(
            waveIndex:      index,
            letters:        challengeWaveLetters[index],
            tileSize:       tileSize,
            gap:            Constants.Game.tileGap,
            difficultyTint: difficultyTint(for: index)
        )
        node.zPosition = 10
        node.position  = position
        addChild(node)
        activeWaveNodes[index] = node
    }

    private func difficultyTint(for index: Int) -> UIColor? {
        guard let flat = gameState?.dailyChallenge?.waves[safe: index]?.flat else { return nil }
        let avg = Double(flat.map { LetterValues.value(for: $0) }.reduce(0, +)) / 25.0
        if avg < 1.8 { return UIColor(Constants.Colors.success).withAlphaComponent(0.09) }
        if avg < 2.5 { return UIColor(Constants.Colors.gold).withAlphaComponent(0.09) }
        return UIColor(Constants.Colors.failure).withAlphaComponent(0.09)
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        let dt: CGFloat = lastUpdateTime == 0 ? 0
                        : CGFloat(min(currentTime - lastUpdateTime, 0.05))
        lastUpdateTime = currentTime

        handleSlowMo(currentTime: currentTime, dt: dt)

        switch blockPhase {
        case .waitingForCountdown:
            // Countdown finished → start block 0 timer and animate tiles in
            if gameState?.countdownValue == nil {
                activeWaveNodes[0]?.animateIn()
                showWaveBanner(index: 0)
                blockPhase = .playing(0)
                gameState?.startBlockTimer(blockIndex: 0)
            }

        case .playing(let i):
            gameState?.tickBlockTimer(dt: Double(dt))
            if gameState?.isBlockTimedOut == true {
                gameState?.stopBlockTimer()
                gameState?.resetStreak()
                exitBlock(i, solved: false)
            }

        default:
            break
        }

        updateTrail()
    }

    // MARK: - Slow motion

    private func handleSlowMo(currentTime: TimeInterval, dt: CGFloat) {
        if slowMoTouch != nil {
            if slowMoTouchStartTime < 0 { slowMoTouchStartTime = currentTime }
            let held = currentTime - slowMoTouchStartTime
            if held >= Self.slowMoThreshold {
                if let gs = gameState, gs.slowMoAllowance > 0 {
                    gs.activateSlowMo()
                    gs.depleteSlowMo(by: Double(dt))
                } else {
                    gameState?.deactivateSlowMo()
                }
            }
        } else {
            gameState?.deactivateSlowMo()
        }

        // Detect transitions for block animation feedback
        let nowActive = gameState?.isSlowMoActive == true
        if nowActive && !wasSlowMoActive       { onSlowMoActivated() }
        else if !nowActive && wasSlowMoActive  { onSlowMoReleased()  }
        wasSlowMoActive = nowActive
    }

    private func onSlowMoActivated() {
        guard case .playing(let i) = blockPhase, let node = activeWaveNodes[i] else { return }
        HapticManager.slowMoActivate()
        node.removeAction(forKey: "breathe")
        node.run(SKAction.sequence([
            SKAction.scale(to: 1.03, duration: 0.10),
            SKAction.scale(to: 1.0,  duration: 0.08),
            SKAction.run { [weak self, weak node] in
                guard let self, let node else { return }
                if self.gameState?.isSlowMoActive == true { self.startBlockBreathe(node) }
            }
        ]), withKey: "pulse")
    }

    private func startBlockBreathe(_ node: WaveNode) {
        let breathe = SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.015, duration: 0.9),
            SKAction.scale(to: 1.0,   duration: 0.9)
        ]))
        node.run(breathe, withKey: "breathe")
    }

    private func onSlowMoReleased() {
        guard case .playing(let i) = blockPhase, let node = activeWaveNodes[i] else { return }
        node.removeAction(forKey: "breathe")
        node.removeAction(forKey: "pulse")
        node.run(SKAction.sequence([
            SKAction.scale(to: 0.97, duration: 0.06),
            SKAction.scale(to: 1.0,  duration: 0.14)
        ]))
    }

    // MARK: - Wave banner

    private func showWaveBanner(index: Int) {
        gameState?.waveBanner = "WAVE \(index + 1)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.gameState?.waveBanner = nil
        }
    }

    // MARK: - Trail

    private func setupTrail() {
        trailNode             = SKShapeNode()
        trailNode.strokeColor = UIColor(Constants.Colors.gold)
        trailNode.lineWidth   = 4.5
        trailNode.lineCap     = .round
        trailNode.lineJoin    = .round
        trailNode.zPosition   = 30
        addChild(trailNode)
    }

    private func updateTrail() {
        guard !selectionPath.isEmpty else { trailNode.path = nil; return }
        let path = CGMutablePath()
        var moved = false
        for coord in selectionPath {
            guard let wn   = activeWaveNodes[coord.waveIndex],
                  let tile = wn.tile(at: coord.row, col: coord.col)
            else { continue }
            let pos = convert(tile.position, from: wn)
            if !moved { path.move(to: pos); moved = true }
            else      { path.addLine(to: pos) }
        }
        trailNode.path = moved ? path : nil
    }

    // MARK: - Flash overlay

    private func setupFlashOverlay() {
        flashOverlay             = SKSpriteNode(color: .clear, size: CGSize(width: 1, height: 1))
        flashOverlay.anchorPoint = .zero
        flashOverlay.zPosition   = 100
        flashOverlay.alpha       = 0
        addChild(flashOverlay)
    }

    private func flashScreen(color: UIColor) {
        flashOverlay.size  = size
        flashOverlay.color = color.withAlphaComponent(0.20)
        flashOverlay.removeAllActions()
        flashOverlay.alpha = 1
        flashOverlay.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.07),
            SKAction.fadeOut(withDuration: 0.28)
        ]))
    }

    // MARK: - Score pop

    private func spawnScorePop(score: Int, multiplier: Int, near coords: [TileCoord]) {
        guard score > 0, !coords.isEmpty else { return }

        let positions: [CGPoint] = coords.compactMap { c in
            guard let wn = activeWaveNodes[c.waveIndex],
                  let t  = wn.tile(at: c.row, col: c.col)
            else { return nil }
            return convert(t.position, from: wn)
        }
        guard !positions.isEmpty else { return }

        let cx = positions.map(\.x).reduce(0, +) / CGFloat(positions.count)
        let cy = positions.map(\.y).reduce(0, +) / CGFloat(positions.count)

        let text  = multiplier > 1 ? "+\(score)  ×\(multiplier)" : "+\(score)"
        let label                     = SKLabelNode(text: text)
        label.fontName                = "SFRounded-Semibold"
        label.fontSize                = multiplier > 1 ? 22 : 20
        label.fontColor               = multiplier > 1
                                        ? UIColor(Constants.Colors.gold)
                                        : UIColor(Constants.Colors.success)
        label.verticalAlignmentMode   = .center
        label.horizontalAlignmentMode = .center
        label.position                = CGPoint(x: cx, y: cy)
        label.zPosition               = 50
        label.alpha                   = 0
        label.setScale(0.6)
        addChild(label)

        label.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeIn(withDuration: 0.08),
                SKAction.scale(to: 1.0, duration: 0.10)
            ]),
            SKAction.group([
                SKAction.moveBy(x: 0, y: 46, duration: 0.60),
                SKAction.sequence([
                    SKAction.wait(forDuration: 0.22),
                    SKAction.fadeOut(withDuration: 0.38)
                ])
            ]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if isPlaying, let coord = findTile(at: touch.location(in: self)) {
            guard !isWaveAlreadySolved(coord.waveIndex) else { return }
            clearSelectionVisuals()
            selectionPath = [coord]
            activeWaveNodes[coord.waveIndex]?.setSelected(true, at: coord.row, col: coord.col)
            activeWaveNodes[coord.waveIndex]?.tile(at: coord.row, col: coord.col)?.playTouchDown()
            gameState?.currentSelection = currentWord()
            HapticManager.selectTile()
        } else {
            // Non-tile touch — track for slow-motion long press
            if slowMoTouch == nil {
                slowMoTouch          = touch
                slowMoTouchStartTime = -1
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isPlaying, let touch = touches.first else { return }
        let loc = touch.location(in: self)
        let prev = touch.previousLocation(in: self)
        let dx = loc.x - prev.x
        let dy = loc.y - prev.y
        let moveDist = hypot(dx, dy)
        // Detect diagonal intent: angle 25–65° from horizontal in any quadrant
        let isDiagonal: Bool
        if moveDist > 2 {
            let angleDeg = Double(atan2(abs(dy), abs(dx))) * 180 / .pi
            isDiagonal = angleDeg >= 25 && angleDeg <= 65
        } else {
            isDiagonal = false
        }
        guard let coord = findTile(at: loc, isDiagonal: isDiagonal) else { return }
        guard !selectionPath.isEmpty else { return }
        guard let firstWave = selectionPath.first?.waveIndex,
              coord.waveIndex == firstWave
        else { return }

        // Backtrack: finger re-entered the second-to-last tile — peel the last tile off.
        if selectionPath.count >= 2 && coord == selectionPath[selectionPath.count - 2] {
            let removed = selectionPath.removeLast()
            activeWaveNodes[removed.waveIndex]?.tile(at: removed.row, col: removed.col)?.cancelGhostTrail()
            activeWaveNodes[removed.waveIndex]?.setSelected(false, at: removed.row, col: removed.col)
            gameState?.currentSelection = currentWord()
            HapticManager.selectTile()
            updateTrail()
            return
        }

        // Forward selection: must be an unvisited adjacent tile.
        guard !selectionPath.contains(coord),
              let last = selectionPath.last,
              areAdjacent(last, coord)
        else { return }

        // Ghost trail: gold glow on the tile being left behind
        if let prev = selectionPath.last {
            activeWaveNodes[prev.waveIndex]?.tile(at: prev.row, col: prev.col)?.playGhostTrail()
        }
        selectionPath.append(coord)
        activeWaveNodes[coord.waveIndex]?.setSelected(true, at: coord.row, col: coord.col)
        gameState?.currentSelection = currentWord()
        HapticManager.selectTile()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touches.contains(where: { $0 === slowMoTouch }) {
            slowMoTouch          = nil
            slowMoTouchStartTime = -1
            gameState?.deactivateSlowMo()
        }

        guard isPlaying, let touch = touches.first else { cancelSelection(); return }
        let loc = touch.location(in: self)
        if let waveIndex = selectionPath.first?.waveIndex,
           isPointOverWave(loc, waveIndex: waveIndex) {
            trySubmit()
        } else {
            cancelSelection()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touches.contains(where: { $0 === slowMoTouch }) {
            slowMoTouch          = nil
            slowMoTouchStartTime = -1
            gameState?.deactivateSlowMo()
        }
        cancelSelection()
    }

    // MARK: - Selection helpers

    private func isWaveAlreadySolved(_ waveIndex: Int) -> Bool {
        gameState?.foundWords.contains(where: { $0.waveIndex == waveIndex }) ?? false
    }

    private func currentWord() -> String {
        selectionPath.compactMap {
            activeWaveNodes[$0.waveIndex]?.tile(at: $0.row, col: $0.col)?.letter
        }.joined()
    }

    private func trySubmit() {
        let word = currentWord()
        guard word.count >= 3 else { cancelSelection(); return }

        if WordValidator.shared.isValid(word) {
            let baseScore  = ScoreCalculator.score(for: word)
            let multiplier = gameState?.currentMultiplier ?? 1
            let pts        = baseScore * multiplier
            let waveIdx    = selectionPath.first!.waveIndex
            let captured   = selectionPath

            for (i, coord) in captured.enumerated() {
                activeWaveNodes[coord.waveIndex]?
                    .removeTileAnimated(at: coord.row, col: coord.col, delay: Double(i) * 0.05)
            }
            spawnScorePop(score: pts, multiplier: multiplier, near: captured)
            flashScreen(color: UIColor(Constants.Colors.success))
            HapticManager.validWord()
            gameState?.submitWord(word: word, score: pts, waveIndex: waveIdx)
            // Freeze the tile preview in place — GameScene owns multiplier so we set it here
            gameState?.submittedWordDisplay = GameState.SubmittedWordDisplay(
                word: word.uppercased(), score: pts, multiplier: multiplier
            )
            // Bank remaining block time across future blocks
            gameState?.bankRemainingTime(blockIndex: waveIdx)
            gameState?.currentSelection = ""
            trailNode.path = nil
            selectionPath.removeAll()

            // Best word — solve on background thread; cleared when next wave starts or round ends
            let flatGrid = challengeWaveLetters[waveIdx]
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let best = WaveGridSolver.bestWord(in: flatGrid) else { return }
                DispatchQueue.main.async { [weak self] in
                    self?.gameState?.bestWordFlash =
                        GameState.BestWordFlash(word: best.word, score: best.score)
                }
            }

            // Rush the block off screen; proceedAfterBlock will wait 1.5 s for the flash
            exitBlock(waveIdx, solved: true)

        } else {
            // Invalid submission — shake tiles + MISS overlay
            for coord in selectionPath {
                let t = activeWaveNodes[coord.waveIndex]?.tile(at: coord.row, col: coord.col)
                t?.playInvalidFlash()
                t?.playShake()
            }
            flashScreen(color: UIColor(Constants.Colors.failure))
            HapticManager.invalidWord()
            gameState?.showMissFeedback = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
                self?.gameState?.showMissFeedback = false
            }
            cancelSelection()
        }
    }

    private func cancelSelection() {
        clearSelectionVisuals()
        selectionPath.removeAll()
        trailNode.path = nil
        gameState?.currentSelection = ""
    }

    private func clearSelectionVisuals() {
        for coord in selectionPath {
            let tile = activeWaveNodes[coord.waveIndex]?.tile(at: coord.row, col: coord.col)
            tile?.cancelGhostTrail()
            tile?.playTouchUp()
            activeWaveNodes[coord.waveIndex]?.setSelected(false, at: coord.row, col: coord.col)
        }
    }

    private func areAdjacent(_ a: TileCoord, _ b: TileCoord) -> Bool {
        a.waveIndex == b.waveIndex &&
        abs(a.row - b.row) <= 1 &&
        abs(a.col - b.col) <= 1 &&
        !(a.row == b.row && a.col == b.col)
    }

    /// `isDiagonal` widens the hit zone by ~25% when gesture angle is 25–65° from horizontal.
    private func findTile(at scenePoint: CGPoint, isDiagonal: Bool = false) -> TileCoord? {
        var best: (coord: TileCoord, dist: CGFloat)? = nil
        let hitRadius = tileSize * (isDiagonal ? 0.85 : 0.68)

        for (_, waveNode) in activeWaveNodes {
            let local = convert(scenePoint, to: waveNode)
            let step  = waveNode.tileStep
            let ts    = waveNode.tileSize

            let approxCol = Int((local.x / step).rounded())
            let approxRFB = Int((local.y / step).rounded())

            for dc in -1...1 {
                for dr in -1...1 {
                    let col = approxCol + dc
                    let rfb = approxRFB + dr
                    let row = (Constants.Game.gridSize - 1) - rfb

                    guard (0..<Constants.Game.gridSize).contains(col),
                          (0..<Constants.Game.gridSize).contains(row),
                          waveNode.tile(at: row, col: col) != nil
                    else { continue }

                    let cx   = CGFloat(col) * step + ts / 2
                    let cy   = CGFloat(rfb) * step + ts / 2
                    let dist = hypot(local.x - cx, local.y - cy)

                    if dist <= hitRadius, best == nil || dist < best!.dist {
                        best = (TileCoord(waveIndex: waveNode.waveIndex, row: row, col: col), dist)
                    }
                }
            }
        }
        return best?.coord
    }

    private func isPointOverWave(_ scenePoint: CGPoint, waveIndex: Int) -> Bool {
        guard let waveNode = activeWaveNodes[waveIndex] else { return false }
        let local = convert(scenePoint, to: waveNode)
        let pad: CGFloat = 28
        return local.x >= -pad && local.x <= waveNode.waveWidth  + pad &&
               local.y >= -pad && local.y <= waveNode.waveHeight + pad
    }
}

// MARK: - WaveNode

/// SKNode containing a 5×5 grid of GridTile children.
private final class WaveNode: SKNode {

    let waveIndex : Int
    let tileSize  : CGFloat
    let gap       : CGFloat

    var tileStep  : CGFloat { tileSize + gap }
    var waveHeight: CGFloat { 5 * tileSize + 4 * gap }
    var waveWidth : CGFloat { 5 * tileSize + 4 * gap }

    private var tileGrid: [[GridTile?]]

    init(waveIndex: Int, letters: [String], tileSize: CGFloat, gap: CGFloat,
         difficultyTint: UIColor? = nil) {
        self.waveIndex = waveIndex
        self.tileSize  = tileSize
        self.gap       = gap
        tileGrid       = Array(repeating: Array(repeating: nil, count: 5), count: 5)
        super.init()

        for row in 0..<5 {
            for col in 0..<5 {
                let idx    = row * 5 + col
                let letter = idx < letters.count ? letters[idx] : "A"
                let tile   = GridTile(letter: letter, tileSize: tileSize)

                if let tint = difficultyTint { tile.applyDifficultyTint(tint) }

                let rowFromBottom = 4 - row
                tile.position = CGPoint(
                    x: CGFloat(col)          * tileStep + tileSize / 2,
                    y: CGFloat(rowFromBottom) * tileStep + tileSize / 2
                )
                tile.alpha = 0   // hidden until animateIn() is called after flyIn completes
                addChild(tile)
                tileGrid[row][col] = tile
            }
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Staggered drop-in animation — call once the node has reached its play position.
    func animateIn() {
        for row in 0..<5 {
            for col in 0..<5 {
                guard let tile = tileGrid[row][col] else { continue }
                tile.alpha = 0
                let delay = Double(row) * 0.030 + Double(col) * 0.008
                tile.run(SKAction.sequence([
                    SKAction.wait(forDuration: delay),
                    SKAction.group([
                        SKAction.fadeIn(withDuration: 0.14),
                        SKAction.sequence([
                            SKAction.moveBy(x: 0, y: 9, duration: 0),
                            SKAction.moveBy(x: 0, y: -9, duration: 0.18)
                        ])
                    ])
                ]))
            }
        }
    }

    func tile(at row: Int, col: Int) -> GridTile? {
        guard (0..<5).contains(row), (0..<5).contains(col) else { return nil }
        return tileGrid[row][col]
    }

    func setSelected(_ selected: Bool, at row: Int, col: Int) {
        tileGrid[row][col]?.isSelected = selected
    }

    func removeTileAnimated(at row: Int, col: Int, delay: TimeInterval = 0) {
        tileGrid[row][col]?.playRemoveAnimation(delay: delay)
        tileGrid[row][col] = nil
    }
}
