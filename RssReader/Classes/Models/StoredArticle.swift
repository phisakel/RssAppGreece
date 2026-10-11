import Foundation
import SwiftData

@Model
final class StoredArticle {
    @Attribute(.unique) var key: String
    var feedURL: String
    var position: Int
    var isCurrent: Bool
    var link: String?
    var guid: String?
    var title: String?
    var categories: [String]
    var headerImageURL: String?
    var commentsCount: Int
    var authorName: String?
    var publicationDate: Date
    var summary: String?
    var rawDescription: String?
    var content: String?
    var isFavorite: Bool
    var readAt: Date?
    var favoritedAt: Date?

    init(key: String, feedURL: String, article: Article, position: Int) {
        self.key = key
        self.feedURL = feedURL
        self.position = position
        isCurrent = true
        link = article.link
        guid = article.guid
        title = article.title
        categories = article.categories
        headerImageURL = article.headerImageURL
        commentsCount = article.commentsCount
        authorName = article.authorName
        publicationDate = article.publicationDate
        summary = article.description
        rawDescription = article.rawDescription
        content = article.content
        isFavorite = article.isFavorite
        readAt = article.readAt
        favoritedAt = article.favoritedAt
    }

    func updateContent(from article: Article, position: Int) {
        self.position = position
        isCurrent = true
        link = article.link
        guid = article.guid
        title = article.title
        categories = article.categories
        headerImageURL = article.headerImageURL
        commentsCount = article.commentsCount
        authorName = article.authorName
        publicationDate = article.publicationDate
        summary = article.description
        rawDescription = article.rawDescription
        content = article.content
        // A feed refresh must preserve the reader's local state.
    }

    func makeArticle() -> Article {
        let article = Article()
        article.feedURL = feedURL
        article.link = link
        article.guid = guid
        article.title = title
        article.categories = categories
        article.headerImageURL = headerImageURL
        article.commentsCount = commentsCount
        article.authorName = authorName
        article.publicationDate = publicationDate
        article.description = summary
        article.rawDescription = rawDescription
        article.content = content
        article.isFavorite = isFavorite
        article.readAt = readAt
        article.favoritedAt = favoritedAt
        return article
    }
}
