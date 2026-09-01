import Foundation

/// A tiny localisation helper keeps keys out of view code.
enum L10n {
    /// Looks up `key` in the language chosen in iOS Settings.
    static func text(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}
