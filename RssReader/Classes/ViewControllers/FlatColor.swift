//
//  FlatColor.swift
//  RssReader
//
//  Created by Simon Ng on 29/6/15.
//  Copyright (c) 2015 AppCoda Limited. All rights reserved.
//

import Foundation

enum FlatColor: Int {

    case lightGreen, darkGreen, lightBlue, darkBlue, lightPurple, darkPurple, lightOrange, darkOrange, paleOrange, lightRed, darkRed, brightYellow, paleYellow, silver
    
    func color() -> UIColor {
        switch(self) {
        case .lightGreen: return UIColor(red: 41.0/255.0, green: 128.0/255.0, blue: 185.0/255.0, alpha: 1.0)
        case .darkGreen: return UIColor(red: 142.0/255.0, green: 68.0/255.0, blue: 173.0/255.0, alpha: 1.0)
        case .lightBlue: return UIColor(red: 52.0/255.0, green: 152.0/255.0, blue: 219.0/255.0, alpha: 1.0)
        case .darkBlue: return UIColor(red: 41.0/255.0, green: 128.0/255.0, blue: 185.0/255.0, alpha: 1.0)
        case .lightPurple: return UIColor(red: 155.0/255.0, green: 89.0/255.0, blue: 182.0/255.0, alpha: 1.0)
        case .darkPurple: return UIColor(red: 142.0/255.0, green: 68.0/255.0, blue: 173.0/255.0, alpha: 1.0)
        case .lightRed: return UIColor(red: 231.0/255.0, green: 76.0/255.0, blue: 60.0/255.0, alpha: 1.0)
        case .darkRed: return UIColor(red: 192.0/255.0, green: 57.0/255.0, blue: 43.0/255.0, alpha: 1.0)
        case .lightOrange: return UIColor(red: 243.0/255.0, green: 156.0/255.0, blue: 18.0/255.0, alpha: 1.0)
        case .darkOrange: return UIColor(red: 211.0/255.0, green: 84.0/255.0, blue: 0.0/255.0, alpha: 1.0)
        case .paleOrange: return UIColor(red: 250.0/255.0, green: 117.0/255.0, blue: 30.0/255.0, alpha: 1.0)
        case .brightYellow: return UIColor(red: 248.0/255.0, green: 223.0/255.0, blue: 100.0/255.0, alpha: 1.0)
        case .paleYellow: return UIColor(red: 255.0/255.0, green: 243.0/255.0, blue: 182.0/255.0, alpha: 1.0)
        case .silver: return UIColor(red: 189.0/255.0, green: 195.0/255.0, blue: 199.0/255.0, alpha: 1.0)
        }
    }
}
