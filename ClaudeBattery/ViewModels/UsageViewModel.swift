import Foundation
import AppKit
import Combine

@MainActor
final class UsageViewModel: ObservableObject {

    @Published private(set) var usageData: UsageData?
    @Published private(set) var burnRate: BurnRate = .normal
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var bridgeStatus: BridgeStatus = .notInstalled

    private var burnCalculator = BurnRateCalculator()
    private var refreshTimer: AnyCancellable?
    private var prefsCancellable: AnyCancellable?
    private let prefsManager: PreferencesManager

    init(prefsManager: PreferencesManager = .shared) {
        self.prefsManager = prefsManager
        bridgeStatus = HookBridgeDataSource().currentBridgeStatus
        subscribeToPrefs()
        Task { await refresh() }
    }

    // MARK: - Menu bar label

    var menuBarPresentation: MenuBarPresentation {
        let prefs = prefsManager.preferences
        guard let data = usageData else {
            return MenuBarPresentation(progress: 0, title: "--%", tint: .monochrome, animated: prefs.animatedGauge)
        }

        let used = Int(data.usagePercent * 100)
        let remaining = 100 - used
        let value = prefs.primaryPercentage == .used ? used : remaining
        let percentage = "\(value)%"
        let countdown = prefs.showResetCountdown ? menuBarCountdown(data.timeUntilReset) : nil
        let title = countdown.map { "\(percentage) \($0)" } ?? percentage

        return MenuBarPresentation(
            progress: Double(value) / 100,
            title: title,
            tint: menuBarTint(value: value, prefs: prefs),
            animated: prefs.animatedGauge
        )
    }

    private func menuBarTint(value: Int, prefs: AppPreferences) -> MenuBarGaugeTint {
        guard prefs.gaugeColorMode == .adaptive else { return .monochrome }

        switch prefs.primaryPercentage {
        case .used:
            if value >= 90 { return .critical }
            if value >= 70 { return .medium }
            return .safe
        case .remaining:
            if value <= 10 { return .critical }
            if value <= 30 { return .medium }
            return .safe
        }
    }

    private func menuBarCountdown(_ timeInterval: TimeInterval) -> String? {
        guard timeInterval > 0 else { return nil }
        let seconds = Int(max(0, timeInterval))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return String(format: "%d:%02d", hours, minutes)
    }

    // MARK: - Refresh

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        bridgeStatus = HookBridgeDataSource().currentBridgeStatus

        let source = makeDataSource()
        do {
            let data = try await source.fetch()
            burnRate = burnCalculator.burnRateFromPercent(currentPercent: data.usagePercent)
            usageData = data
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Bridge setup

    func installBridge() async throws {
        try HookBridgeDataSource.installBridgeScript()
        try HookBridgeDataSource.addToClaudeSettings()
        bridgeStatus = .waitingForData
        prefsManager.update { $0.dataSource = .hookBridge }
    }

    // MARK: - Timer management

    func startAutoRefresh() {
        let interval = prefsManager.preferences.refreshInterval
        refreshTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.refresh() }
            }
    }

    func stopAutoRefresh() {
        refreshTimer?.cancel()
        refreshTimer = nil
    }

    // MARK: - Preferences subscription

    private func subscribeToPrefs() {
        prefsCancellable = prefsManager.$preferences
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                self.stopAutoRefresh()
                self.startAutoRefresh()
                Task { await self.refresh() }
            }
    }

    // MARK: - Factory

    private func makeDataSource() -> any UsageDataSource {
        let p = prefsManager.preferences
        switch p.dataSource {
        case .hookBridge:
            return HookBridgeDataSource()
        case .claudeCode:
            return ClaudeCodeDataSource(projectsPath: p.claudeCodePath)
        case .manual:
            return ManualDataSource(prefsManager: prefsManager)
        }
    }
}

struct MenuBarPresentation {
    let progress: Double
    let title: String
    let tint: MenuBarGaugeTint
    let animated: Bool
}


extension UsageViewModel {
    // MARK: - Menu bar arc rendering
    // NOTE: _arcLabelText / _arcLabelColor are intentionally prefixed to avoid
    // colliding with your existing display-mode logic. Wire them to your
    // existing methods if you want DisplayMode preferences to affect the label.

    var menuBarImage: NSImage {
        guard let data = usageData else { return ArcStatusImage.makeIdle() }
        return ArcStatusImage.make(percent: data.usagePercent, status: data.status)
    }

    var menuBarAttributedLabel: NSAttributedString {
        guard let data = usageData else { return NSAttributedString() }
        let text = _arcLabelText(for: data)
        guard !text.isEmpty else { return NSAttributedString() }
        return NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: _arcLabelColor(for: data.status)
        ])
    }

    var menuBarToolTip: String {
        guard let data = usageData else { return "Claude Battery — waiting for data" }
        let pct  = max(0, Int(data.usagePercent * 100))
        let rem  = max(0, 100 - pct)
        let secs = max(0, Int(data.timeUntilReset))
        let age  = Int(-data.lastUpdated.timeIntervalSinceNow)
        let ago: String
        if age < 60 { ago = "just now" }
        else if age < 3600 { ago = "\(age / 60)m ago" }
        else { ago = "\(age / 3600)h ago" }
        return "Used: \(pct)%\nRemaining: \(rem)%\nResets in: \(secs / 3600):\(String(format: "%02d", (secs % 3600) / 60))\nLast updated: \(ago)"
    }

    private func _arcLabelText(for data: UsageData) -> String {
        let pct  = max(0, Int(data.usagePercent * 100))
        let secs = max(0, Int(data.timeUntilReset))
        let cd   = "\(secs / 3600):\(String(format: "%02d", (secs % 3600) / 60))"
        if data.usagePercent >= 0.70 || data.timeUntilReset < 3600 {
            return "\(pct)% \(cd)"
        }
        return "\(pct)%"
    }

    private func _arcLabelColor(for status: UsageStatus) -> NSColor {
        switch status {
        case .safe:                return .labelColor
        case .medium:              return .systemOrange
        case .critical, .depleted: return .systemRed
        }
    }
}

// MARK: - BurnRateCalculator extension for percentage-based tracking

extension BurnRateCalculator {
    mutating func burnRateFromPercent(currentPercent: Double) -> BurnRate {
        let syntheticTokens = Int(currentPercent * 1000)
        record(tokens: syntheticTokens)
        return burnRate(currentUsed: syntheticTokens)
    }
}
