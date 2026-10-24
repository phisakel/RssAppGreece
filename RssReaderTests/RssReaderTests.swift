import XCTest
import UIKit
import SwiftData
@testable import RssReader

@MainActor
final class RssReaderTests: XCTestCase {
    private let feedURL = "https://example.com/feed"

    private func withContinueReadingDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "ContinueReadingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    func testContinueReadingFrequencySurvivesRecreationAndTriggersEveryFifthTap() {
        withContinueReadingDefaults { defaults in
            let first = ContinueReadingAdFrequency(defaults: defaults)
            for _ in 1...3 { XCTAssertFalse(first.registerTap()) }
            let recreated = ContinueReadingAdFrequency(defaults: defaults)
            XCTAssertFalse(recreated.registerTap())
            XCTAssertTrue(recreated.registerTap())
            for _ in 1...4 { XCTAssertFalse(recreated.registerTap()) }
            XCTAssertTrue(recreated.registerTap())
        }
    }

    func testContinueReadingWaitsForAdOnlyOnFifthTapAndIgnoresRepeatedTaps() {
        withContinueReadingDefaults { defaults in
            let flow = ContinueReadingAdFlow(frequency: ContinueReadingAdFrequency(defaults: defaults))
            var opened = 0
            var presentations = 0
            var dismissAd: (() -> Void)?
            let presentAd: (@escaping () -> Void) -> Bool = { completion in
                presentations += 1
                dismissAd = completion
                return true
            }
            for _ in 1...4 {
                flow.continueReading(presentAd: presentAd) { opened += 1 }
            }
            XCTAssertEqual(opened, 4)
            XCTAssertEqual(presentations, 0)
            flow.continueReading(presentAd: presentAd) { opened += 1 }
            XCTAssertEqual(presentations, 1)
            XCTAssertEqual(opened, 4)
            flow.continueReading(presentAd: presentAd) { opened += 1 }
            XCTAssertEqual(presentations, 1)
            dismissAd?()
            dismissAd?()
            XCTAssertEqual(opened, 5)
            // The rapid duplicate tap was not counted toward the next ad.
            for _ in 1...4 {
                flow.continueReading(presentAd: presentAd) { opened += 1 }
            }
            XCTAssertEqual(presentations, 1)
            XCTAssertEqual(opened, 9)
        }
    }

    func testContinueReadingUnavailableAdOpensImmediatelyWithoutDeferringAd() {
        withContinueReadingDefaults { defaults in
            let flow = ContinueReadingAdFlow(frequency: ContinueReadingAdFrequency(defaults: defaults))
            var opened = 0
            var attempts = 0
            for _ in 1...9 {
                flow.continueReading(presentAd: { _ in attempts += 1; return false }) { opened += 1 }
            }
            XCTAssertEqual(opened, 9)
            XCTAssertEqual(attempts, 1)
            flow.continueReading(presentAd: { completion in
                attempts += 1
                // A presentation failure uses the same completion as dismissal.
                completion()
                return true
            }) { opened += 1 }
            XCTAssertEqual(attempts, 2)
            XCTAssertEqual(opened, 10)
        }
    }

    func testOldAdCallbackCannotFinishANewerReadingRequest() {
        withContinueReadingDefaults { defaults in
            let flow = ContinueReadingAdFlow(frequency: ContinueReadingAdFrequency(defaults: defaults))
            var opened = 0
            var completions: [() -> Void] = []
            let presentAd: (@escaping () -> Void) -> Bool = { completions.append($0); return true }
            for _ in 1...5 { flow.continueReading(presentAd: presentAd) { opened += 1 } }
            completions[0]()
            for _ in 1...5 { flow.continueReading(presentAd: presentAd) { opened += 1 } }
            XCTAssertEqual(opened, 9)
            completions[0]()
            XCTAssertEqual(opened, 9)
            completions[1]()
            XCTAssertEqual(opened, 10)
        }
    }

    func testInterstitialUsesGoogleTestUnitInDebugBuilds() {
        #if DEBUG
        XCTAssertEqual(ConfigurationManager.admobInterstitialAdUnitId(), "ca-app-pub-3940256099942544/4411468910")
        #endif
    }

    func testEnglishAndGreekResourcesAreBundledAndComplete() throws {
        let appBundle = Bundle(for: ConfigurationManager.self)
        XCTAssertTrue(appBundle.localizations.contains("en"))
        XCTAssertTrue(appBundle.localizations.contains("el"))
        for table in ["Localizable", "Main_iPhone", "Main_iPhone-2", "Main_iPhone-3", "Main_iPad"] {
            var tables: [[String: String]] = []
            for language in ["en", "el"] {
                let url = try XCTUnwrap(appBundle.url(forResource: table, withExtension: "strings", subdirectory: nil, localization: language))
                let data = try Data(contentsOf: url)
                let values = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
                XCTAssertFalse(values.isEmpty, "Missing translations in \(language)/\(table)")
                XCTAssertFalse(values.values.contains(where: { $0.isEmpty }))
                tables.append(values)
            }
            XCTAssertEqual(Set(tables[0].keys), Set(tables[1].keys), "Translation coverage differs in \(table)")
        }
    }

    func testLocalizedReadingButtonAndInterpolatedMessages() throws {
        let appBundle = Bundle(for: ConfigurationManager.self)
        let author = "Μαρία Smith"
        let status = 404
        for (language, reading, byline, http) in [
            ("en", "Continue reading", "By Μαρία Smith", "The feed server returned HTTP 404. Please check the URL."),
            ("el", "Συνεχίστε την ανάγνωση", "Από Μαρία Smith", "Ο διακομιστής της ροής επέστρεψε HTTP 404. Ελέγξτε τη διεύθυνση.")
        ] {
            let path = try XCTUnwrap(appBundle.path(forResource: language, ofType: "lproj"))
            let bundle = try XCTUnwrap(Bundle(path: path))
            XCTAssertEqual(bundle.localizedString(forKey: "cfl-qW-6Xw.normalTitle", value: nil, table: "Main_iPhone-3"), reading)
            XCTAssertEqual(String(localized: "By \(author)", bundle: bundle), byline)
            XCTAssertEqual(String(localized: "The feed server returned HTTP \(status). Please check the URL.", bundle: bundle), http)
        }
    }

    func testLocalizedCategoriesPreserveFeedIdentityAndPublisherNames() {
        let category = ["name": "Ειδήσεις", "url": "CategoryFeed"]
        XCTAssertEqual(ConfigurationManager.displayName(for: category), String(localized: "News"))
        XCTAssertNotNil(ConfigurationManager.getCategoryFeeds(category["name"]!))
        let publisher = ["name": "Ειδήσεις", "url": "https://example.com/feed"]
        XCTAssertEqual(ConfigurationManager.displayName(for: publisher), publisher["name"])
        XCTAssertEqual(category["name"], "Ειδήσεις")
    }

    func testSceneFeedRoundTripAndInvalidState() throws {
        let feed = SceneFeed(title: "Καθημερινή", url: "https://www.kathimerini.gr/infeeds/rss/nx-rss-feed.xml")
        XCTAssertEqual(SceneFeed.decode(feed.encoded), feed)
        XCTAssertNil(SceneFeed.decode(""))
        XCTAssertNil(SceneFeed.decode("invalid"))
    }

    private func article(_ guid: String, title: String = "Original") -> Article {
        let article = Article()
        article.guid = guid
        article.title = title
        article.link = "https://example.com/\(guid)"
        article.publicationDate = Date(timeIntervalSince1970: 1_700_000_000)
        article.categories = ["News", "Ελλάδα"]
        article.content = "<p>Content</p>"
        return article
    }

    func testRefreshUpdatesContentWithoutLosingReaderState() throws {
        let store = try ArticleStore(inMemory: true)
        let first = try XCTUnwrap(store.save([article("one")], feedURL: feedURL).first)
        let date = Date(timeIntervalSince1970: 123)
        try store.markRead(first, at: date)
        try store.setFavorite(true, for: first, at: date)
        let refreshed = try store.save([article("one", title: "Updated")], feedURL: feedURL)
        XCTAssertEqual(refreshed.count, 1)
        XCTAssertEqual(refreshed.first?.title, "Updated")
        XCTAssertEqual(refreshed.first?.readAt, date)
        XCTAssertEqual(refreshed.first?.favoritedAt, date)
        XCTAssertEqual(refreshed.first?.isFavorite, true)
        try store.setFavorite(false, for: refreshed[0])
        XCTAssertNil(try store.cachedArticles(feedURL: feedURL).first?.favoritedAt)
    }

    func testCacheContainsLatestSnapshotInFeedOrderAndIsolatesFeeds() throws {
        let store = try ArticleStore(inMemory: true)
        try store.save([article("one"), article("two")], feedURL: feedURL)
        try store.save([article("one", title: "Other feed")], feedURL: "https://other.com/feed")
        try store.save([article("two"), article("three")], feedURL: feedURL)
        XCTAssertEqual(try store.cachedArticles(feedURL: feedURL).compactMap(\.guid), ["two", "three"])
        XCTAssertEqual(try store.cachedArticles(feedURL: "https://other.com/feed").first?.title, "Other feed")
        try store.save([], feedURL: feedURL)
        XCTAssertTrue(try store.cachedArticles(feedURL: feedURL).isEmpty)
    }

    func testDuplicateGUIDsDoNotCreateDuplicateRecords() throws {
        let store = try ArticleStore(inMemory: true)
        let saved = try store.save([article("one"), article("one", title: "Latest")], feedURL: feedURL)
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.title, "Latest")
    }

    func testArticlesWithoutGUIDUseLinkForStableIdentity() throws {
        let store = try ArticleStore(inMemory: true)
        let first = article("")
        first.guid = nil
        let saved = try store.save([first], feedURL: feedURL)
        try store.setFavorite(true, for: saved[0])
        let update = article("", title: "Updated")
        update.guid = nil
        XCTAssertEqual(try store.save([update], feedURL: feedURL).first?.isFavorite, true)
    }

    func testDiskStoreSurvivesReopening() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("articles.store")
        do {
            let store = try ArticleStore(storeURL: url)
            let saved = try store.save([article("one")], feedURL: feedURL)
            try store.markRead(saved[0], at: Date(timeIntervalSince1970: 123))
        }
        let reopened = try ArticleStore(storeURL: url)
        let cached = try XCTUnwrap(reopened.cachedArticles(feedURL: feedURL).first)
        XCTAssertEqual(cached.guid, "one")
        XCTAssertEqual(cached.categories, ["News", "Ελλάδα"])
        XCTAssertEqual(cached.content, "<p>Content</p>")
        XCTAssertEqual(cached.readAt, Date(timeIntervalSince1970: 123))
    }

    func testNetworkFeedIsParsedAndSavedIncludingCDATA() async throws {
        let store = try ArticleStore(inMemory: true)
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        FeedURLProtocol.responseData = Data("""
        <rss version="2.0"><channel><item><guid>one</guid><title>Ελλάδα &amp; News</title>
        <link>https://example.com/one</link><pubDate>Tue, 14 Nov 2023 22:13:20 +0000</pubDate>
        <description><![CDATA[<p>Summary without an image</p>]]></description>
        </item></channel></rss>
        """.utf8)
        FeedURLProtocol.responseError = nil
        let service = FeedsService(session: session, store: store)
        let done = expectation(description: "Feed loaded")
        service.getFeedsWithURL(feedURL, completion: { articles in
            XCTAssertEqual(articles.count, 1)
            XCTAssertEqual(articles.first?.title?.trimmingCharacters(in: .whitespacesAndNewlines), "Ελλάδα & News")
            XCTAssertTrue(articles.first?.description?.contains("Summary") == true)
            done.fulfill()
        }, failure: { error in XCTFail(error.localizedDescription); done.fulfill() })
        await fulfillment(of: [done], timeout: 5)
        XCTAssertEqual(try store.cachedArticles(feedURL: feedURL).first?.guid, "one")
    }

    func testOfflineRequestReturnsPersistedFeed() async throws {
        let store = try ArticleStore(inMemory: true)
        try store.save([article("one")], feedURL: feedURL)
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        FeedURLProtocol.responseError = URLError(.notConnectedToInternet)
        let service = FeedsService(session: session, store: store)
        let done = expectation(description: "Cached feed loaded")
        service.getFeedsWithURL(feedURL, completion: { articles in
            XCTAssertEqual(articles.first?.guid, "one")
            done.fulfill()
        }, failure: { error in XCTFail(error.localizedDescription); done.fulfill() })
        await fulfillment(of: [done], timeout: 5)
    }

    func testOfflineRequestWithoutCacheReportsFailure() async throws {
        let store = try ArticleStore(inMemory: true)
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        FeedURLProtocol.responseError = URLError(.notConnectedToInternet)
        let service = FeedsService(session: session, store: store)
        let done = expectation(description: "Failure reported")
        service.getFeedsWithURL(feedURL, completion: { _ in XCTFail("Unexpected cache hit"); done.fulfill() }, failure: { error in
            XCTAssertEqual((error as NSError).code, NSURLErrorNotConnectedToInternet)
            done.fulfill()
        })
        await fulfillment(of: [done], timeout: 5)
    }

    func testMenuSectionButtonReceivesTapsAtItsVisibleCenter() throws {
        let objects = UINib(nibName: "SectionHeaderView", bundle: Bundle(for: SectionHeaderView.self))
            .instantiate(withOwner: nil)
        let header = try XCTUnwrap(objects.first as? SectionHeaderView)
        header.frame = CGRect(x: 0, y: 0, width: 440, height: 70)
        header.layoutIfNeeded()
        let center = header.titleButton.convert(CGPoint(x: header.titleButton.bounds.midX, y: header.titleButton.bounds.midY), to: header)
        XCTAssertTrue(header.hitTest(center, with: nil) === header.titleButton)
    }

    func testImageExtractionToleratesMissingSourcesAndMalformedTags() {
        XCTAssertEqual("Ελλάδα 📰 <img alt='No source'>".parseFirstImage(), "")
        XCTAssertEqual("<img src=".parseFirstImage(), "")
        XCTAssertEqual("<img data-src='https://example.com/lazy.jpg'>".parseFirstImage(), "")
        XCTAssertEqual("<img alt='No source'><img src='https://example.com/valid.jpg'>".parseFirstImage(), "https://example.com/valid.jpg")
    }

    func testImageExtractionSupportsUnicodeQuotesAndFeaturedImages() {
        XCTAssertEqual("📰 <img SRC = '//example.com/εικόνα.jpg?a=1&amp;b=2'>".parseFirstImage(), "https://example.com/εικόνα.jpg?a=1&b=2")
        XCTAssertEqual("<img src='https://example.com/first.jpg'><figure><img src=https://example.com/featured.jpg></figure>".parseFirstImage(), "https://example.com/featured.jpg")
    }

    func testFeedURLValidationAndDuplicateIdentity() throws {
        XCTAssertEqual(try FeedValidator.normalizedURL(" HTTPS://EXAMPLE.COM:443/feed/#story ").absoluteString, "https://example.com/feed/")
        XCTAssertEqual(FeedValidator.identity("https://example.com/feed/"), FeedValidator.identity("https://EXAMPLE.com:443/feed#article"))
        for invalid in ["", "not a URL", "file:///tmp/feed.xml", "https://user:password@example.com/feed"] {
            XCTAssertThrowsError(try FeedValidator.normalizedURL(invalid))
        }
        XCTAssertTrue(ConfigurationManager.containsFeed("https://www.ertnews.gr/feed"))
    }

    func testFeedMetadataAcceptsRSSAndAtomButRejectsWebPagesAndMalformedXML() throws {
        XCTAssertEqual(try FeedValidator.title(in: Data("<rss><channel><title><![CDATA[Ελληνικά & News]]></title><item><title>Article</title></item></channel></rss>".utf8)), "Ελληνικά & News")
        XCTAssertEqual(try FeedValidator.title(in: Data("<feed xmlns='http://www.w3.org/2005/Atom'><title>Atom News</title><entry><title>Article</title></entry></feed>".utf8)), "Atom News")
        for invalid in ["<html><title>Website</title></html>", "<rss><broken>", "<rss><title>Not a channel</title></rss>"] {
            XCTAssertThrowsError(try FeedValidator.title(in: Data(invalid.utf8)))
        }
    }

    func testValidationFetchesFeedAndUsesCustomNameOrChannelTitle() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        FeedURLProtocol.responseError = nil
        FeedURLProtocol.responseData = Data("<rss><channel><title>Channel Name</title></channel></rss>".utf8)
        let automatic = try await FeedValidator.validate(feedURL, name: " ", session: session)
        XCTAssertEqual(automatic.name, "Channel Name")
        let custom = try await FeedValidator.validate(feedURL, name: " My Feed ", session: session)
        XCTAssertEqual(custom.name, "My Feed")
        XCTAssertEqual(custom.url, feedURL)
        FeedURLProtocol.responseData = Data("<html><title>Not RSS</title></html>".utf8)
        do {
            _ = try await FeedValidator.validate(feedURL, name: "", session: session)
            XCTFail("Expected invalid feed error")
        } catch { XCTAssertTrue(error is FeedSubscriptionError) }
    }

    func testCustomFeedPersistsAcrossStoreRecreationAndRejectsDuplicates() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("reader.store")
        do {
            let store = try ArticleStore(storeURL: url)
            try store.addSubscription(ValidatedFeed(name: "My Greek Feed", url: feedURL))
            XCTAssertThrowsError(try store.addSubscription(ValidatedFeed(name: "Duplicate", url: feedURL + "/")))
        }
        let reopened = try ArticleStore(storeURL: url)
        let feeds = try reopened.subscriptions()
        XCTAssertEqual(feeds.count, 1)
        XCTAssertEqual(feeds.first?.name, "My Greek Feed")
        XCTAssertEqual(feeds.first?.url, feedURL)
    }

    func testAddingSubscriptionSchemaPreservesExistingArticleDatabase() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("reader.store")
        do {
            let schema = Schema([StoredArticle.self])
            let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            let original = article("legacy")
            let record = StoredArticle(key: ArticleStore.key(for: original, feedURL: feedURL), feedURL: feedURL, article: original, position: 0)
            record.isFavorite = true
            context.insert(record)
            try context.save()
        }
        let upgraded = try ArticleStore(storeURL: url)
        let cached = try upgraded.cachedArticles(feedURL: feedURL)
        XCTAssertEqual(cached.first?.guid, "legacy")
        XCTAssertEqual(cached.first?.isFavorite, true)
        try upgraded.addSubscription(ValidatedFeed(name: "My feed", url: feedURL))
        XCTAssertEqual(try upgraded.subscriptions().count, 1)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FeedURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class FeedURLProtocol: URLProtocol {
    static var responseData = Data()
    static var responseError: Error?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if let error = Self.responseError {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Self.responseData)
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}
}
