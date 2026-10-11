//
//  ArticleListNavHeader.swift
//  RssReader
//
//  Created by Simon Ng on 4/6/15.
//  Copyright (c) 2015 AppCoda Limited. All rights reserved.
//

import UIKit

class ArticleListNavHeaderView: UIView {
    @IBOutlet weak var titleLabel:UILabel!
    @IBOutlet weak var menuButton:UIButton!

    /*
    // Only override drawRect: if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func drawRect(rect: CGRect) {
        // Drawing code
    }
    */


    override func awakeFromNib() {
        configure()
    }
    
    func configure() -> Void {
    }
}
