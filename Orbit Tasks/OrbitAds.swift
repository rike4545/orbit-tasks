import SwiftUI
import GoogleMobileAds
import UIKit

private enum OrbitAdRuntimeOptions {
    static let useTestAdsKey = "orbit.ads.useTestAds"
    static let disableInterstitialsKey = "orbit.ads.disableInterstitials"
    static let disableAppOpenAdsKey = "orbit.ads.disableAppOpen"

    static var useTestAds: Bool {
        if let override = ProcessInfo.processInfo.environment["ORBIT_ADS_USE_TEST_UNITS"] {
            let normalized = override.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalized == "1" || normalized == "true" || normalized == "yes"
        }

        if let idx = ProcessInfo.processInfo.arguments.firstIndex(of: "-OrbitUseTestAds"),
           ProcessInfo.processInfo.arguments.indices.contains(idx + 1) {
            let raw = ProcessInfo.processInfo.arguments[idx + 1].lowercased()
            return raw == "1" || raw == "true" || raw == "yes"
        }

        if UserDefaults.standard.object(forKey: useTestAdsKey) != nil {
            return UserDefaults.standard.bool(forKey: useTestAdsKey)
        }

        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    static func setUseTestAds(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: useTestAdsKey)
    }

    static var disableInterstitialsForDebug: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: disableInterstitialsKey)
        #else
        false
        #endif
    }

    static func setDisableInterstitialsForDebug(_ disabled: Bool) {
        UserDefaults.standard.set(disabled, forKey: disableInterstitialsKey)
    }

    static var disableAppOpenAdsForDebug: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: disableAppOpenAdsKey)
        #else
        false
        #endif
    }

    static func setDisableAppOpenAdsForDebug(_ disabled: Bool) {
        UserDefaults.standard.set(disabled, forKey: disableAppOpenAdsKey)
    }
}

private enum OrbitAdConfig {
    static let productionBannerAdUnitID = "ca-app-pub-9917450718827221/5504772107"
    static let testBannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"
    static let productionInterstitialAdUnitID = "ca-app-pub-9917450718827221/5631676873"
    static let testInterstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
    static let productionAppOpenAdUnitID = "ca-app-pub-9917450718827221/1884003552"
    static let testAppOpenAdUnitID = "ca-app-pub-3940256099942544/5575463023"

    static var bannerAdUnitID: String {
        OrbitAdRuntimeOptions.useTestAds ? testBannerAdUnitID : productionBannerAdUnitID
    }

    static var interstitialAdUnitID: String {
        OrbitAdRuntimeOptions.useTestAds ? testInterstitialAdUnitID : productionInterstitialAdUnitID
    }

    static var appOpenAdUnitID: String {
        OrbitAdRuntimeOptions.useTestAds ? testAppOpenAdUnitID : productionAppOpenAdUnitID
    }
}

enum OrbitAds {
    @MainActor private static var hasStartedMonetization = false

    static var isUsingTestAds: Bool {
        OrbitAdRuntimeOptions.useTestAds
    }

    static var bannerAdUnitID: String {
        OrbitAdConfig.bannerAdUnitID
    }

    static var interstitialAdUnitID: String {
        OrbitAdConfig.interstitialAdUnitID
    }

    static var appOpenAdUnitID: String {
        OrbitAdConfig.appOpenAdUnitID
    }

    static func configureSDKForLaunch() {
        if OrbitAdRuntimeOptions.useTestAds {
            MobileAds.shared.requestConfiguration.testDeviceIdentifiers = ["SIMULATOR"]
        }

        #if DEBUG
        print("OrbitAds: launch mode = \(OrbitAdRuntimeOptions.useTestAds ? "test" : "production")")
        #endif
    }

    @MainActor
    static func startMonetizationAfterLaunchIfNeeded() async {
        guard !hasStartedMonetization else { return }
        hasStartedMonetization = true

        try? await Task.sleep(for: .milliseconds(600))
        guard !Task.isCancelled else { return }

        _ = await MobileAds.shared.start()
        OrbitInterstitialAdManager.shared.start()
        OrbitAppOpenAdManager.shared.start()
    }

    @MainActor
    static func setUseTestAds(_ enabled: Bool) {
        OrbitAdRuntimeOptions.setUseTestAds(enabled)
        OrbitInterstitialAdManager.shared.adConfigurationDidChange()
        OrbitAppOpenAdManager.shared.adConfigurationDidChange()
    }

    @MainActor
    static var disableInterstitialsForDebug: Bool {
        OrbitAdRuntimeOptions.disableInterstitialsForDebug
    }

    @MainActor
    static func setDisableInterstitialsForDebug(_ disabled: Bool) {
        OrbitAdRuntimeOptions.setDisableInterstitialsForDebug(disabled)
        OrbitInterstitialAdManager.shared.adConfigurationDidChange()
    }

    @MainActor
    static var disableAppOpenAdsForDebug: Bool {
        OrbitAdRuntimeOptions.disableAppOpenAdsForDebug
    }

    @MainActor
    static func setDisableAppOpenAdsForDebug(_ disabled: Bool) {
        OrbitAdRuntimeOptions.setDisableAppOpenAdsForDebug(disabled)
        OrbitAppOpenAdManager.shared.adConfigurationDidChange()
    }

    @MainActor
    static func preloadInterstitialForDebug() -> String {
        OrbitInterstitialAdManager.shared.preloadForTesting()
        return "Requested interstitial preload."
    }

    @MainActor
    static func presentInterstitialForDebug() -> String {
        OrbitInterstitialAdManager.shared.presentForTesting()
    }

    @MainActor
    static func preloadAppOpenForDebug() -> String {
        OrbitAppOpenAdManager.shared.preloadForTesting()
        return "Requested app open preload."
    }

    @MainActor
    static func presentAppOpenForDebug() -> String {
        OrbitAppOpenAdManager.shared.presentForTesting()
    }

    @MainActor
    static func openAdInspectorForDebug() async -> String {
        guard let root = UIApplication.shared.adPresentationHostViewController else {
            return "No active view controller available for Ad Inspector."
        }

        return await withCheckedContinuation { continuation in
            MobileAds.shared.presentAdInspector(from: root) { error in
                if let error {
                    continuation.resume(returning: "Ad Inspector error: \(error.localizedDescription)")
                } else {
                    continuation.resume(returning: "Ad Inspector closed.")
                }
            }
        }
    }
}

struct OrbitBannerAd: View {
    @State private var availableWidth: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { availableWidth = proxy.size.width }
                .onChange(of: proxy.size.width) { _, newWidth in
                    availableWidth = newWidth
                }
        }
        .frame(height: bannerHeight)
        .overlay {
            if availableWidth >= 320 {
                OrbitBannerAdRepresentable(
                    adUnitID: OrbitAdConfig.bannerAdUnitID,
                    adSize: currentOrientationAnchoredAdaptiveBanner(width: availableWidth)
                )
                .frame(width: availableWidth, height: bannerHeight)
            }
        }
    }

    private var bannerHeight: CGFloat {
        max(currentOrientationAnchoredAdaptiveBanner(width: max(availableWidth, 320)).size.height, 50)
    }
}

private struct OrbitBannerAdRepresentable: UIViewRepresentable {
    let adUnitID: String
    let adSize: AdSize

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: adSize)
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = UIApplication.shared.adPresentationHostViewController
        bannerView.delegate = context.coordinator
        context.coordinator.load(bannerView, force: true)
        return bannerView
    }

    func updateUIView(_ bannerView: BannerView, context: Context) {
        var shouldForceLoad = false

        if bannerView.adUnitID != adUnitID {
            bannerView.adUnitID = adUnitID
            shouldForceLoad = true
        }

        if bannerView.adSize.size != adSize.size {
            bannerView.adSize = adSize
            shouldForceLoad = true
        }

        if bannerView.rootViewController == nil {
            bannerView.rootViewController = UIApplication.shared.adPresentationHostViewController
        }

        context.coordinator.load(bannerView, force: shouldForceLoad)
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        private var lastRequestedSignature: String = ""
        private var lastLoadAt = Date.distantPast

        func load(_ bannerView: BannerView, force: Bool) {
            let signature = "\(bannerView.adUnitID ?? "")|\(bannerView.adSize.size.width)x\(bannerView.adSize.size.height)"
            let now = Date()

            // Guard against repetitive load thrash from rapid SwiftUI updates.
            if !force && signature == lastRequestedSignature && now.timeIntervalSince(lastLoadAt) < 2 {
                return
            }

            lastRequestedSignature = signature
            lastLoadAt = now
            bannerView.load(Request())
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            #if DEBUG
            print("OrbitAds: banner loaded (\(bannerView.adUnitID ?? "unknown"))")
            #endif
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: any Error) {
            #if DEBUG
            print("OrbitAds: banner failed (\(bannerView.adUnitID ?? "unknown")): \(error.localizedDescription)")
            #endif
        }
    }
}

private struct OrbitBannerPlacementModifier: ViewModifier {
    @EnvironmentObject private var purchases: OrbitPurchaseManager
    @StateObject private var experience = OrbitExperience.shared

    func body(content: Content) -> some View {
        if purchases.hasRemovedAds || !experience.canShowAds {
            content
        } else {
            content.safeAreaInset(edge: .bottom) {
                OrbitBannerAd()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
            }
        }
    }
}

extension View {
    func orbitBannerPlacement() -> some View {
        modifier(OrbitBannerPlacementModifier())
    }
}

@MainActor
final class OrbitInterstitialAdManager: NSObject, FullScreenContentDelegate {
    static let shared = OrbitInterstitialAdManager()

    private var interstitialAd: InterstitialAd?
    private var isLoadingInterstitial = false
    private var isPresentingInterstitial = false
    private var taskCompletionsSinceLastInterstitial = 0
    private var lastInterstitialShownAt: Date?
    private var adsRemoved = UserDefaults.standard.bool(forKey: OrbitMonetizationKeys.adsRemovedEntitlement)

    private var sessionInterstitialImpressions = 0
    private let sessionInterstitialImpressionCap = 6

    private var consecutiveLoadFailures = 0
    private var nextLoadAllowedAt = Date.distantPast
    private var retryLoadTask: Task<Void, Never>?

    private let minCompletionsBeforeShow = 6
    private let minTimeAfterLaunch: TimeInterval = 90
    private let minIntervalBetweenShows: TimeInterval = 150
    private let maxLoadRetryDelay: TimeInterval = 180

    private override init() {
        super.init()
    }

    var isPresentingAd: Bool {
        isPresentingInterstitial
    }

    func start() {
        guard !adsRemoved else { return }
        loadInterstitialIfNeeded()
    }

    func recordTaskCompletionEvent() {
        guard !adsRemoved else { return }
        taskCompletionsSinceLastInterstitial += 1
        presentIfEligible()
    }

    func setAdsRemoved(_ removed: Bool) {
        adsRemoved = removed
        if removed {
            clearInterstitialState(resetPacing: true)
        } else {
            loadInterstitialIfNeeded(force: true)
        }
    }

    func adConfigurationDidChange() {
        clearInterstitialState(resetPacing: false)
        if !adsRemoved {
            loadInterstitialIfNeeded(force: true)
        }
    }

    func preloadForTesting() {
        guard !adsRemoved else { return }
        loadInterstitialIfNeeded(force: true)
    }

    func presentForTesting() -> String {
        guard !adsRemoved else {
            return "Ads are removed for this account."
        }

        #if DEBUG
        if OrbitAdRuntimeOptions.disableInterstitialsForDebug {
            return "Interstitials are disabled in debug controls."
        }
        #endif

        guard UIApplication.shared.applicationState == .active else {
            return "App must be active to present an interstitial."
        }

        guard let presenter = UIApplication.shared.adPresentationHostViewController else {
            return "No presenter available right now."
        }

        guard let interstitialAd else {
            loadInterstitialIfNeeded(force: true)
            return "Interstitial not ready yet. Triggered preload."
        }

        interstitialAd.present(from: presenter)
        return "Presented interstitial."
    }

    private func presentIfEligible() {
        guard !adsRemoved else { return }

        #if DEBUG
        if OrbitAdRuntimeOptions.disableInterstitialsForDebug {
            return
        }
        #endif

        guard UIApplication.shared.applicationState == .active else {
            loadInterstitialIfNeeded()
            return
        }

        guard !isPresentingInterstitial else {
            return
        }

        guard sessionInterstitialImpressions < sessionInterstitialImpressionCap else {
            return
        }

        let now = Date()
        let experience = OrbitExperience.shared

        guard experience.canShowAds else {
            loadInterstitialIfNeeded()
            return
        }

        guard experience.secondsSinceLaunch >= minTimeAfterLaunch else {
            loadInterstitialIfNeeded()
            return
        }

        guard taskCompletionsSinceLastInterstitial >= minCompletionsBeforeShow else {
            loadInterstitialIfNeeded()
            return
        }

        if let lastInterstitialShownAt,
           now.timeIntervalSince(lastInterstitialShownAt) < minIntervalBetweenShows {
            loadInterstitialIfNeeded()
            return
        }

        guard let interstitialAd else {
            loadInterstitialIfNeeded()
            return
        }

        guard let presenter = UIApplication.shared.adPresentationHostViewController else {
            loadInterstitialIfNeeded()
            return
        }

        interstitialAd.present(from: presenter)
    }

    private func loadInterstitialIfNeeded(force: Bool = false) {
        guard !adsRemoved else { return }
        guard OrbitExperience.shared.hasCompletedOnboarding else { return }
        guard !isLoadingInterstitial else { return }
        guard interstitialAd == nil else { return }

        let now = Date()
        if !force && now < nextLoadAllowedAt {
            scheduleRetryLoad(after: nextLoadAllowedAt.timeIntervalSince(now))
            return
        }

        isLoadingInterstitial = true

        InterstitialAd.load(
            with: OrbitAdConfig.interstitialAdUnitID,
            request: Request()
        ) { [weak self] ad, error in
            guard let self else { return }

            Task { @MainActor in
                self.isLoadingInterstitial = false

                if let error {
                    self.consecutiveLoadFailures += 1
                    let delay = min(pow(2, Double(self.consecutiveLoadFailures)) * 2, self.maxLoadRetryDelay)
                    self.nextLoadAllowedAt = Date().addingTimeInterval(delay)
                    self.scheduleRetryLoad(after: delay)

                    #if DEBUG
                    print("OrbitAds: interstitial failed (attempt \(self.consecutiveLoadFailures)): \(error.localizedDescription)")
                    #endif
                    return
                }

                self.retryLoadTask?.cancel()
                self.retryLoadTask = nil
                self.consecutiveLoadFailures = 0
                self.nextLoadAllowedAt = .distantPast

                self.interstitialAd = ad
                self.interstitialAd?.fullScreenContentDelegate = self

                #if DEBUG
                print("OrbitAds: interstitial loaded (\(OrbitAdConfig.interstitialAdUnitID))")
                #endif
            }
        }
    }

    private func scheduleRetryLoad(after delay: TimeInterval) {
        retryLoadTask?.cancel()

        let safeDelay = max(1, delay)
        retryLoadTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(safeDelay))
            guard !Task.isCancelled else { return }
            self.loadInterstitialIfNeeded()
        }
    }

    private func clearInterstitialState(resetPacing: Bool) {
        retryLoadTask?.cancel()
        retryLoadTask = nil

        interstitialAd = nil
        isLoadingInterstitial = false
        isPresentingInterstitial = false
        consecutiveLoadFailures = 0
        nextLoadAllowedAt = .distantPast

        if resetPacing {
            taskCompletionsSinceLastInterstitial = 0
            lastInterstitialShownAt = nil
            sessionInterstitialImpressions = 0
        }
    }

    // MARK: - FullScreenContentDelegate

    func adWillPresentFullScreenContent(_ ad: any FullScreenPresentingAd) {
        isPresentingInterstitial = true
        lastInterstitialShownAt = Date()
    }

    func adDidRecordImpression(_ ad: any FullScreenPresentingAd) {
        sessionInterstitialImpressions += 1
        taskCompletionsSinceLastInterstitial = 0
    }

    func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: any Error) {
        #if DEBUG
        print("OrbitAds: interstitial failed to present: \(error.localizedDescription)")
        #endif

        isPresentingInterstitial = false
        interstitialAd = nil
        loadInterstitialIfNeeded(force: true)
    }

    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        isPresentingInterstitial = false
        interstitialAd = nil
        loadInterstitialIfNeeded()
    }
}

@MainActor
final class OrbitAppOpenAdManager: NSObject, FullScreenContentDelegate {
    static let shared = OrbitAppOpenAdManager()

    private var appOpenAd: AppOpenAd?
    private var isLoadingAppOpen = false
    private var isPresentingAppOpen = false
    private var adsRemoved = UserDefaults.standard.bool(forKey: OrbitMonetizationKeys.adsRemovedEntitlement)
    private var loadDate: Date?
    private var lastShownAt: Date?
    private var didEnterBackgroundAt: Date?
    private var hasBackgroundedOnce = false

    private let adMaxAge: TimeInterval = 4 * 60 * 60
    private let minIntervalBetweenShows: TimeInterval = 180

    private override init() {
        super.init()
    }

    func start() {
        guard !adsRemoved else { return }
        loadAppOpenIfNeeded(force: true)
    }

    func setAdsRemoved(_ removed: Bool) {
        adsRemoved = removed
        if removed {
            clearState()
        } else {
            loadAppOpenIfNeeded(force: true)
        }
    }

    func adConfigurationDidChange() {
        clearState()
        if !adsRemoved {
            loadAppOpenIfNeeded(force: true)
        }
    }

    func sceneDidEnterBackground() {
        hasBackgroundedOnce = true
        didEnterBackgroundAt = Date()
    }

    func sceneDidBecomeActive() {
        guard !adsRemoved else { return }
        guard hasBackgroundedOnce else {
            loadAppOpenIfNeeded()
            return
        }
        presentIfEligible()
    }

    func preloadForTesting() {
        guard !adsRemoved else { return }
        loadAppOpenIfNeeded(force: true)
    }

    func presentForTesting() -> String {
        guard !adsRemoved else {
            return "Ads are removed for this account."
        }

        #if DEBUG
        if OrbitAdRuntimeOptions.disableAppOpenAdsForDebug {
            return "App open ads are disabled in debug controls."
        }
        #endif

        guard UIApplication.shared.applicationState == .active else {
            return "App must be active to present an app open ad."
        }

        guard !OrbitInterstitialAdManager.shared.isPresentingAd else {
            return "Interstitial currently active; try again shortly."
        }

        guard let presenter = UIApplication.shared.adPresentationHostViewController else {
            return "No presenter available right now."
        }

        guard let appOpenAd else {
            loadAppOpenIfNeeded(force: true)
            return "App open ad not ready yet. Triggered preload."
        }

        appOpenAd.present(from: presenter)
        return "Presented app open ad."
    }

    private func presentIfEligible() {
        #if DEBUG
        if OrbitAdRuntimeOptions.disableAppOpenAdsForDebug {
            return
        }
        #endif

        let experience = OrbitExperience.shared

        guard UIApplication.shared.applicationState == .active else {
            loadAppOpenIfNeeded()
            return
        }

        guard experience.canShowAppOpenAds else {
            loadAppOpenIfNeeded()
            return
        }

        guard !isPresentingAppOpen else { return }
        guard !OrbitInterstitialAdManager.shared.isPresentingAd else { return }

        if let backgroundedAt = didEnterBackgroundAt,
           Date().timeIntervalSince(backgroundedAt) < 5 {
            // Skip noisy foreground flaps.
            loadAppOpenIfNeeded()
            return
        }

        if let lastShownAt,
           Date().timeIntervalSince(lastShownAt) < minIntervalBetweenShows {
            loadAppOpenIfNeeded()
            return
        }

        guard let presenter = UIApplication.shared.adPresentationHostViewController else {
            loadAppOpenIfNeeded()
            return
        }

        guard let appOpenAd else {
            loadAppOpenIfNeeded()
            return
        }

        if isAppOpenExpired {
            self.appOpenAd = nil
            loadAppOpenIfNeeded(force: true)
            return
        }

        appOpenAd.present(from: presenter)
    }

    private var isAppOpenExpired: Bool {
        guard let loadDate else { return true }
        return Date().timeIntervalSince(loadDate) >= adMaxAge
    }

    private func loadAppOpenIfNeeded(force: Bool = false) {
        guard !adsRemoved else { return }
        guard OrbitExperience.shared.hasCompletedOnboarding else { return }
        guard !isLoadingAppOpen else { return }
        if !force, appOpenAd != nil, !isAppOpenExpired { return }

        if isAppOpenExpired {
            appOpenAd = nil
        }

        isLoadingAppOpen = true
        AppOpenAd.load(
            with: OrbitAdConfig.appOpenAdUnitID,
            request: Request()
        ) { [weak self] ad, error in
            guard let self else { return }
            Task { @MainActor in
                self.isLoadingAppOpen = false
                if let error {
                    #if DEBUG
                    print("OrbitAds: app open failed: \(error.localizedDescription)")
                    #endif
                    return
                }

                self.appOpenAd = ad
                self.loadDate = Date()
                self.appOpenAd?.fullScreenContentDelegate = self
                #if DEBUG
                print("OrbitAds: app open loaded (\(OrbitAdConfig.appOpenAdUnitID))")
                #endif
            }
        }
    }

    private func clearState() {
        appOpenAd = nil
        isLoadingAppOpen = false
        isPresentingAppOpen = false
        loadDate = nil
        lastShownAt = nil
    }

    func adWillPresentFullScreenContent(_ ad: any FullScreenPresentingAd) {
        isPresentingAppOpen = true
        lastShownAt = Date()
    }

    func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: any Error) {
        #if DEBUG
        print("OrbitAds: app open failed to present: \(error.localizedDescription)")
        #endif
        isPresentingAppOpen = false
        appOpenAd = nil
        loadDate = nil
        loadAppOpenIfNeeded(force: true)
    }

    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        isPresentingAppOpen = false
        appOpenAd = nil
        loadDate = nil
        loadAppOpenIfNeeded(force: true)
    }
}

private extension UIApplication {
    var adPresentationHostViewController: UIViewController? {
        let activeWindowScene = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        let root = activeWindowScene?
            .windows
            .first(where: { $0.isKeyWindow })?
            .rootViewController

        var current = root
        while let presented = current?.presentedViewController {
            current = presented
        }

        if current is UIAlertController {
            return nil
        }

        return current
    }
}
