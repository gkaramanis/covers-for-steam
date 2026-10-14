import ScreenSaver

/// Options saved in the screensaver's own defaults.
enum Preferences {
    private static var defaults: ScreenSaverDefaults? {
        ScreenSaverDefaults(forModuleWithName: "local.covers-for-steam")
    }

    static var mode: DisplayMode {
        get { defaults?.string(forKey: "displayMode").flatMap(DisplayMode.init) ?? .wall }
        set { save(newValue.rawValue, forKey: "displayMode") }
    }

    /// Steam's generated covers for apps with no portrait art: the landscape
    /// banner over a blurred stretch of its colours.
    static var includeGenerated: Bool {
        get { defaults?.bool(forKey: "includeGenerated") ?? false }
        set { save(newValue, forKey: "includeGenerated") }
    }

    private static func save(_ value: Any, forKey key: String) {
        defaults?.set(value, forKey: key)
        defaults?.synchronize()
    }
}
