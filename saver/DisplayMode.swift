import ScreenSaver

/// How the covers are shown, saved in the screensaver's own defaults.
enum DisplayMode: String, CaseIterable {
    case wall
    case origami

    var title: String {
        switch self {
        case .wall: "Wall"
        case .origami: "Origami"
        }
    }

    /// Seconds between changes.
    var interval: TimeInterval {
        switch self {
        case .wall: 3
        case .origami: 4
        }
    }

    private static let key = "displayMode"
    private static var defaults: ScreenSaverDefaults? {
        ScreenSaverDefaults(forModuleWithName: "local.covers-for-steam")
    }

    static var saved: DisplayMode {
        get { defaults?.string(forKey: key).flatMap(DisplayMode.init) ?? .wall }
        set {
            defaults?.set(newValue.rawValue, forKey: key)
            defaults?.synchronize()
        }
    }
}
