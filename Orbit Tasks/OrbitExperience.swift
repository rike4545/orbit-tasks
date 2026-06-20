import SwiftUI
import Combine

@MainActor
final class OrbitExperience: ObservableObject {
    static let shared = OrbitExperience()

    private enum Keys {
        static let hasCompletedOnboarding = "orbit.experience.hasCompletedOnboarding"
    }

    @Published private(set) var hasCompletedOnboarding: Bool
    private(set) var launchTime: Date

    private let defaults: UserDefaults
    private var adRefreshTask: Task<Void, Never>?

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        self.launchTime = Date()
        scheduleAdThresholdRefreshes()
    }

    var secondsSinceLaunch: TimeInterval {
        Date().timeIntervalSince(launchTime)
    }

    var shouldShowOnboarding: Bool {
        !hasCompletedOnboarding
    }

    var canShowAds: Bool {
        hasCompletedOnboarding && secondsSinceLaunch >= 30
    }

    var canShowAppOpenAds: Bool {
        hasCompletedOnboarding && secondsSinceLaunch >= 60
    }

    func beginSession() {
        launchTime = Date()
        scheduleAdThresholdRefreshes()
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        defaults.set(true, forKey: Keys.hasCompletedOnboarding)
        scheduleAdThresholdRefreshes()
        OrbitInterstitialAdManager.shared.start()
        OrbitAppOpenAdManager.shared.start()
    }

    private func scheduleAdThresholdRefreshes() {
        adRefreshTask?.cancel()
        adRefreshTask = Task { @MainActor in
            objectWillChange.send()

            for threshold in [30.0, 60.0] {
                let delay = max(0, threshold - secondsSinceLaunch)
                guard delay > 0 else { continue }

                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                objectWillChange.send()
            }
        }
    }
}
