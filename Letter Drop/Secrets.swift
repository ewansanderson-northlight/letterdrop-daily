import Foundation

enum Secrets {
    static var postHogApiKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "POSTHOG_API_KEY") as? String,
              !key.isEmpty else {
            #if DEBUG
            fatalError("POSTHOG_API_KEY is missing. Check your .xcconfig file.")
            #else
            return ""
            #endif
        }
        return key
    }
}
