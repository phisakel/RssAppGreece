//
//  MenuViewController.swift
//  RssReader
//
//  Created by Simon Ng on 4/6/15.
//  Copyright (c) 2015 AppCoda Limited. All rights reserved.
//

import UIKit

protocol MenuViewDelegate {
    func didSelectMenuItem(_ feed:[String: String])
}

class MenuViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, SectionHeaderViewDelegate {
    @IBOutlet weak var tableView:UITableView!
    @IBOutlet weak var headerView:UIView!
    @IBOutlet weak var closeButton: UIButton?
    
    let feedsURLs: [[String: String]] = ConfigurationManager.sharedConfigurationManager().feeds
    var isSectionExpanded:[Bool] = []
    
    var delegate: MenuViewDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.sectionHeaderTopPadding = 0
        
        let menuBackground = UIColor { traits in
            if traits.userInterfaceStyle == .dark { return .systemGroupedBackground }
            return ConfigurationManager.defaultTheme().lowercased() == "dark"
                ? FlatColor.darkOrange.color() : FlatColor.brightYellow.color()
        }
        tableView.backgroundColor = menuBackground
        headerView.backgroundColor = menuBackground
        view.backgroundColor = menuBackground
        closeButton?.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton?.tintColor = .label
        closeButton?.accessibilityLabel = "Close feeds"

        isSectionExpanded = [Bool](repeating: false, count: feedsURLs.count)
        
        // Hide status bar
        UIApplication.shared.setStatusBarHidden(true, with: UIStatusBarAnimation.slide)

        // Register section header view
        tableView.register(UINib(nibName: "SectionHeaderView", bundle: nil), forHeaderFooterViewReuseIdentifier: "SectionHeaderView")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // Return the number of sections.
        return feedsURLs.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        if isSectionExpanded[section] {
            let category = feedsURLs[section]["name"]!
            guard let categoryFeeds = ConfigurationManager.getCategoryFeeds(category) else {
                return 0
            }
            
            return categoryFeeds.count
        }
        
        return 0
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        return max(52, UIFontMetrics(forTextStyle: .headline)
            .scaledFont(for: .systemFont(ofSize: 20, weight: .semibold)).lineHeight + 20)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return max(44, UIFontMetrics(forTextStyle: .body)
            .scaledFont(for: .systemFont(ofSize: 17)).lineHeight + 16)
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeaderView") as! SectionHeaderView
        
        headerView.titleButton.setTitle(feedsURLs[section]["name"], for: UIControl.State())
        headerView.titleButton.titleLabel?.font = UIFontMetrics(forTextStyle: .headline)
            .scaledFont(for: .systemFont(ofSize: 20, weight: .semibold))
        headerView.titleButton.titleLabel?.adjustsFontForContentSizeCategory = true
        headerView.sectionID = section
        headerView.delegate = self
                
        return headerView
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MenuCell", for: indexPath) as! CustomLabelTableViewCell
        cell.label.font = UIFontMetrics(forTextStyle: .body)
            .scaledFont(for: .systemFont(ofSize: 17))
        cell.label.adjustsFontForContentSizeCategory = true
        
        cell.label.textColor = .label
        cell.contentView.backgroundColor = .clear
        cell.backgroundColor = UIColor { traits in
            if traits.userInterfaceStyle == .dark { return .secondarySystemGroupedBackground }
            return ConfigurationManager.defaultTheme().lowercased() == "dark"
                ? FlatColor.paleOrange.color() : FlatColor.paleYellow.color()
        }

        // Get category and display the category feeds
        if let category = feedsURLs[indexPath.section]["name"] {
            let categoryFeeds = ConfigurationManager.getCategoryFeeds(category)
            cell.label.text = categoryFeeds?[indexPath.row]["name"]
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        cell.alpha = 0.0
        cell.transform = CGAffineTransform(translationX: 0, y: 100)
        UIView.animate(withDuration: 0.2, delay: 0.02 * Double(indexPath.row), options: [], animations: {
            cell.transform = CGAffineTransform.identity
            cell.alpha = 1.0
            }, completion: nil)

    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let category = feedsURLs[indexPath.section]["name"] {
            let categoryFeeds = ConfigurationManager.getCategoryFeeds(category)
            let feed = categoryFeeds![indexPath.row]
            didSelectMenuItem(feed)
        }
    }
    
    
    // MARK: - Common methods
    
    func didSelectMenuItem(_ feed:[String: String]) {
        delegate?.didSelectMenuItem(feed)
        UIApplication.shared.setStatusBarHidden(false, with: UIStatusBarAnimation.slide)
        performSegue(withIdentifier: "unwindToMainScreen", sender: self)
    }

    // MARK: - SectionHeaderDelegate Methods
    
    func didSelectSectionHeaderView(_ sectionHeaderView: SectionHeaderView) {
        
        if feedsURLs[sectionHeaderView.sectionID]["url"] == "CategoryFeed" {
            
            // Update the status of the category (expanded / collapsed) and reload the section
            isSectionExpanded[sectionHeaderView.sectionID] = isSectionExpanded[sectionHeaderView.sectionID] ? false : true
            tableView.reloadSections(IndexSet(integer: sectionHeaderView.sectionID), with: UITableView.RowAnimation.none)
            
            return
        }
        
        // For items without sub-menu items, just call didSelectMenuItem to display the feed
        let feed = feedsURLs[sectionHeaderView.sectionID]
        didSelectMenuItem(feed)

    }
    
}

