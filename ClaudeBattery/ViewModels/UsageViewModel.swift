import Foundation
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

    var menuBarTitle: String {
        guard let data = usageData else { return "--%" }
        let pct = Int(data.usagePercent * 100)
        return "\(pct)%"
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

// MARK: - BurnRateCalculator extension for percentage-based tracking

extension BurnRateCalculator {
    mutating func burnRateFromPercent(currentPercent: Double) -> BurnRate {
        let syntheticTokens = Int(currentPercent * 1000)
        record(tokens: syntheticTokens)
        return burnRate(currentUsed: syntheticTokens)
    }
}
