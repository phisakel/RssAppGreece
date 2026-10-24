//
//  ConfigurationManager.swift
//  RssReader
//
//  Created by Simon Ng on 5/12/14.
//  Copyright (c) 2014 AppCoda Limited. All rights reserved.
//

import UIKit


@MainActor
class ConfigurationManager: NSObject {
    var configuration:AnyObject?
    static let personalFeedsCategory = "Οι ροές μου"
    var feeds: [[String: String]] {
        var feeds = Self.initFeeds()
        if !Self.personalFeeds.isEmpty {
            feeds.append(["name": Self.personalFeedsCategory, "url": "CategoryFeed"])
        }
        return feeds
    }

    /// Translate category headings without changing feed names or lookup keys.
    static func displayName(for feed: [String: String]) -> String {
        let name = feed["name"] ?? ""
        guard feed["url"] == "CategoryFeed" else { return name }
        switch name {
        case "Ειδήσεις": return String(localized: "News")
        case "Οικονομία": return String(localized: "Finance")
        case "Υγεία & Ευεξία": return String(localized: "Health & Wellness")
        case "Γυναίκα": return String(localized: "Woman")
        case "Τεχνολογία": return String(localized: "Technology")
        case "Αθλητικά": return String(localized: "Sports")
        case personalFeedsCategory: return String(localized: "My feeds")
        default: return name
        }
    }

    private static var personalFeeds: [[String: String]] {
        guard let store = try? ArticleStore.shared.get(), let subscriptions = try? store.subscriptions() else { return [] }
        return subscriptions.map { ["name": $0.name, "url": $0.url] }
    }

    static func containsFeed(_ url: String) -> Bool {
        let manager = sharedConfigurationManager()
        let categories = manager.configuration?.object(forKey: "CategoryFeeds") as? [String: [[String: String]]] ?? [:]
        let allFeeds = initFeeds() + categories.values.flatMap { $0 } + personalFeeds
        return allFeeds.contains { FeedValidator.identity($0["url"] ?? "") == FeedValidator.identity(url) }
    }

    override init() {
        super.init()
        
        if let confPath = Bundle.main.path(forResource: "ReaderConf", ofType: "plist") {
            configuration = NSDictionary(contentsOfFile: confPath)
        }
    }
    
    class func sharedConfigurationManager() -> ConfigurationManager {
        return _sharedConfigurationManager
    }
    
    class func initFeeds() -> [[String: String]] {
        return ConfigurationManager.sharedConfigurationManager().configuration?.object(forKey: "Feeds") as! [[String: String]]
        
    }
    
    class func getCategoryFeeds(_ category: String) -> [[String: String]]? {
        
        if category == personalFeedsCategory { return personalFeeds }
        var categoryFeeds:[[String: String]]?
        
        if let categories = ConfigurationManager.sharedConfigurationManager().configuration?.object(forKey: "CategoryFeeds") as? [String: AnyObject]{

            categoryFeeds = categories[category] as? [[String: String]]
        }
        
        return categoryFeeds
    }
    
    class func isBannerAdsEnabled() -> Bool {
        Bundle.main.object(forInfoDictionaryKey: "BannerAdsEnabled") as? Bool ?? false
    }

    class func isDetailViewAdsEnabled() -> Bool {
        isBannerAdsEnabled() && (sharedConfigurationManager().configuration?.object(forKey: "DetailViewAdsEnabled") as? Bool ?? false)
    }

    class func isHomeScreenAdsEnabled() -> Bool {
        return isBannerAdsEnabled() && (sharedConfigurationManager().configuration?.object(forKey: "HomeScreenAdsEnabled") as? Bool ?? false)
    }

    class func isDropdownMenuEnabled() -> Bool {
        return ConfigurationManager.sharedConfigurationManager().configuration?.object(forKey: "DropdownMenu") as! Bool
    }
    
    class func displayMode() -> String {
        return ConfigurationManager.sharedConfigurationManager().configuration?.object(forKey: "DisplayMode") as! String
    }
    
    class func defaultTheme() -> String {
        
        if let defaultTheme = ConfigurationManager.sharedConfigurationManager().configuration?.object(forKey: "Theme") as? String {
            return defaultTheme
        }
        
        return "Dark"
    }
    
    class func isInterstitialAdsEnabled() -> Bool {
        sharedConfigurationManager().configuration?.object(forKey: "InterstitialAdsEnabled") as? Bool ?? false
    }

    class func admobInterstitialAdUnitId() -> String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/4411468910"
        #else
        return sharedConfigurationManager().configuration?.object(forKey: "AdmobInterstitialAdUnitId") as? String ?? ""
        #endif
    }

    class func admobAppId() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String ?? ""
    }
    
    class func admobAdUnitId() -> String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2435281174"
        #else
        return ConfigurationManager.sharedConfigurationManager().configuration?.object(forKey: "AdmobAdUnitId") as? String ?? ""
        #endif
    }

}

@MainActor
let _sharedConfigurationManager: ConfigurationManager = { ConfigurationManager() }()
