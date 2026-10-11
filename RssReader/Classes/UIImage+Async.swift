//
//  UIImage+Async.swift
//  RssReader
//
//  Created by Simon Ng on 16/6/15.
//  Copyright (c) 2015 AppCoda Limited. All rights reserved.
//

import UIKit

extension UIImage {
    
    func asyncGetImage(_ url: URL, completionHandler: @escaping ((_ data: Data?, _ error: NSError?) -> Void)) {
        URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) -> Void in
            
            if let error = error {
                completionHandler(data, error as NSError)
            }
        }).resume()
    }
}
