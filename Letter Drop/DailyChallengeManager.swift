//
//  DailyChallengeManager.swift
//  Letter Drop
//
//  Fetches today's 5×5 letter grids from GitHub via URLSession.
//  There is NO random fallback generator. If the fetch fails for any reason
//  the caller receives a .failure result and the game must not start.
//
//  JSON schema expected at the GitHub raw URL:
//  {
//    "date": "2025-03-13",
//    "waves": [
//      { "grid": [["A","B","C","D","E"],
//                 ["F","G","H","I","J"],
//                 ["K","L","M","N","O"],
//                 ["P","Q","R","S","T"],
//                 ["U","V","W","X","Y"]] },
//      ... (6 waves total)
//    ]
//  }
//

import Foundation

// MARK: - Codable models

nonisolated struct DailyChallenge: Codable {
    let date: String
    let waves: [WaveLetters]
}

nonisolated struct WaveLetters: Codable {
    /// Row-major 5×5 grid of single uppercase letters.
    let grid: [[String]]

    /// Flattened 25-element array in reading order (row 0 col 0 … row 4 col 4).
    var flat: [String] { grid.flatMap { $0 } }
}

// MARK: - Load errors

enum PuzzleLoadError: LocalizedError {
    case networkError(Error)
    case httpError(Int)
    case decodingError
    case invalidPuzzle(String)

    var errorDescription: String? {
        switch self {
        case .networkError:            return "Network connection failed. Please check your connection and try again."
        case .httpError(let code):     return "Server returned an error (HTTP \(code)). Please try again."
        case .decodingError:           return "Today's puzzle data is malformed. Please try again."
        case .invalidPuzzle(let msg):  return "Invalid puzzle data: \(msg)"
        }
    }
}

// MARK: - Manager

final class DailyChallengeManager {

    static let shared = DailyChallengeManager()

    private var remoteURL: URL {
        let dateString = todayString()
        return URL(string: "https://raw.githubusercontent.com/ewansanderson-northlight/letterdrop-daily/main/puzzles/puzzle-\(dateString).json")!
    }

    private let cacheKey  = "dailyChallengeCache"
    private let cacheDate = "dailyChallengeCacheDate"

    private(set) var currentChallenge: DailyChallenge?

    // MARK: - Load

    /// Fetches today's puzzle using URLSession.
    /// Returns .success on the main queue, or .failure if anything goes wrong.
    /// There is NO random fallback — a failure must be surfaced to the user.
    func load(completion: @escaping (Result<DailyChallenge, Error>) -> Void) {
        let today = todayString()

        // Serve today's already-validated cache without a network round-trip
        if let cached = cachedChallenge(), cached.date == today {
            currentChallenge = cached
            completion(.success(cached))
            return
        }

        var request = URLRequest(url: remoteURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            // Network-level error
            if let error {
                DispatchQueue.main.async {
                    completion(.failure(PuzzleLoadError.networkError(error)))
                }
                return
            }

            // HTTP status must be 200
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                DispatchQueue.main.async {
                    completion(.failure(PuzzleLoadError.httpError(http.statusCode)))
                }
                return
            }

            // Data must be present and decode correctly
            guard let data else {
                DispatchQueue.main.async {
                    completion(.failure(PuzzleLoadError.decodingError))
                }
                return
            }

            guard let challenge = try? JSONDecoder().decode(DailyChallenge.self, from: data) else {
                DispatchQueue.main.async {
                    completion(.failure(PuzzleLoadError.decodingError))
                }
                return
            }

            // Structural validation
            do {
                try self.validate(challenge)
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            // All good — cache and deliver
            self.cache(data: data, date: today)
            self.currentChallenge = challenge
            DispatchQueue.main.async { completion(.success(challenge)) }
        }.resume()
    }

    // MARK: - Validation

    private func validate(_ challenge: DailyChallenge) throws {
        guard !challenge.date.isEmpty else {
            throw PuzzleLoadError.invalidPuzzle("Missing date field.")
        }
        guard challenge.waves.count == Constants.Game.wavesPerRound else {
            throw PuzzleLoadError.invalidPuzzle(
                "Expected \(Constants.Game.wavesPerRound) waves, got \(challenge.waves.count).")
        }
        for (i, wave) in challenge.waves.enumerated() {
            guard wave.grid.count == Constants.Game.gridSize else {
                throw PuzzleLoadError.invalidPuzzle(
                    "Wave \(i): expected \(Constants.Game.gridSize) rows, got \(wave.grid.count).")
            }
            for row in wave.grid {
                guard row.count == Constants.Game.gridSize else {
                    throw PuzzleLoadError.invalidPuzzle(
                        "Wave \(i): expected \(Constants.Game.gridSize) columns, got \(row.count).")
                }
                for cell in row {
                    guard cell.count == 1, cell.unicodeScalars.first.map(CharacterSet.letters.contains) == true else {
                        throw PuzzleLoadError.invalidPuzzle(
                            "Wave \(i): invalid cell value '\(cell)'.")
                    }
                }
            }
        }
    }

    // MARK: - Cache (today's successful fetch only)

    private func cache(data: Data, date: String) {
        UserDefaults.standard.set(data, forKey: cacheKey)
        UserDefaults.standard.set(date, forKey: cacheDate)
    }

    private func cachedChallenge() -> DailyChallenge? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(DailyChallenge.self, from: data)
    }

    // MARK: - Helpers

    private func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
