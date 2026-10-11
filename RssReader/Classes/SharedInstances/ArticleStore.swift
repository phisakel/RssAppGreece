import Foundation
import SwiftData

/// UIKit and the parser use Article values; only this main-actor store accesses SwiftData.
@MainActor
final class ArticleStore {
    static let shared: Result<ArticleStore, Error> = Result { try ArticleStore() }
    let container: ModelContainer
    private let context: ModelContext

    init(inMemory: Bool = false, storeURL: URL? = nil) throws {
        let schema = Schema([StoredArticle.self, FeedSubscription.self])
        let configuration: ModelConfiguration
        if let storeURL {
            configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        }
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    func subscriptions() throws -> [ValidatedFeed] {
        try context.fetch(FetchDescriptor<FeedSubscription>(sortBy: [SortDescriptor(\.addedAt)]))
            .map { ValidatedFeed(name: $0.name, url: $0.url) }
    }

    func addSubscription(_ feed: ValidatedFeed) throws {
        guard !(try subscriptions()).contains(where: { FeedValidator.identity($0.url) == FeedValidator.identity(feed.url) }) else {
            throw FeedSubscriptionError.duplicate
        }
        context.insert(FeedSubscription(name: feed.name, url: feed.url))
        do { try context.save() }
        catch { context.rollback(); throw error }
    }

    static func key(for article: Article, feedURL: String) -> String {
        let identity = [article.guid, article.link].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
            ?? "\(article.title ?? "")|\(article.publicationDate.timeIntervalSince1970)"
        // Length prefixes avoid collisions when a feed's GUID contains a separator.
        return "\(feedURL.utf8.count):\(feedURL)\(identity.utf8.count):\(identity)"
    }

    @discardableResult
    func save(_ articles: [Article], feedURL: String) throws -> [Article] {
        do {
            let records = try records(for: feedURL)
            var byKey = Dictionary(uniqueKeysWithValues: records.map { ($0.key, $0) })
            records.forEach { $0.isCurrent = false }
            for (position, article) in articles.enumerated() {
                let key = Self.key(for: article, feedURL: feedURL)
                if let existing = byKey[key] {
                    existing.updateContent(from: article, position: position)
                } else {
                    let record = StoredArticle(key: key, feedURL: feedURL, article: article, position: position)
                    context.insert(record)
                    byKey[key] = record
                }
            }
            try context.save()
            return try cachedArticles(feedURL: feedURL)
        } catch {
            context.rollback()
            throw error
        }
    }

    func cachedArticles(feedURL: String) throws -> [Article] {
        try records(for: feedURL).filter(\.isCurrent).sorted { $0.position < $1.position }.map { $0.makeArticle() }
    }

    func markRead(_ article: Article, at date: Date = Date()) throws {
        guard let record = try record(for: article) else { return }
        record.readAt = date
        do { try context.save(); article.readAt = date }
        catch { context.rollback(); throw error }
    }

    func setFavorite(_ favorite: Bool, for article: Article, at date: Date = Date()) throws {
        guard let record = try record(for: article) else { return }
        record.isFavorite = favorite
        record.favoritedAt = favorite ? date : nil
        do {
            try context.save()
            article.isFavorite = favorite
            article.favoritedAt = record.favoritedAt
        } catch { context.rollback(); throw error }
    }

    private func record(for article: Article) throws -> StoredArticle? {
        guard let feedURL = article.feedURL else { return nil }
        let key = Self.key(for: article, feedURL: feedURL)
        return try context.fetch(FetchDescriptor<StoredArticle>(predicate: #Predicate { $0.key == key })).first
    }

    private func records(for feedURL: String) throws -> [StoredArticle] {
        try context.fetch(FetchDescriptor<StoredArticle>(predicate: #Predicate { $0.feedURL == feedURL }))
    }
}
