import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var currentFeed: SceneFeed?
    private static let lastFeedKey = "reader.lastFeed"
    private static let activityType = "com.appcoda.blogreader3.currentFeed"

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let root = window?.rootViewController, let reader = findReader(root) else { return }
        reader.onCurrentFeedChange = { [weak self, weak scene] feed in
            self?.currentFeed = feed
            UserDefaults.standard.set(feed?.encoded, forKey: Self.lastFeedKey)
            scene?.userActivity = self?.restorationActivity()
        }
        let encoded = session.stateRestorationActivity?.userInfo?["feed"] as? String
            ?? UserDefaults.standard.string(forKey: Self.lastFeedKey) ?? ""
        if let feed = SceneFeed.decode(encoded) {
            currentFeed = feed
            reader.restoreFeed(feed)
        }
    }

    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        restorationActivity()
    }

    private func restorationActivity() -> NSUserActivity? {
        guard let currentFeed else { return nil }
        let activity = NSUserActivity(activityType: Self.activityType)
        activity.title = currentFeed.title
        activity.userInfo = ["feed": currentFeed.encoded]
        return activity
    }

    private func findReader(_ controller: UIViewController) -> (any SceneFeedReader)? {
        controller.loadViewIfNeeded()
        if let reader = controller as? any SceneFeedReader { return reader }
        for child in controller.children {
            if let reader = findReader(child) { return reader }
        }
        return nil
    }
}

/// Lightweight navigation state shared by UIKit scene restoration and launch preferences.
struct SceneFeed: Codable, Equatable {
    let title: String
    let url: String

    var encoded: String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    static func decode(_ value: String) -> SceneFeed? {
        try? JSONDecoder().decode(Self.self, from: Data(value.utf8))
    }
}

@MainActor
protocol SceneFeedReader: AnyObject {
    var onCurrentFeedChange: ((SceneFeed?) -> Void)? { get set }
    func restoreFeed(_ feed: SceneFeed)
}
