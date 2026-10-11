//
//  SectionHeaderView.swift
//  RssReader
//
//  Created by Simon Ng on 29/10/2015.
//  Copyright © 2015 AppCoda Limited. All rights reserved.
//

import UIKit

protocol SectionHeaderViewDelegate {
    func didSelectSectionHeaderView(_ cell:SectionHeaderView)
}

class SectionHeaderView: UITableViewHeaderFooterView {

    @IBOutlet var titleButton:UIButton!
    
    var delegate:SectionHeaderViewDelegate?
    var sectionID:Int = 0
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // UITableViewHeaderFooterView installs its own content view. Controls
        // loaded as direct nib subviews can end up behind that view and miss taps.
        titleButton.removeFromSuperview()
        contentView.addSubview(titleButton)
        titleButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            titleButton.topAnchor.constraint(equalTo: contentView.topAnchor),
            titleButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

    }
    
    @IBAction func titleButtonTapped(_ sender: UIButton) {
        delegate?.didSelectSectionHeaderView(self)
    }
    
}
