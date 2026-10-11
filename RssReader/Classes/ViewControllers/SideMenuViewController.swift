//
//  SideMenuViewController.swift
//  RssReader
//
//  Created by AppCoda on 11/24/14.
//  Copyright (c) 2014 AppCoda Limited. All rights reserved.
//

import UIKit

class SideMenuViewController: UITableViewController, SectionHeaderViewDelegate {
    
    @IBOutlet weak var menuTitleLabel:UILabel!
    
    var currentFeed : (title: String, url: String)?
    var oldFeed: (title: String, url: String)?
    
    lazy var detailViewController: FeedsViewController = {
        var navigationFrontVC: UINavigationController?
        if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.phone {
            navigationFrontVC = self.revealViewController().frontViewController as? UINavigationController
        } else {
            navigationFrontVC = self.splitViewController?.viewControllers.last as? UINavigationController;
        }
        let feedsVc = navigationFrontVC?.viewControllers.first as? FeedsViewController
        return feedsVc!
    }()
    
    var feedsURLs: [[String: String]] = ConfigurationManager.sharedConfigurationManager().feeds

    // Indicates whether the submenu is expanded
    var isSectionExpanded:[Bool] = []

    @objc private func reloadFeedMenu() {
        feedsURLs = ConfigurationManager.sharedConfigurationManager().feeds
        isSectionExpanded = [Bool](repeating: false, count: feedsURLs.count)
        tableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadFeedMenu()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(reloadFeedMenu), name: .feedSubscriptionsChanged, object: nil)
        
        tableView.dataSource = self
        
        tableView.backgroundView = nil
        tableView.backgroundColor = .systemBackground
        tableView.separatorColor = .separator
        menuTitleLabel?.textColor = .label

        if menuTitleLabel != nil {
            menuTitleLabel.font = UIFont.systemFont(ofSize: 20.0)
        }
        
        currentFeed = self.detailViewController.currentFeeds
        isSectionExpanded = [Bool](repeating: false, count: feedsURLs.count)
        
        // Register table section header for reuse purpose
        // The main title of menu items is displayed as the section title
        // The subtitle of menu items is displayed as the section rows
        tableView.register(UINib(nibName: "SidebarSectionHeaderView", bundle: nil), forHeaderFooterViewReuseIdentifier: "SidebarSectionHeaderView")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if currentFeed == nil {
            currentFeed = self.detailViewController.currentFeeds
            tableView.reloadData()
        }

        // Hide dropdown menu for iPad (landscape)
        if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad {
            self.detailViewController.navigationHeaderButton.isHidden = true
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad {
            self.detailViewController.navigationHeaderButton.isHidden = false
        }
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return UIStatusBarStyle.default
    }
    
    // MARK: - UITableViewDataSource Methods
    fileprivate let cellReuseIdentifier = "cell"

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let category = feedsURLs[indexPath.section]["name"] {
            let categoryFeeds = ConfigurationManager.getCategoryFeeds(category)
            let feed = categoryFeeds![indexPath.row]
            didSelectMenuItem(feed)
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier)

        // Get category and display the category feeds
        if let category = feedsURLs[indexPath.section]["name"] {
            let categoryFeeds = ConfigurationManager.getCategoryFeeds(category)
            cell?.textLabel?.text = categoryFeeds?[indexPath.row]["name"]
        }

        cell?.textLabel?.font = UIFont.systemFont(ofSize: 16.0)
        cell?.imageView?.image = UIImage(named: "nav_radio")?.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
        
        let color: UIColor = cell?.textLabel?.text == currentFeed?.title ? .systemBlue : .label
        cell?.imageView?.tintColor = color
        cell?.textLabel?.textColor = color

        // Transparent background
        cell?.backgroundColor = UIColor.clear
        
        return cell!
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // Return the number of sections.
        return feedsURLs.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
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
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        return 35.0
    }
    
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SidebarSectionHeaderView") as! SectionHeaderView
        
        headerView.titleButton.titleLabel?.font = UIFont.systemFont(ofSize: 16.0)
        headerView.titleButton.setTitle(feedsURLs[section]["name"], for: UIControl.State())
        headerView.sectionID = section
        headerView.delegate = self
        
        let titleColor: UIColor = headerView.titleButton.titleLabel?.text == currentFeed?.title ? .systemBlue : .label
        headerView.titleButton.setTitleColor(titleColor, for: .normal)

        return headerView
    }

    // MARK: - Common methods
    
    func didSelectMenuItem(_ feed:[String: String]) {
        let currentTitle = feed["name"]
        let currentUrl = feed["url"]
        
        oldFeed = currentFeed
        currentFeed = (title: currentTitle!, url: currentUrl!)
        self.detailViewController.currentFeeds = currentFeed
        
        if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.phone {
            revealViewController().revealToggle(animated: true)
        }
        
        // Reload table data to change the selected item
        tableView.reloadData()
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
