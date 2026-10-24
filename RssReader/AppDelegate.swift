//
//  AppDelegate.swift
//  RssReader
//
//  Created by AppCoda on 11/20/14.
//  Copyright (c) 2014 AppCoda Limited. All rights reserved.
//

import UIKit
import GoogleMobileAds
import UserMessagingPlatform

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, shouldSaveSecureApplicationState coder: NSCoder) -> Bool {
        true
    }

    func application(_ application: UIApplication, shouldRestoreSecureApplicationState coder: NSCoder) -> Bool {
        true
    }

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithOpaqueBackground()
        navigationAppearance.backgroundColor = .systemBackground
        navigationAppearance.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        UINavigationBar.appearance().standardAppearance = navigationAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationAppearance
        UINavigationBar.appearance().compactAppearance = navigationAppearance
        UINavigationBar.appearance().tintColor = .systemBlue

        // AdMob starts after the first visible placement gathers consent.
        
        // To fix the background color issue of the menu table view
        if #available(iOS 14.0, *) {
            var bgConfig = UIBackgroundConfiguration.listPlainCell()
            bgConfig.backgroundColor = UIColor.clear
            UITableViewHeaderFooterView.appearance().backgroundConfiguration = bgConfig
        }
        
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        let key = UIDevice.current.userInterfaceIdiom == .pad ? "UIMainStoryboardFile~ipad" : "UIMainStoryboardFile"
        let storyboardName = Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "Main_iPhone-3"
        configuration.storyboard = UIStoryboard(name: storyboardName, bundle: nil)
        return configuration
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

/// Serializes consent and SDK startup across the iPhone and iPad placements.
@MainActor
final class AdMobManager {
    static let shared = AdMobManager()

    private final class Placement {
        weak var banner: BannerView?
        weak var controller: UIViewController?
        weak var table: UITableView?
        var requestedSize: CGSize?
        var isPreparing = false

        init(banner: BannerView? = nil, controller: UIViewController, table: UITableView?) {
            self.banner = banner
            self.controller = controller
            self.table = table
        }
    }

    private var preparation: Task<Void, Never>?
    private var sdkStartup: Task<Void, Never>?
    private var placements: [Placement] = []
    private var isPresentingPrivacyOptions = false

    var privacyOptionsRequired: Bool {
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    var canDisplayAds: Bool {
        ConsentInformation.shared.canRequestAds && !isPresentingPrivacyOptions
    }

    func didFail(_ banner: BannerView) {
        // A failed placement can retry when its screen next appears.
        placements.first { $0.banner === banner }?.requestedSize = nil
    }

    /// Privacy options remain available for interstitial-only configurations.
    func registerPrivacyOptions(from controller: UIViewController, table: UITableView) {
        guard ConfigurationManager.isBannerAdsEnabled() || ConfigurationManager.isInterstitialAdsEnabled(),
              controller.viewIfLoaded?.window != nil else { return }
        placements.removeAll { $0.controller == nil }
        let placement: Placement
        if let existing = placements.first(where: { $0.controller === controller && $0.table === table }) {
            placement = existing
        } else {
            placement = Placement(controller: controller, table: table)
            placements.append(placement)
        }
        Task { [weak self, weak controller] in
            guard let self, let controller else { return }
            await prepare(from: controller)
            updatePrivacyButton(for: placement)
        }
    }

    func load(_ banner: BannerView, from controller: UIViewController, table: UITableView? = nil) {
        guard ConfigurationManager.isBannerAdsEnabled(),
              controller.viewIfLoaded?.window != nil, !isPresentingPrivacyOptions else { return }
        placements.removeAll { $0.controller == nil }
        let placement: Placement
        if let existing = placements.first(where: { $0.banner === banner }) {
            placement = existing
        } else if let existing = placements.first(where: { $0.controller === controller && $0.table === table }) {
            placement = existing
            placement.banner = banner
            placement.requestedSize = nil
        } else {
            placement = Placement(banner: banner, controller: controller, table: table)
            placements.append(placement)
        }
        guard !placement.isPreparing else { return }
        placement.isPreparing = true

        Task { [weak self, weak controller, weak banner] in
            guard let self, let controller, let banner else { return }
            defer { placement.isPreparing = false }
            await prepare(from: controller)
            updatePrivacyButton(for: placement)
            guard controller.viewIfLoaded?.window != nil,
                  controller.presentedViewController == nil,
                  !isPresentingPrivacyOptions,
                  ConsentInformation.shared.canRequestAds else { return }
            await startSDK()
            guard ConfigurationManager.isBannerAdsEnabled(), canDisplayAds, controller.viewIfLoaded?.window != nil else { return }

            let width = floor((table?.bounds.width ?? controller.view.bounds.width)
                - controller.view.safeAreaInsets.left - controller.view.safeAreaInsets.right)
            guard width > 0 else { return }
            let size = largeAnchoredAdaptiveBanner(width: width)
            guard placement.requestedSize != size.size else { return }
            placement.requestedSize = size.size
            banner.adSize = size
            banner.load(Request())
        }
    }

    func prepareForAds(from controller: UIViewController) async -> Bool {
        guard controller.viewIfLoaded?.window != nil, !isPresentingPrivacyOptions else { return false }
        await prepare(from: controller)
        guard canDisplayAds, controller.presentedViewController == nil,
              controller.viewIfLoaded?.window != nil else { return false }
        await startSDK()
        return canDisplayAds && controller.viewIfLoaded?.window != nil
    }

    private func prepare(from controller: UIViewController) async {
        if let preparation {
            await preparation.value
            return
        }
        let task = Task { @MainActor in
            do {
                try await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
                try await ConsentForm.loadAndPresentIfRequired(from: controller)
            } catch {
                // UMP may still permit ads using a previous session's consent.
                print("AdMob consent: \(error.localizedDescription)")
            }
        }
        preparation = task
        await task.value
    }

    private func startSDK() async {
        if let sdkStartup {
            await sdkStartup.value
            return
        }
        let task = Task { @MainActor in
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                MobileAds.shared.start { _ in continuation.resume() }
            }
        }
        sdkStartup = task
        await task.value
    }

    private func updatePrivacyButton(for placement: Placement) {
        guard let table = placement.table else { return }
        guard privacyOptionsRequired else {
            if table.tableFooterView?.accessibilityIdentifier == "adPrivacyOptions" {
                table.tableFooterView = nil
            }
            return
        }
        guard table.tableFooterView?.accessibilityIdentifier != "adPrivacyOptions" else { return }
        let button = UIButton(type: .system)
        button.setTitle(String(localized: "Ad privacy"), for: .normal)
        button.accessibilityIdentifier = "adPrivacyOptions"
        button.frame = CGRect(x: 0, y: 0, width: table.bounds.width, height: 52)
        button.addAction(UIAction { [weak self, weak controller = placement.controller] _ in
            guard let controller else { return }
            self?.presentPrivacyOptions(from: controller)
        }, for: .touchUpInside)
        table.tableFooterView = button
    }

    func presentPrivacyOptions(from controller: UIViewController) {
        guard privacyOptionsRequired, !isPresentingPrivacyOptions else { return }
        isPresentingPrivacyOptions = true
        ContinueReadingInterstitial.shared.invalidate()
        Task {
            do {
                try await ConsentForm.presentPrivacyOptionsForm(from: controller)
            } catch {
                let alert = UIAlertController(title: String(localized: "Ad privacy"), message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .default))
                controller.present(alert, animated: true)
            }
            // Discard old creatives after a privacy choice and refresh visible placements.
            for placement in placements {
                placement.requestedSize = nil
                updatePrivacyButton(for: placement)
                guard let banner = placement.banner else { continue }
                banner.removeFromSuperview()
                banner.delegate?.bannerView?(banner, didFailToReceiveAdWithError:
                    NSError(domain: "AdMobPrivacyChanged", code: 0))
            }
            isPresentingPrivacyOptions = false
            for placement in placements {
                guard let banner = placement.banner, let owner = placement.controller else { continue }
                load(banner, from: owner, table: placement.table)
            }
        }
    }
}

