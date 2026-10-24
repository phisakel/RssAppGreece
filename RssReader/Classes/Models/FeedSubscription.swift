import Foundation
import SwiftData

@Model
final class FeedSubscription {
    @Attribute(.unique) var url: String
    var name: String
    var addedAt: Date

    init(name: String, url: String, addedAt: Date = Date()) {
        self.name = name
        self.url = url
        self.addedAt = addedAt
    }
}

struct ValidatedFeed: Sendable {
    let name: String
    let url: String
}

enum FeedSubscriptionError: LocalizedError {
    case invalidURL, invalidFeed, duplicate, httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return String(localized: "Enter an HTTP or HTTPS RSS feed URL.")
        case .invalidFeed: return String(localized: "This URL does not contain a valid RSS or Atom feed.")
        case .duplicate: return String(localized: "This feed is already in your menu.")
        case .httpError(let status): return String(localized: "The feed server returned HTTP \(status). Please check the URL.", comment: "Feed validation error; HTTP status code")
        }
    }
}

enum FeedValidator {
    static func normalizedURL(_ input: String) throws -> URL {
        guard var parts = URLComponents(string: input.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = parts.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil else {
            throw FeedSubscriptionError.invalidURL
        }
        parts.scheme = scheme
        parts.host = host.lowercased()
        parts.fragment = nil
        if (scheme == "https" && parts.port == 443) || (scheme == "http" && parts.port == 80) { parts.port = nil }
        guard let url = parts.url else { throw FeedSubscriptionError.invalidURL }
        return url
    }

    static func identity(_ input: String) -> String {
        guard let url = try? normalizedURL(input), var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return input }
        while parts.path.hasSuffix("/") { parts.path.removeLast() }
        return parts.string ?? input
    }

    static func validate(_ input: String, name: String, session: URLSession = .shared) async throws -> ValidatedFeed {
        let url = try normalizedURL(input)
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/rss+xml, application/atom+xml, application/xml, text/xml", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw FeedSubscriptionError.invalidFeed }
        guard (200..<300).contains(http.statusCode) else { throw FeedSubscriptionError.httpError(http.statusCode) }
        let feedTitle = try await Task.detached { try title(in: data) }.value
        try Task.checkCancellation()
        let finalURL = try normalizedURL(response.url?.absoluteString ?? url.absoluteString)
        let customName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return ValidatedFeed(name: customName.isEmpty ? (feedTitle.isEmpty ? finalURL.host! : feedTitle) : customName, url: finalURL.absoluteString)
    }

    static func title(in data: Data) throws -> String {
        guard data.count <= 5_000_000 else { throw FeedSubscriptionError.invalidFeed }
        let delegate = FeedMetadataParser()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse(), delegate.isFeed else { throw FeedSubscriptionError.invalidFeed }
        return delegate.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private final class FeedMetadataParser: NSObject, XMLParserDelegate {
    private var path: [String] = []
    var title = ""
    private var hasChannel = false
    private var root = ""
    var isFeed: Bool { root == "feed" || (["rss", "rdf:RDF", "RDF"].contains(root) && hasChannel) }
    private var isTitle: Bool { path == [root, "channel", "title"] || path == ["feed", "title"] }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        if path.isEmpty { root = elementName }
        path.append(elementName)
        if path == [root, "channel"] { hasChannel = true }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { if isTitle { title += string } }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) { if isTitle { title += String(decoding: CDATABlock, as: UTF8.self) } }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) { path.removeLast() }
}
