//
//  ArticleTextLabelViewCell.swift
//  RssReader
//
//  Created by Simon Ng on 5/6/15.
//  Copyright (c) 2015 AppCoda Limited. All rights reserved.
//

import UIKit

class ArticleTextLabelViewCell: UITableViewCell {
    @IBOutlet weak var descriptionLabel:UILabel!
    @IBOutlet weak var descriptionTextView:UITextView!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        configure()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.contentView.updateConstraintsIfNeeded()
        self.contentView.layoutIfNeeded()
        
    }
    
    func configure() -> Void {
        descriptionTextView.backgroundColor = .clear
        descriptionTextView.textColor = .label
        descriptionTextView.linkTextAttributes = [.foregroundColor: UIColor.link]
    }
}
