//
//  WordDefinitionSheet.swift
//  Letter Drop
//
//  Modal dictionary card shown when a best word is tapped on the results screen.
//

import SwiftUI

struct WordDefinitionSheet: View {
    let word: String
    @Binding var isPresented: Bool

    private enum LoadState {
        case loading
        case loaded(DictionaryService.Entry)
        case offline
        case failed
    }

    @State private var loadState: LoadState = .loading

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // ── Close button ────────────────────────────────────────────
                HStack {
                    Spacer()
                    Button { isPresented = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28, weight: .regular))
                            .foregroundStyle(Constants.Colors.tile.opacity(0.35))
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)

                // ── Word title ──────────────────────────────────────────────
                Text(word.uppercased())
                    .font(Constants.Fonts.rounded(52, weight: .bold))
                    .foregroundStyle(Constants.Colors.scoreGold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)

                // ── Content ─────────────────────────────────────────────────
                switch loadState {

                case .loading:
                    Spacer()
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(Constants.Colors.tile.opacity(0.55))
                            .scaleEffect(1.3)
                        Spacer()
                    }
                    Spacer()

                case .loaded(let entry):
                    Text(entry.partOfSpeech)
                        .font(.system(size: 15, weight: .regular).italic())
                        .foregroundStyle(Constants.Colors.tile.opacity(0.42))
                        .padding(.bottom, 20)

                    Text(entry.definition)
                        .font(Constants.Fonts.rounded(18, weight: .regular))
                        .foregroundStyle(Constants.Colors.tile)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()

                    Button {
                        let query = word.lowercased()
                            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
                            ?? word.lowercased()
                        if let url = URL(string: "https://en.wiktionary.org/wiki/\(query)") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Learn more")
                            Image(systemName: "arrow.right")
                        }
                        .font(Constants.Fonts.rounded(16, weight: .semibold))
                        .foregroundStyle(Constants.Colors.scoreGold)
                    }
                    .padding(.bottom, 16)

                    Text("Definitions provided by FreeDictionaryAPI.com")
                        .font(Constants.Fonts.rounded(11, weight: .regular))
                        .foregroundStyle(Constants.Colors.tile.opacity(0.22))

                case .offline:
                    Text("No connection right now — try again when you're online. The word is valid though, we promise! 🤷")
                        .font(Constants.Fonts.rounded(17, weight: .regular))
                        .foregroundStyle(Constants.Colors.tile.opacity(0.60))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()

                case .failed:
                    Text("No definition found — but we promise it's a word! 🤷")
                        .font(Constants.Fonts.rounded(17, weight: .regular))
                        .foregroundStyle(Constants.Colors.tile.opacity(0.60))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 24)

                    Spacer()

                    Button {
                        let query = word
                            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                            ?? word
                        if let url = URL(string: "https://www.google.com/search?q=define+\(query)") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Search Google")
                            Image(systemName: "arrow.right")
                        }
                        .font(Constants.Fonts.rounded(16, weight: .semibold))
                        .foregroundStyle(Constants.Colors.scoreGold)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
        .presentationBackground(Constants.Colors.background)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .task {
            do {
                let entry = try await DictionaryService.fetch(word: word)
                loadState = .loaded(entry)
            } catch DictionaryService.FetchError.network {
                loadState = .offline
            } catch {
                loadState = .failed
            }
        }
    }
}
