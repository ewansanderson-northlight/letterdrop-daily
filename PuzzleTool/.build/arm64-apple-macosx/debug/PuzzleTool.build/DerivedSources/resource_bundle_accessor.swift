import Foundation

extension Foundation.Bundle {
    static let module: Bundle = {
        let mainPath = Bundle.main.bundleURL.appendingPathComponent("PuzzleTool_PuzzleTool.bundle").path
        let buildPath = "/Users/ewansanderson/Claude Projects/BETA Gaming Project/Letter Drop/PuzzleTool/.build/arm64-apple-macosx/debug/PuzzleTool_PuzzleTool.bundle"

        let preferredBundle = Bundle(path: mainPath)

        guard let bundle = preferredBundle ?? Bundle(path: buildPath) else {
            // Users can write a function called fatalError themselves, we should be resilient against that.
            Swift.fatalError("could not load resource bundle: from \(mainPath) or \(buildPath)")
        }

        return bundle
    }()
}