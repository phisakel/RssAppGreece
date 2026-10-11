//
//  ArticleViewCell.swift
//  RssReader
//
//  Created by AppCoda on 11/20/14.
//  Copyright (c) 2014 AppCoda Limited. All rights reserved.
//

import UIKit

class ArticleViewCell: UITableViewCell {
    
    
    @IBOutlet var headerImageView: UIImageView!
    @IBOutlet var categoryLabel: UILabel!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var authorLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var commentsCountLabel: UILabel!
    @IBOutlet weak var commentsLabel: UILabel!
    @IBOutlet weak var dateTimeLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var imageViewConstraintHeight: NSLayoutConstraint!
    @IBOutlet weak var imageViewConstraintWidth: NSLayoutConstraint!
    
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.contentView.updateConstraintsIfNeeded()
        self.contentView.layoutIfNeeded()
        
    }
    
    override func awakeFromNib() {
        configure()
    }
    
    func configure() -> Void {
        titleLabel.font = .systemFont(ofSize: 20)
        authorLabel.font = .systemFont(ofSize: 12)
        categoryLabel.font = .systemFont(ofSize: 12)
        dateTimeLabel.font = .systemFont(ofSize: 12)
        descriptionLabel?.font = .systemFont(ofSize: 14)

    }
    
}
