//
//  DictionaryService.swift
//  Letter Drop
//
//  Fetches word definitions from the Free Dictionary API.
//  https://api.dictionaryapi.dev/api/v2/entries/en/[word]
//

import Foundation

enum DictionaryService {

    struct Entry {
        let partOfSpeech: String
        let definition: String
    }

    enum FetchError: Error {
        case notFound
        case network
    }

    static func fetch(word: String) async throws -> Entry {
        let encoded = word.lowercased()
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? word.lowercased()

        guard let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(encoded)")
        else { throw FetchError.network }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw FetchError.network
        }

        guard (response as? HTTPURLResponse)?.statusCode == 200
        else { throw FetchError.notFound }

        guard
            let json     = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
            let first    = json.first,
            let meanings = first["meanings"] as? [[String: Any]],
            let meaning  = meanings.first,
            let pos      = meaning["partOfSpeech"] as? String,
            let defs     = meaning["definitions"] as? [[String: Any]],
            let def      = defs.first?["definition"] as? String
        else { throw FetchError.notFound }

        return Entry(partOfSpeech: pos, definition: def)
    }
}
