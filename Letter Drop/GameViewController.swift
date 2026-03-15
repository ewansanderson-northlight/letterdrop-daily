//
//  GameViewController.swift
//  Letter Drop
//
//  Hosts the SpriteKit scene. Embedded in GameContainerView via
//  UIViewControllerRepresentable. Uses the DailyChallenge already
//  fetched and validated by GameState — no independent network calls.
//

import UIKit
import SpriteKit
import SwiftUI
import Combine

final class GameViewController: UIViewController {

    // MARK: - Dependencies

    var gameState: GameState?

    // MARK: - Private

    private var skView    : SKView!
    private var gameScene : GameScene?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Constants.Colors.background)
        setupSpriteKitView()
        setupHUDOverlay()
        observePhase()
    }

    // MARK: - SpriteKit setup

    private func setupSpriteKitView() {
        skView = SKView(frame: view.bounds)
        skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        skView.backgroundColor  = UIColor(Constants.Colors.background)
        skView.ignoresSiblingOrder = true
        skView.showsFPS       = false
        skView.showsNodeCount = false
        view.addSubview(skView)

        let scene = GameScene(size: view.bounds.size)
        scene.gameState = gameState
        skView.presentScene(scene)
        gameScene = scene
    }

    // MARK: - SwiftUI HUD overlay

    private func setupHUDOverlay() {
        guard let gameState else { return }

        let hudView = GameHUDView(gameState: gameState)
        let hostingVC = UIHostingController(rootView: hudView)
        hostingVC.view.backgroundColor = .clear
        hostingVC.view.isOpaque = false

        addChild(hostingVC)
        hostingVC.view.isUserInteractionEnabled = false   // pass touches through to SpriteKit
        view.addSubview(hostingVC.view)
        hostingVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingVC.view.leadingAnchor  .constraint(equalTo: view.leadingAnchor),
            hostingVC.view.trailingAnchor .constraint(equalTo: view.trailingAnchor),
            hostingVC.view.topAnchor      .constraint(equalTo: view.topAnchor),
            hostingVC.view.bottomAnchor   .constraint(equalTo: view.bottomAnchor)
        ])
        hostingVC.didMove(toParent: self)
    }

    // MARK: - Phase observation

    private func observePhase() {
        gameState?.$phase
            .receive(on: DispatchQueue.main)
            .sink { [weak self] phase in
                switch phase {
                case .playing:
                    self?.beginGameplay()
                case .results, .menu, .loading, .fetchError:
                    self?.gameScene?.stopGame()
                }
            }
            .store(in: &cancellables)
    }

    private func beginGameplay() {
        // Use the puzzle that GameState already fetched and validated — no fallback.
        guard let challenge = gameState?.dailyChallenge else { return }
        let waveLetters = challenge.waves.map { $0.flat }
        gameScene?.startGame(with: waveLetters)
    }

    // MARK: - Orientation

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override var prefersStatusBarHidden: Bool { true }
}
