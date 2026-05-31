import Foundation

final class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()

    private let defaults = UserDefaults.standard
    private enum Key: String {
        case dataSource, displayMode, primaryPercentage, showResetCountdown
        case animatedGauge, gaugeColorMode, refreshInterval, launchAtLogin
        case showPromptEstimates, manualPlan, manualCustomTokens
        case manualUsedTokens, manualResetDate, claudeCodePath
    }

    @Published var preferences = AppPreferences() {
        didSet { save() }
    }

    private init() {
        load()
    }

    private func load() {
        var p = AppPreferences()

        if let raw = defaults.string(forKey: Key.dataSource.rawValue),
           let v = DataSourceType(rawValue: raw) { p.dataSource = v }

        if let raw = defaults.string(forKey: Key.primaryPercentage.rawValue),
           let v = PrimaryPercentage(rawValue: raw) {
            p.primaryPercentage = v
        } else if let raw = defaults.string(forKey: Key.displayMode.rawValue) {
            let migrated = Self.migratedDisplayMode(raw)
            p.primaryPercentage = migrated.primaryPercentage
            p.showResetCountdown = migrated.showResetCountdown
        }

        if defaults.object(forKey: Key.showResetCountdown.rawValue) != nil {
            p.showResetCountdown = defaults.bool(forKey: Key.showResetCountdown.rawValue)
        }
        if defaults.object(forKey: Key.animatedGauge.rawValue) != nil {
            p.animatedGauge = defaults.bool(forKey: Key.animatedGauge.rawValue)
        }
        if let raw = defaults.string(forKey: Key.gaugeColorMode.rawValue),
           let v = GaugeColorMode(rawValue: raw) {
            p.gaugeColorMode = v
        }

        let interval = defaults.double(forKey: Key.refreshInterval.rawValue)
        if interval > 0 { p.refreshInterval = interval }

        p.launchAtLogin = defaults.bool(forKey: Key.launchAtLogin.rawValue)

        let showEstimates = defaults.object(forKey: Key.showPromptEstimates.rawValue)
        p.showPromptEstimates = showEstimates.map { ($0 as? Bool) ?? true } ?? true

        if let raw = defaults.string(forKey: Key.manualPlan.rawValue),
           let v = ClaudePlan(rawValue: raw) { p.manualPlan = v }

        let customTokens = defaults.integer(forKey: Key.manualCustomTokens.rawValue)
        if customTokens > 0 { p.manualCustomTokens = customTokens }

        let usedTokens = defaults.integer(forKey: Key.manualUsedTokens.rawValue)
        if usedTokens >= 0 { p.manualUsedTokens = usedTokens }

        if let resetDate = defaults.object(forKey: Key.manualResetDate.rawValue) as? Date {
            p.manualResetDate = resetDate
        }

        if let path = defaults.string(forKey: Key.claudeCodePath.rawValue) {
            p.claudeCodePath = path
        }

        preferences = p
    }

    private static func migratedDisplayMode(_ raw: String) -> (primaryPercentage: PrimaryPercentage, showResetCountdown: Bool) {
        switch raw {
        case "remainingPercentage":
            return (.remaining, false)
        case "remainingAndResetCountdown":
            return (.remaining, true)
        case "usedAndResetCountdown", "countdown", "smart", "compact":
            return (.used, true)
        default:
            return (.used, false)
        }
    }

    private func save() {
        let p = preferences
        defaults.set(p.dataSource.rawValue, forKey: Key.dataSource.rawValue)
        defaults.set(p.primaryPercentage.rawValue, forKey: Key.primaryPercentage.rawValue)
        defaults.set(p.showResetCountdown, forKey: Key.showResetCountdown.rawValue)
        defaults.set(p.animatedGauge, forKey: Key.animatedGauge.rawValue)
        defaults.set(p.gaugeColorMode.rawValue, forKey: Key.gaugeColorMode.rawValue)
        defaults.set(p.refreshInterval, forKey: Key.refreshInterval.rawValue)
        defaults.set(p.launchAtLogin, forKey: Key.launchAtLogin.rawValue)
        defaults.set(p.showPromptEstimates, forKey: Key.showPromptEstimates.rawValue)
        defaults.set(p.manualPlan.rawValue, forKey: Key.manualPlan.rawValue)
        defaults.set(p.manualCustomTokens, forKey: Key.manualCustomTokens.rawValue)
        defaults.set(p.manualUsedTokens, forKey: Key.manualUsedTokens.rawValue)
        defaults.set(p.manualResetDate, forKey: Key.manualResetDate.rawValue)
        defaults.set(p.claudeCodePath, forKey: Key.claudeCodePath.rawValue)
    }

    // Convenience mutators to avoid full-struct replacement at call sites
    func update(_ block: (inout AppPreferences) -> Void) {
        var p = preferences
        block(&p)
        preferences = p
    }
}
