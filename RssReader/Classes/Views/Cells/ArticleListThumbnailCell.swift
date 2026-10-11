//
//  ArticleListThumbnailCell.swift
//  RssReader
//
//  Created by Simon Ng on 4/6/15.
//  Copyright (c) 2015 AppCoda Limited. All rights reserved.
//

import UIKit

class ArticleListThumbnailCell: UITableViewCell {
    @IBOutlet weak var thumbnailImageView:UIImageView!
    @IBOutlet weak var titleLabel:UILabel!
    @IBOutlet weak var authorLabel:UILabel!
    @IBOutlet weak var thumbnailImageViewConstraintHeight: NSLayoutConstraint!
    @IBOutlet weak var thumbnailImageViewConstraintWidth: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
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
        titleLabel.lineBreakMode = .byWordWrapping
        authorLabel.lineBreakMode = .byWordWrapping

    }
}
