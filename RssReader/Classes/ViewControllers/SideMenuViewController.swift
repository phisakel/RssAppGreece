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
        
        // Customize sidebar menu color
//        tableView.backgroundColor = UIColor(red: 39.0/255.0, green: 44.0/255.0, blue: 48.0/255.0, alpha: 1.0)
        
        if ConfigurationManager.defaultTheme().lowercased() == "light" {
            tableView.backgroundColor = UIColor.clear
            tableView.backgroundView = UIImageView(image: UIImage(named: "nav_bg"))
            let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.extraLight)
            let blurEffectView = UIVisualEffectView(effect: blurEffect)
            blurEffectView.frame = view.bounds
            tableView.backgroundView?.addSubview(blurEffectView)
            tableView.separatorColor = UIColor.clear
            
        } else if ConfigurationManager.defaultTheme().lowercased() == "dark" {
            tableView.backgroundColor = UIColor(red: 39.0/255.0, green: 44.0/255.0, blue: 48.0/255.0, alpha: 1.0)
            tableView.separatorColor = UIColor(white: 0.15, alpha: 0.2)
        }
        
//        tableView.separatorColor = UIColor(white: 0.15, alpha: 0.2)
//        tableView.separatorColor = UIColor.clearColor()

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
        
        // Highlight the selected category
        if ConfigurationManager.defaultTheme() == "dark" {
            cell?.imageView?.tintColor = (cell?.textLabel?.text == currentFeed?.title) ? UIColor(red: 0.0/255.0, green: 174.0/255.0, blue: 239.0/255.0, alpha: 1.0) : UIColor(white: 0.8, alpha: 0.9)
            cell?.textLabel?.textColor = (cell?.textLabel?.text == currentFeed?.title) ? UIColor(red: 0.0/255.0, green: 174.0/255.0, blue: 239.0/255.0, alpha: 1.0) : UIColor(white: 0.8, alpha: 0.9)
        } else if ConfigurationManager.defaultTheme() == "light" {
            cell?.imageView?.tintColor = (cell?.textLabel?.text == currentFeed?.title) ? UIColor(red: 166.0/255.0, green: 37.0/255.0, blue: 15.0/255.0, alpha: 1.0) : UIColor.gray
            cell?.textLabel?.textColor = (cell?.textLabel?.text == currentFeed?.title) ? UIColor(red: 166.0/255.0, green: 37.0/255.0, blue: 15.0/255.0, alpha: 1.0) : UIColor.gray
        }

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
        
        if ConfigurationManager.defaultTheme() == "dark" {
            let titleColor = (headerView.titleButton.titleLabel?.text == currentFeed?.title) ? UIColor(red: 0.0/255.0, green: 174.0/255.0, blue: 239.0/255.0, alpha: 1.0) : UIColor(white: 0.8, alpha: 0.9)
            headerView.titleButton.setTitleColor(titleColor, for: UIControl.State())
        } else if ConfigurationManager.defaultTheme() == "light" {
            let titleColor = (headerView.titleButton.titleLabel?.text == currentFeed?.title) ? UIColor(red: 166.0/255.0, green: 37.0/255.0, blue: 15.0/255.0, alpha: 1.0) : UIColor.gray
            headerView.titleButton.setTitleColor(titleColor, for: UIControl.State())
        }
        
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
