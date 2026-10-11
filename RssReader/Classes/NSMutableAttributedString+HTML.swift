//
//  NSMutableAttributedString+HTML.swift
//  RssReader
//
//  Created by Simon Ng on 15/6/15.
//  Copyright (c) 2015 AppCoda Limited. All rights reserved.
//

import Foundation

extension NSMutableAttributedString {
    
    func removeHTMLTags() {
        replaceAllStrings("<[^>]+>", replacement: "")
    }
    
    func replaceAllStrings(_ pattern: String, replacement: String) {
        var range = (self.string as NSString).range(of: pattern, options: .regularExpression)
        while range.location != NSNotFound {
            self.replaceCharacters(in: range, with: replacement)
            range = (self.string as NSString).range(of: pattern, options: .regularExpression)
        }
    }
}
