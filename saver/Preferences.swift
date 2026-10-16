import Foundation
import os

/// Options saved as a plist in Application Support. Inside legacyScreenSaver
/// that is the sandbox container, which every saver instance shares.
/// ScreenSaverDefaults did not keep values between instances there.
enum Preferences {
    private static let log = Logger(subsystem: "is.karaman.covers-for-steam", category: "preferences")

    private static var url: URL {
        URL.applicationSupportDirectory.appending(path: "is.karaman.covers-for-steam/Preferences.plist")
    }

    static var mode: DisplayMode {
        get { (load()["displayMode"] as? String).flatMap(DisplayMode.init) ?? .wall }
        set { save(newValue.rawValue, forKey: "displayMode") }
    }

    /// Steam's generated covers for apps with no portrait art: the landscape
    /// banner over a blurred stretch of its colours.
    static var includeGenerated: Bool {
        get { load()["includeGenerated"] as? Bool ?? false }
        set { save(newValue, forKey: "includeGenerated") }
    }

    /// Leave out tools, servers and applications; games and demos stay.
    static var gamesOnly: Bool {
        get { load()["gamesOnly"] as? Bool ?? true }
        set { save(newValue, forKey: "gamesOnly") }
    }

    private static func load() -> [String: Any] {
        NSDictionary(contentsOf: url) as? [String: Any] ?? [:]
    }

    private static func save(_ value: Any, forKey key: String) {
        var values = load()
        values[key] = value
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try (values as NSDictionary).write(to: url)
            log.notice("Saved \(key, privacy: .public) = \(String(describing: value), privacy: .public)")
        } catch {
            log.error("Cannot save \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
