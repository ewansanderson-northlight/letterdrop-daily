//
//  GameState.swift
//  Letter Drop
//
//  Single source of truth shared between SwiftUI screens and SpriteKit scene.
//  Timer model: per-block countdown with time-banking on early submit.
//

import Foundation
import Combine

enum GamePhase: Equatable {
    case loading      // fetching daily puzzle at launch
    case menu
    case playing
    case results
    case fetchError   // network/validation failure — game cannot start
}

struct FoundWord {
    let word: String
    let score: Int
    let waveIndex: Int  // 0-5
}

final class GameState: ObservableObject {

    // MARK: - Phase
    @Published var phase: GamePhase = .menu

    // MARK: - Round state
    @Published var score: Int = 0
    @Published var foundWords: [FoundWord] = []

    /// Updated by GameScene as the player traces a path — drives the HUD preview.
    @Published var currentSelection: String = ""

    // MARK: - In-game UI helpers

    /// Short "WAVE N" banner shown when a new block starts. Cleared after ~1.2 s.
    @Published var waveBanner: String? = nil
    /// Y of the active block's top edge in UIKit coords (origin top-left).
    /// Set by GameScene; used to anchor the word-preview overlay.
    @Published var blockTopUIKitY: CGFloat = 0

    // MARK: - Per-block timer

    /// The phase currently draining: bank first, then block time, then none.
    enum TimerPhase: Equatable {
        case banked   // burning accumulated bank
        case block    // burning this block's allocation
        case none
    }
    @Published var timerPhase: TimerPhase = .none

    /// Remaining seconds on the current block's own allocation.
    @Published var currentBlockTimeRemaining: Double = 0

    /// Pooled bonus seconds earned by submitting words early.
    /// Drains first (in gold) before each block's own allocation starts.
    @Published var bankedTime: Double = 0

    /// True when the block clock should not tick (slow-mo is consuming its own budget).
    var isSlowMoActive: Bool = false {
        didSet { objectWillChange.send() }
    }

    /// True on the frame the block allocation hits zero (GameScene detects and acts on this).
    var isBlockTimedOut: Bool {
        timerPhase == .block && currentBlockTimeRemaining <= 0
    }

    // MARK: - Per-block timer API (called by GameScene)

    /// Call when a block enters play. Bank drains first if any remains.
    func startBlockTimer(blockIndex: Int) {
        let base = Constants.Game.blockTimeLimits[safe: blockIndex] ?? 0
        currentBlockTimeRemaining = base
        timerPhase = bankedTime > 0 ? .banked : .block
    }

    /// Tick the block clock by `dt` real seconds. Slow-mo pauses the clock entirely.
    func tickBlockTimer(dt: Double) {
        guard timerPhase != .none, !isSlowMoActive else { return }

        if timerPhase == .banked {
            bankedTime = max(0, bankedTime - dt)
            if bankedTime <= 0 { timerPhase = .block }
        } else {
            currentBlockTimeRemaining = max(0, currentBlockTimeRemaining - dt)
        }
    }

    /// Called on a successful early submit. Distributes remaining time equally
    /// across blocks that haven't been played yet.
    func bankRemainingTime(blockIndex: Int) {
        let remaining = currentBlockTimeRemaining
        let remainingBlocks = Constants.Game.wavesPerRound - blockIndex - 1
        if remainingBlocks > 0 && remaining > 0 {
            bankedTime += remaining / Double(remainingBlocks)
        }
        currentBlockTimeRemaining = 0
        timerPhase = .none
    }

    func stopBlockTimer() {
        timerPhase = .none
    }

    // MARK: - Daily challenge
    @Published var hasPlayedToday: Bool = false
    /// The validated puzzle loaded via URLSession — nil only while loading.
    private(set) var dailyChallenge: DailyChallenge?
    /// Human-readable reason shown on the fetch-error screen.
    @Published private(set) var fetchErrorMessage: String = ""

    // MARK: - Countdown (#1)
    /// 3 → 2 → 1 → 0 (GO) → nil.  nil means game is running.
    @Published var countdownValue: Int? = nil

    private var countdownGeneration = 0

    func startCountdown() {
        countdownGeneration += 1
        let gen = countdownGeneration
        countdownValue = 3
        scheduleCountdown(value: 3, generation: gen)
    }

    private func scheduleCountdown(value: Int, generation: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, self.countdownGeneration == generation else { return }
            let next = value - 1
            self.countdownValue = next
            if next > 0 {
                self.scheduleCountdown(value: next, generation: generation)
            } else {
                // Show GO (0) for 0.6 s then clear — GameScene starts block 0 timer
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    guard let self, self.countdownGeneration == generation else { return }
                    self.countdownValue = nil
                }
            }
        }
    }

    // MARK: - Best word flash (#3)
    struct BestWordFlash: Equatable {
        let word: String
        let score: Int
    }
    @Published var bestWordFlash: BestWordFlash? = nil

    // MARK: - Submitted word display (frozen tile preview after submit)
    struct SubmittedWordDisplay: Equatable {
        let word: String
        let score: Int
        let streakBonus: Int
    }
    @Published var submittedWordDisplay: SubmittedWordDisplay? = nil

    // MARK: - Miss feedback (#7)
    @Published var showMissFeedback = false

    // MARK: - Wave optimal words (#8, #9)
    struct WaveOptimal: Equatable {
        let word: String
        let score: Int
    }
    @Published var waveOptimalWords: [WaveOptimal?] = []
    @Published var theoreticalMaxScore: Int = 0

    private func computeWaveOptimal() {
        guard let waves = dailyChallenge?.waves else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var optima: [WaveOptimal?] = []
            for wave in waves {
                if let best = WaveGridSolver.bestWord(in: wave.flat) {
                    optima.append(WaveOptimal(word: best.word, score: best.score))
                } else {
                    optima.append(nil)
                }
            }
            // Theoretical max: best word per wave + streak bonus if perfect streak + +200 perfect bonus
            // Streak bonuses: wave 0→+0, 1→+25, 2→+50, 3→+75, 4→+100, 5→+150
            let streakBonuses = [0, 25, 50, 75, 100, 150]
            let waveTotal = optima.enumerated().reduce(0) { total, pair in
                guard let elem = pair.element else { return total }
                let bonus = pair.offset < streakBonuses.count ? streakBonuses[pair.offset] : 150
                return total + elem.score + bonus
            }
            let maxScore = waveTotal + 200
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.waveOptimalWords    = optima
                self.theoreticalMaxScore = maxScore
                AnalyticsManager.shared.track(.puzzleCompleted(
                    date:        self.todayString(),
                    score:       self.score,
                    maxScore:    maxScore,
                    wordsFound:  self.foundWords.count,
                    bestWord:    self.bestWord,
                    wavesScored: self.foundWords.count
                ))
            }
        }
    }

    // MARK: - Slow motion

    /// Remaining slow-motion budget in seconds (15 s per round).
    @Published var slowMoAllowance: Double = 15.0

    func activateSlowMo()             { isSlowMoActive = true }
    func deactivateSlowMo()           { isSlowMoActive = false }
    func depleteSlowMo(by dt: Double) { slowMoAllowance = max(0, slowMoAllowance - dt) }

    // MARK: - Streak bonus
    /// Number of consecutive waves solved without missing one.
    @Published var consecutiveSolves: Int = 0

    /// Index of the wave currently being played (0-5). Set by GameScene when each block enters play.
    @Published var currentWaveIndex: Int = 0

    /// Additive bonus for the next submission based on the current streak.
    /// Streak 0 → +0, 1 → +25, 2 → +50, 3 → +75, 4 → +100, 5+ → +150
    var currentStreakBonus: Int {
        switch consecutiveSolves {
        case 0:     return 0
        case 1:     return 25
        case 2:     return 50
        case 3:     return 75
        case 4:     return 100
        default:    return 150
        }
    }

    /// Shown on the results screen when all 6 waves are solved (+200 perfect round bonus).
    @Published var showPerfectRoundCelebration: Bool = false

    /// True when the score just set in endRound() beats the stored personal best.
    @Published var isNewBestScore: Bool = false

    // MARK: - Streak tracking (letterdrop_streak in UserDefaults as JSON)

    struct StreakData: Codable {
        var lastPlayedDate: String
        var currentStreak: Int
        var bestStreak: Int
    }

    @Published var currentStreak: Int = 0
    @Published var bestStreak: Int = 0

    private static let streakKey = "letterdrop_streak"

    private func loadStreak() {
        guard let data = UserDefaults.standard.data(forKey: Self.streakKey),
              let streak = try? JSONDecoder().decode(StreakData.self, from: data)
        else { return }
        currentStreak = streak.currentStreak
        bestStreak    = streak.bestStreak
    }

    private func updateStreak(todayStr: String) {
        guard let data = UserDefaults.standard.data(forKey: Self.streakKey),
              let existing = try? JSONDecoder().decode(StreakData.self, from: data)
        else {
            // First game ever — start streak at 1
            saveStreak(StreakData(lastPlayedDate: todayStr, currentStreak: 1, bestStreak: 1))
            return
        }
        // Already updated for today — no change
        if existing.lastPlayedDate == todayStr { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())
                            .flatMap { formatter.string(from: $0) }

        let newStreak = existing.lastPlayedDate == yesterday
            ? existing.currentStreak + 1
            : 1
        let newBest = max(existing.bestStreak, newStreak)
        saveStreak(StreakData(lastPlayedDate: todayStr, currentStreak: newStreak, bestStreak: newBest))
    }

    private func saveStreak(_ data: StreakData) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        UserDefaults.standard.set(encoded, forKey: Self.streakKey)
        let isNewBest = data.currentStreak > bestStreak  // compare before updating
        currentStreak = data.currentStreak
        bestStreak    = data.bestStreak
        AnalyticsManager.shared.track(.streakUpdated(
            currentStreak: data.currentStreak,
            isNewBest:     isNewBest
        ))
    }

    // MARK: - Persistent stats (UserDefaults-backed)
    @Published var bestScore: Int = UserDefaults.standard.integer(forKey: "bestScore") {
        didSet { UserDefaults.standard.set(bestScore, forKey: "bestScore") }
    }
    @Published var gamesPlayed: Int = UserDefaults.standard.integer(forKey: "gamesPlayed") {
        didSet { UserDefaults.standard.set(gamesPlayed, forKey: "gamesPlayed") }
    }
    @Published var totalScore: Int = UserDefaults.standard.integer(forKey: "totalScore") {
        didSet { UserDefaults.standard.set(totalScore, forKey: "totalScore") }
    }
    @Published var totalWordsCompleted: Int = UserDefaults.standard.integer(forKey: "totalWordsCompleted") {
        didSet { UserDefaults.standard.set(totalWordsCompleted, forKey: "totalWordsCompleted") }
    }
    @Published var perfectRounds: Int = UserDefaults.standard.integer(forKey: "perfectRounds") {
        didSet { UserDefaults.standard.set(perfectRounds, forKey: "perfectRounds") }
    }
    @Published var bestWordScore: Int = UserDefaults.standard.integer(forKey: "bestWordScore") {
        didSet { UserDefaults.standard.set(bestWordScore, forKey: "bestWordScore") }
    }
    @Published var bestWord: String = UserDefaults.standard.string(forKey: "bestWord") ?? "" {
        didSet { UserDefaults.standard.set(bestWord, forKey: "bestWord") }
    }

    // MARK: - Derived
    var averageScore: Int {
        guard gamesPlayed > 0 else { return 0 }
        return totalScore / gamesPlayed
    }

    var shortestFoundWord: String? {
        foundWords.min(by: { $0.word.count < $1.word.count })?.word
    }

    var longestFoundWord: String? {
        foundWords.max(by: { $0.word.count < $1.word.count })?.word
    }

    // MARK: - Private
    private static let lastPlayedKey = "lastPlayedDate"

    // MARK: - Init
    init() {
        checkPlayedToday()
        loadStreak()
        fetchDailyChallenge()
    }

    // MARK: - Puzzle fetch

    /// Called once at init and again when the user taps Retry on the error screen.
    func retryPuzzleFetch() {
        fetchDailyChallenge()
    }

    private func fetchDailyChallenge() {
        phase = .loading

        DailyChallengeManager.shared.load { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let challenge):
                self.dailyChallenge = challenge
                self.phase = .menu

            case .failure(let error):
                print("Failed to load challenge:", error)
                self.phase = .menu
            }
        }
    }

    // MARK: - Round actions

    func startRound() {
        score                       = 0
        foundWords                  = []
        currentSelection            = ""
        consecutiveSolves           = 0
        slowMoAllowance             = 15.0
        isSlowMoActive              = false
        waveOptimalWords            = []
        theoreticalMaxScore         = 0
        bestWordFlash               = nil
        showMissFeedback            = false
        showPerfectRoundCelebration = false
        isNewBestScore              = false
        // Per-block timer state
        currentBlockTimeRemaining = 0
        bankedTime                  = 0
        timerPhase                  = .none
        waveBanner                  = nil
        blockTopUIKitY              = 0
        currentWaveIndex            = 0
        phase = .playing
        markPlayedToday()
        AnalyticsManager.shared.track(.puzzleStarted(date: todayString()))
        startCountdown()    // GameScene starts block 0 timer after GO
    }

    func endRound() {
        stopBlockTimer()
        countdownGeneration += 1    // cancel any pending countdown
        countdownValue = nil
        submittedWordDisplay = nil
        bestWordFlash = nil
        // Perfect round bonus
        if foundWords.count == Constants.Game.wavesPerRound {
            perfectRounds += 1
            score += 200
            showPerfectRoundCelebration = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
                self?.showPerfectRoundCelebration = false
            }
        }
        isNewBestScore = score > bestScore
        if score > bestScore { bestScore = score }
        totalScore += score
        gamesPlayed += 1
        phase = .results
        computeWaveOptimal()        // async — populates results screen data
    }

    func returnToMenu() {
        stopBlockTimer()
        countdownGeneration += 1    // cancel any pending countdown
        countdownValue = nil
        currentSelection = ""
        submittedWordDisplay = nil
        bestWordFlash = nil
        showPerfectRoundCelebration = false
        phase = .menu
    }

    func submitWord(word: String, score wordScore: Int, waveIndex: Int) {
        foundWords.append(FoundWord(word: word.uppercased(), score: wordScore, waveIndex: waveIndex))
        // submittedWordDisplay is set by GameScene (which owns the streak bonus)
        score += wordScore
        totalWordsCompleted += 1
        consecutiveSolves += 1          // extend streak
        if wordScore > bestWordScore {
            bestWordScore = wordScore
            bestWord = word.uppercased()
        }
    }

    /// Called by GameScene when a block exits without being solved.
    func resetStreak() {
        consecutiveSolves = 0
    }

    func resetStats() {
        bestScore           = 0
        gamesPlayed         = 0
        totalScore          = 0
        totalWordsCompleted = 0
        perfectRounds       = 0
        bestWordScore       = 0
        bestWord            = ""
    }

    // MARK: - Daily play tracking

    func checkPlayedToday() {
        hasPlayedToday = UserDefaults.standard.string(forKey: Self.lastPlayedKey) == todayString()
    }

    private func markPlayedToday() {
        let today = todayString()
        UserDefaults.standard.set(today, forKey: Self.lastPlayedKey)
        hasPlayedToday = true
        updateStreak(todayStr: today)
    }

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

// MARK: - Safe subscript used by startBlockTimer

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
