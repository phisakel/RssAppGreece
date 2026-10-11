//
//  SFMenuItem.swift
//  RssReader
//
//  Created by AppCoda on 23.11.14.
//  Copyright (c) 2014 AppCoda Limited. All rights reserved.
//

import Foundation

class DropdownMenuItem: REMenuItem {
    var url: URL?
    
    override init!(title: String!, image: UIImage!, highlightedImage: UIImage!, action: ((REMenuItem?) -> Void)!) {
        super.init(title: title, image: image, highlightedImage: highlightedImage, action: action)
    }
}
