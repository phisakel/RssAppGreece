//
//  Article.swift
//  RssReader
//
//  Created by AppCoda on 11/20/14.
//  Copyright (c) 2014 AppCoda Limited. All rights reserved.
//

import Foundation

class Article {
    var feedURL: String?
    var link: String? = ""
    var categories = [String]()
    var headerImageURL: String? = "" {
        didSet {
            headerImageURL = headerImageURL?.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
            headerImageURL = headerImageURL?.removingPercentEncoding ?? headerImageURL
            headerImageURL = headerImageURL?.replacingOccurrences(of: "&amp;", with: "&")
        }
    }
    var commentsCount = 0
    var authorName: String? = ""
    // XMLParser delivers text in chunks; trim only after the item is complete.
    var title: String? = ""
    var isFavorite = false
    var publicationDate = Date()
    var description: String? = ""
    var rawDescription: String? = "" /*{
        didSet {
            description = rawDescription?.stringByDecodingHTMLEscapeCharacters()
        }
    }*/
    var readAt: Date?
    var favoritedAt: Date?
    var content: String? = ""
    var guid: String? = ""
    
    init() {

    }
}
