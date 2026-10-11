//
//  SafariActivity.swift
//  RssReader
//
//  Created by Simon Ng on 5/5/15.
//  Copyright (c) 2015 AppCoda Limited. All rights reserved.
//

import UIKit

class SafariActivity: UIActivity {
    fileprivate var url:URL?
   
//    override var activityType: UIActivityType? {
//        return "SafariActivity"
//    }
    
    override var activityTitle : String? {
        return "Open in Safari"
    }
    
    override var activityImage : UIImage? {
        let safariImage = UIImage(named: "safari-7")
        return safariImage
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        for activityItem in activityItems {
            if let activityItem = activityItem as? URL, UIApplication.shared.canOpenURL(activityItem) {
                return true
            }
        }
        
        return false
    }
    
    override func prepare(withActivityItems activityItems: [Any]) {
        for activityItem in activityItems {
            if let activityItem = activityItem as? URL {
                url = activityItem
            }
        }
    }
    
    override func perform() {
        let completed = UIApplication.shared.openURL(url!)
        activityDidFinish(completed)
    }
}
