import UIKit
import GoogleMobileAds

/// Counts accepted Continue reading taps across screens and app launches.
@MainActor
final class ContinueReadingAdFrequency {
    private let defaults: UserDefaults
    private let key = "ads.continueReadingTapRemainder"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func registerTap() -> Bool {
        let remainder = max(0, defaults.integer(forKey: key)) % 5
        let next = (remainder + 1) % 5
        defaults.set(next, forKey: key)
        return next == 0
    }
}

/// Separates navigation from the SDK so failed/unavailable ads never block reading.
@MainActor
final class ContinueReadingAdFlow {
    private let frequency: ContinueReadingAdFrequency
    private var pending: UUID?

    init(frequency: ContinueReadingAdFrequency) {
        self.frequency = frequency
    }

    func continueReading(presentAd: (@escaping () -> Void) -> Bool, openArticle: @escaping () -> Void) {
        guard pending == nil else { return }
        let token = UUID()
        pending = token
        let finish = { [weak self] in
            guard let self, self.pending == token else { return }
            self.pending = nil
            openArticle()
        }
        if frequency.registerTap(), presentAd(finish) { return }
        finish()
    }
}

@MainActor
final class ContinueReadingInterstitial: NSObject, FullScreenContentDelegate {
    static let shared = ContinueReadingInterstitial()

    private let flow = ContinueReadingAdFlow(frequency: ContinueReadingAdFrequency())
    private var interstitial: InterstitialAd?
    private var loadedAt: Date?
    private var loading: Task<Void, Never>?
    private var generation = 0
    private var presentingAd: InterstitialAd?
    private var finishReading: (() -> Void)?

    private var isFresh: Bool {
        guard let loadedAt else { return false }
        // Google interstitials expire after an hour; refresh before that boundary.
        return Date().timeIntervalSince(loadedAt) < 55 * 60
    }

    func preload(from controller: UIViewController) {
        guard ConfigurationManager.isInterstitialAdsEnabled(),
              controller.viewIfLoaded?.window != nil,
              loading == nil, presentingAd == nil else { return }
        if interstitial != nil, isFresh { return }
        interstitial = nil
        loadedAt = nil
        let currentGeneration = generation
        loading = Task { [weak self, weak controller] in
            guard let self else { return }
            defer { loading = nil }
            guard let controller,
                  await AdMobManager.shared.prepareForAds(from: controller),
                  currentGeneration == generation else { return }
            let unitID = ConfigurationManager.admobInterstitialAdUnitId()
            guard !unitID.isEmpty else { return }
            do {
                let ad = try await InterstitialAd.load(with: unitID, request: Request())
                guard currentGeneration == generation, AdMobManager.shared.canDisplayAds else { return }
                ad.fullScreenContentDelegate = self
                interstitial = ad
                loadedAt = Date()
            } catch {
                print("AdMob interstitial load: \(error.localizedDescription)")
            }
        }
    }

    func continueReading(from controller: UIViewController, openArticle: @escaping () -> Void) {
        flow.continueReading(presentAd: { [self] completion in
            guard ConfigurationManager.isInterstitialAdsEnabled(),
                  AdMobManager.shared.canDisplayAds,
                  controller.viewIfLoaded?.window?.windowScene?.activationState == .foregroundActive,
                  controller.presentedViewController == nil,
                  let ad = interstitial, isFresh else { return false }
            do {
                try ad.canPresent(from: controller)
            } catch {
                invalidate()
                return false
            }
            interstitial = nil
            loadedAt = nil
            presentingAd = ad
            finishReading = completion
            ad.present(from: controller)
            return true
        }, openArticle: openArticle)
    }

    /// Drop cached ads and ignore outstanding loads when privacy choices change.
    func invalidate() {
        generation += 1
        interstitial = nil
        loadedAt = nil
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finishPresentation()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("AdMob interstitial presentation: \(error.localizedDescription)")
        finishPresentation()
    }

    private func finishPresentation() {
        presentingAd = nil
        let completion = finishReading
        finishReading = nil
        completion?()
        // The next excerpt appearance preloads the next single-use ad.
    }
}
