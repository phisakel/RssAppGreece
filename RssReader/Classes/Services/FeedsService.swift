 //
//  FeedsService.swift
//  RssReader
//
//  Created by AppCoda on 11/21/14.
//  Copyright (c) 2014 AppCoda Limited. All rights reserved.
//

import UIKit

// MARK: - RSS and ATOM tags
private let rssChannelTag = "channel"
private let atomChannelTag = "feed"
 
private let rssItemTag = "item"
private let rssTitleTag = "title"
private let rssLinkTag = "link"
private let rssAuthorTag = "dc:creator"
private let rssCategoryTag = "category"
private let rssThumbnailTag = "media:thumbnail"
private let rssMediaContentTag = "media:content"
private let rssCommentsCountTag = "slash:comments"
private let rssPubDateTag = "pubDate"
private let rssDescriptionTag = "description"
private let rssContentTag = "content:encoded"
private let rssEnclosureTag = "enclosure"
private let rssGuidTag = "guid"
 
private let atomItemTag = "entry"
private let atomTitleTag = "title"
private let atomLinkTag = "link"
private let atomAuthorTag = "author"
private let atomAuthorNameTag = "name"
private let atomCategoryTag = "category"
private let atomThumbnailTag = "media:thumbnail"
private let atomMediaContentTag = "media:content"
private let atomCommentsCountTag = "slash:comments"
private let atomPubDateTag = "published"
private let atomContentTag = "content"

// MARK: - Feed Types Enumeration

enum FeedType: String {
    case Unknown = "unknown"
    case Atom = "feed"
    case RSS1 = "rdf:RDF"
    case RSS1Alt = "RDF"
    case RSS2 = "rss"
    
    func feedDateFormat() -> String {
        if self == .Atom {
            return "yyyy-MM-dd'T'HH:mm:ssZ"
        } else if self == .RSS1 || self == .RSS1Alt || self == .RSS2 {
            return "EEE, dd MMM yyyy HH:mm:ss ZZZ"
        }
        
        return ""
    }
}
 
typealias FeedsServiceCompletionClosure = (_ articles: [Article]) -> ()
typealias FeedsServiceFailureClosure = (Error) -> ()

 // MARK: -

@MainActor
class FeedsService: NSObject, @preconcurrency XMLParserDelegate {
    // MARK: - FeedsService properties
    fileprivate var currentElement = ""
    fileprivate var title = ""
    fileprivate var descriptionImageURL = ""
    fileprivate var thumbnailImageURL = ""
    fileprivate var mediaContentImageURL = ""
    fileprivate var enclosureImageURL = ""
    fileprivate var contentImageURL = ""
    
    fileprivate var completion: FeedsServiceCompletionClosure!
    fileprivate var failure: FeedsServiceFailureClosure!
    
    fileprivate var feeds = [Article]()
    fileprivate var feedType:FeedType?
    fileprivate var currentFeed: Article?
    fileprivate var isParsingItem = false
    fileprivate var isParsingAuthor = false
    
    fileprivate var feedsCount = 0
    fileprivate var parser: XMLParser!
    
    fileprivate var commentsCount = ""
    fileprivate var publicationDate = ""

    private let session: URLSession
    private let storeOverride: ArticleStore?

    init(session: URLSession = .shared, store: ArticleStore? = nil) {
        self.session = session
        storeOverride = store
        super.init()
    }

    // MARK: - Helper Methods
    
    func getFeedsWithURL(_ aUrlString: String, completion: FeedsServiceCompletionClosure!, failure: FeedsServiceFailureClosure!) -> Void {

        task?.cancel()
        let requestID = UUID()
        activeRequestID = requestID
        self.completion = completion
        self.failure = failure
        requestedURL = aUrlString
        guard let url = URL(string: aUrlString), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            failure?(URLError(.badURL))
            return
        }
        task = session.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self, self.activeRequestID == requestID else { return }
                if let error {
                    if (error as NSError).code != NSURLErrorCancelled { self.handleFailure(error) }
                    return
                }
                guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode), let data else {
                    self.handleFailure(URLError(.badServerResponse))
                    return
                }
                self.parser = XMLParser(data: data)
                self.parser.delegate = self
                self.parser.shouldResolveExternalEntities = false
                self.parser.parse()
            }
        }
        task?.resume()
    }

    private var activeRequestID: UUID?
    private var task: URLSessionDataTask?
    private var requestedURL = ""

    @MainActor private func handleFailure(_ error: Error) {
        do {
            let cached = try (storeOverride ?? ArticleStore.shared.get()).cachedArticles(feedURL: requestedURL)
            if !cached.isEmpty { completion?(cached); return }
        } catch {
            print("Article cache unavailable: \(error)")
        }
        failure?(error)
    }

        // MARK: - NSXMLParserDelegate Methods
    
    func parserDidStartDocument(_ parser: XMLParser) {
        
        feedsCount = self.feeds.count
        self.feeds = [Article]()
        feedType = nil
        currentFeed = nil
        isParsingItem = false
        isParsingAuthor = false
        commentsCount = ""
        publicationDate = ""
        contentImageURL = ""
        
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        currentElement = elementName
        
        // Determine the feed type
        switch elementName {
            case FeedType.Atom.rawValue:
                self.feedType = .Atom
                return
            
            case FeedType.RSS1.rawValue:
                self.feedType = .RSS1
                return
            
            case FeedType.RSS1Alt.rawValue:
                self.feedType = .RSS1
                return
            
            case FeedType.RSS2.rawValue:
                self.feedType = .RSS2
                return
            
            default:
                break
        }
        
        // Perform parsing based on the feed type
        if self.feedType == .RSS2 || self.feedType == .RSS1 || self.feedType == .RSS1Alt {
            parseRSSStartElement(elementName, attributes: attributeDict)
        } else if self.feedType == .Atom {
            parseAtomStartElement(elementName, attributes: attributeDict)
        }
        
    }
    
    func parseRSSStartElement(_ elementName: String, attributes attributeDict: [AnyHashable: Any]) {
        
        if currentElement == rssItemTag {
            currentFeed = Article()
            commentsCount = ""
            publicationDate = ""
            contentImageURL = ""
            descriptionImageURL = ""
            thumbnailImageURL = ""
            mediaContentImageURL = ""
            enclosureImageURL = ""
        }
        
        if currentElement == rssThumbnailTag {
            if var url = attributeDict["url"] as? String {
                url = url.components(separatedBy: "?")[0]
                currentFeed?.headerImageURL = url
                thumbnailImageURL = url
            }
        }
        
        if currentElement == rssMediaContentTag {
            if var url = attributeDict["url"] as? String {
                url = url.components(separatedBy: "?")[0]
                if mediaContentImageURL == "" || mediaContentImageURL.contains("gravatar.com") {
                    currentFeed?.headerImageURL = url
                    mediaContentImageURL = url
                }
            }
        }
        
        if currentElement == rssEnclosureTag {
            if var url = attributeDict["url"] as? String {
                url = url.components(separatedBy: "?")[0]
                currentFeed?.headerImageURL = url
                enclosureImageURL = url
            } else if let type = attributeDict["type"] as? String {
                if type.contains("video") && type.contains("audio") {
                    var url = attributeDict["url"] as! String
                    url = url.components(separatedBy: "?")[0]
                    currentFeed?.headerImageURL = url
                    enclosureImageURL = url
                }
            }
        }
    }
    
    func parseAtomStartElement(_ elementName: String, attributes attributeDict: [AnyHashable: Any]) {
        
        if currentElement == atomItemTag {
            currentFeed = Article()
            commentsCount = ""
            publicationDate = ""
            contentImageURL = ""
            descriptionImageURL = ""
            thumbnailImageURL = ""
            mediaContentImageURL = ""
            isParsingItem = true
        }
        
        if isParsingItem {
            if currentElement == atomLinkTag {
                if let url = attributeDict["href"] as? String,
                   attributeDict["rel"] as? String != "self",
                   attributeDict["rel"] as? String != "enclosure" {
                    currentFeed?.link = url
                }
            }
            
            if currentElement == atomAuthorTag {
                isParsingAuthor = true
            }
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {

        // Perform parsing based on the feed type
        if self.feedType == .RSS2 || self.feedType == .RSS1 || self.feedType == .RSS1Alt {
            parseRSSEndElement(elementName)
        } else if self.feedType == .Atom {
            parseAtomEndElement(elementName)
        }

    }
    
    func parseRSSEndElement(_ elementName: String) {
        
        if elementName == rssCommentsCountTag {
            commentsCount = commentsCount.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            currentFeed?.commentsCount = Int(commentsCount) ?? 0
            if let count = Int(commentsCount) {
                currentFeed?.commentsCount = count
                commentsCount = ""
            }
        }
        
        if elementName == rssItemTag {
            currentFeed?.title = currentFeed?.title?.convertingHTMLToPlainText().trimmingCharacters(in: .whitespacesAndNewlines)
            currentFeed?.title! += "\n"
            feeds.append(currentFeed!)
            if let headerImageURL = currentFeed?.headerImageURL {
                if headerImageURL == "" {
                    if thumbnailImageURL != "" {
                        currentFeed?.headerImageURL = thumbnailImageURL
                    } else if mediaContentImageURL != "" {
                        currentFeed?.headerImageURL = mediaContentImageURL
                    } else if enclosureImageURL != "" {
                        currentFeed?.headerImageURL = enclosureImageURL
                    } else if descriptionImageURL != "" {
                        currentFeed?.headerImageURL = descriptionImageURL
                    } else if contentImageURL != "" {
                        currentFeed?.headerImageURL = contentImageURL
                    }
                }
            }
        }
        
        if elementName == rssAuthorTag {
            if let _str = currentFeed?.authorName!.convertingHTMLToPlainText() {
                currentFeed?.authorName! = _str
            }
        }
        
        if elementName == rssPubDateTag {
            let pubDate = publicationDate.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = feedType?.feedDateFormat()
            if let pubDate = dateFormatter.date(from: pubDate) {
                currentFeed?.publicationDate = pubDate
                publicationDate = ""
            }
        }
        
        if currentElement == rssDescriptionTag {
            currentFeed?.description = currentFeed?.rawDescription?.stringByDecodingHTMLEscapeCharacters()
            if let headerImageURL = currentFeed?.headerImageURL {
                if !isImage(headerImageURL) {
                    if let html = currentFeed?.rawDescription {
                        currentFeed?.headerImageURL = html.parseFirstImage()
                        descriptionImageURL = html.parseFirstImage() ?? ""
                    }
                }
            }
        }
        
        if currentElement == rssContentTag {
            if let headerImageURL = currentFeed?.headerImageURL {
                if !isImage(headerImageURL) {
                    if let html = currentFeed?.content {
                        currentFeed?.headerImageURL = html.parseFirstImage()
                        contentImageURL = html.parseFirstImage() ?? ""
                    }
                }
            }

        }
        
    }

    func parseAtomEndElement(_ elementName: String) {
        
        if elementName == atomItemTag {
            currentFeed?.title = currentFeed?.title?.convertingHTMLToPlainText().trimmingCharacters(in: .whitespacesAndNewlines)
            currentFeed?.title! += "\n"
            feeds.append(currentFeed!)
            if let headerImageURL = currentFeed?.headerImageURL {
                if headerImageURL == "" {
                    if thumbnailImageURL != "" {
                        currentFeed?.headerImageURL = thumbnailImageURL
                    } else if mediaContentImageURL != "" {
                        currentFeed?.headerImageURL = mediaContentImageURL
                    } else if enclosureImageURL != "" {
                        currentFeed?.headerImageURL = enclosureImageURL
                    } else if descriptionImageURL != "" {
                        currentFeed?.headerImageURL = descriptionImageURL
                    }
                }
            }

            isParsingItem = false
            isParsingAuthor = false
        }

        if isParsingAuthor && elementName == atomAuthorNameTag {
            if let author = currentFeed?.authorName!.convertingHTMLToPlainText() {
                currentFeed?.authorName! = author
            }
        }
        
        if elementName == atomPubDateTag {
            let pubDate = publicationDate.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = feedType?.feedDateFormat()
            if let pubDate = dateFormatter.date(from: pubDate) {
                currentFeed?.publicationDate = pubDate
                publicationDate = ""
            }
        }
        
        if currentElement == atomContentTag {
            if let headerImageURL = currentFeed?.headerImageURL {
                if !isImage(headerImageURL) {
                    if let html = currentFeed?.rawDescription {
                        currentFeed?.headerImageURL = html.parseFirstImage()
                        descriptionImageURL = html.parseFirstImage() ?? ""
                    }
                }
            }
        }
    

    }

    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        
        // Perform parsing based on the feed type
        if self.feedType == .RSS2 || self.feedType == .RSS1 || self.feedType == .RSS1Alt {
            parseRSSFoundCharacters(foundCharacters: string)
        } else if self.feedType == .Atom {
            parseAtomFoundCharacters(foundCharacters: string)
        }

    }
    
    func parseRSSFoundCharacters(foundCharacters string: String?) {
        if let currentString = string {
            switch currentElement {
            case rssTitleTag :
                currentFeed?.title! += currentString
            case rssAuthorTag:
                currentFeed?.authorName! += currentString
            case rssCategoryTag:
                let category = currentString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if category != "" {
                    currentFeed?.categories.append(category)
                }
            case rssLinkTag:
                currentFeed?.link! += currentString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            case rssCommentsCountTag:
                commentsCount += currentString
            case rssPubDateTag:
                publicationDate += currentString
            case rssDescriptionTag:
                currentFeed?.rawDescription! += currentString
            case rssContentTag:
                currentFeed?.content! += currentString
            case rssGuidTag:
                currentFeed?.guid! += currentString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            default:
                break;
                
            }
        }
    }
    
    func parseAtomFoundCharacters(foundCharacters string: String?) {
        
        if !isParsingItem {
            return
        }
        
        if let currentString = string?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) {
            switch currentElement {
                case atomTitleTag :
                    currentFeed?.title! += currentString
                case atomAuthorNameTag:
                    currentFeed?.authorName! += currentString
                case atomCategoryTag:
                    let category = currentString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    if category != "" {
                        currentFeed?.categories.append(category)
                    }
                case atomLinkTag:
                    currentFeed?.link! += currentString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                case atomCommentsCountTag:
                    commentsCount += currentString
                case atomPubDateTag:
                    publicationDate += currentString
                case atomContentTag:
                    currentFeed?.rawDescription! += currentString
                default:
                    break;
            }
        }
        
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let string = String(data: CDATABlock, encoding: .utf8) {
            self.parser(parser, foundCharacters: string)
        }
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        feeds.forEach { $0.feedURL = requestedURL }
        do {
            let saved = try (storeOverride ?? ArticleStore.shared.get()).save(feeds, feedURL: requestedURL)
            completion?(saved)
        } catch {
            // A storage error must not discard an otherwise successful network response.
            print("Unable to save articles: \(error)")
            completion?(feeds)
        }
        
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        handleFailure(parseError)
    }
    
    func isImage(_ imagePath:String) -> Bool {
        if imagePath == "" ||
            imagePath.range(of: ".png", options: .caseInsensitive) == nil ||
            imagePath.range(of: ".jpg", options: .caseInsensitive) == nil ||
            imagePath.range(of: ".jpeg", options: .caseInsensitive) == nil ||
            imagePath.range(of: ".gif", options: .caseInsensitive) == nil {
                
            return false
        }
        
        return true
    }
    
}






