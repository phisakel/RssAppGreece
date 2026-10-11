//
//  FeedsViewController.swift
//  RssReader
//
//  Created by AppCoda on 11/20/14.
//  Copyright (c) 2014 AppCoda Limited. All rights reserved.
//

import UIKit
import GoogleMobileAds

class FeedsViewController: UITableViewController, BannerViewDelegate, SceneFeedReader {
    var onCurrentFeedChange: ((SceneFeed?) -> Void)?

    func restoreFeed(_ feed: SceneFeed) {
        guard ConfigurationManager.containsFeed(feed.url) else {
            onCurrentFeedChange?(nil)
            return
        }
        currentFeeds = (title: feed.title, url: feed.url)
    }

    @IBOutlet var navigationHeaderButton: UIButton!
    var navigationHeaderLabel:UILabel?
    
    fileprivate var _currentFeeds: (title: String, url: String)?
    fileprivate let slideUpTransitionAnimator = SlideUpTransitionAnimator()
    
    var currentFeeds: (title: String, url: String)? {
        set (newValue){
            _currentFeeds = newValue
            onCurrentFeedChange?(newValue.map { SceneFeed(title: $0.title, url: $0.url) })
            loadTableView(_currentFeeds?.url, title: _currentFeeds?.title)
        }
        get {
            return _currentFeeds
        }
    }
    
    // Data source for UITableView
    lazy var dataSource: ArticleDataSource? = {
        return ArticleDataSource(configureCellClosure: { (articleCell, article, indexPath) -> () in
           
            // Display article title
            articleCell.titleLabel.text = article.title

            if let authorName = article.authorName {
                articleCell.authorLabel.text = (authorName == "") ? "" : "BY \(authorName)".uppercased()
            }
            
            articleCell.categoryLabel.text = article.categories.first?.uppercased()
            
            // Display article date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM dd HH:mm"
            articleCell.dateTimeLabel.text = dateFormatter.string(from: article.publicationDate as Date)
            
            // If the comment count is zero, hide the comment label
            if article.commentsCount != 0 {
                if articleCell.commentsCountLabel != nil {
                    articleCell.commentsCountLabel.text = String(article.commentsCount)
                }
            } else {
                if articleCell.commentsCountLabel != nil {
                    articleCell.commentsCountLabel.isHidden = true
                    articleCell.commentsLabel.isHidden = true
                }
            }
            
            // Article Description (Supported by Main_iPhone-2.storyboard and Main_iPad.storyboard
            if articleCell.descriptionLabel != nil {
                articleCell.descriptionLabel.text = article.description
            }

            // Load article image
            if let articleImageURL = article.headerImageURL {
                if articleImageURL != "" {
                    if self.storyboard!.value(forKey: "name")! as! String == "Main_iPhone" {
                        if articleCell.imageViewConstraintHeight != nil {
                            articleCell.imageViewConstraintHeight.constant = 252.0
                        }
                        self.tableView.estimatedRowHeight = 357.0
                        
                    } else if self.storyboard!.value(forKey: "name")! as! String == "Main_iPhone-2" {
                        if ConfigurationManager.displayMode() == "Image" {
                            articleCell.imageViewConstraintHeight.constant = 171.0
                            articleCell.imageViewConstraintWidth.constant = 120.0
                        } else if ConfigurationManager.displayMode() == "Text" {
                            articleCell.imageViewConstraintHeight.constant = 0.0
                            articleCell.imageViewConstraintWidth.constant = 0.0
                        } else if ConfigurationManager.displayMode() == "Text+Image" {

                            let isText = (indexPath.row % 2 == 0) ? true : false
                            if isText {
                                articleCell.imageViewConstraintHeight.constant = 0.0
                                articleCell.imageViewConstraintWidth.constant = 0.0
                            } else {
                                articleCell.imageViewConstraintHeight.constant = 220.0
                                articleCell.imageViewConstraintWidth.constant = 120.0
                            }
                            
                        }
                        self.tableView.estimatedRowHeight = 171.0
                        
                    } else if self.storyboard!.value(forKey: "name")! as! String == "Main_iPad" {
                        if articleCell.imageViewConstraintHeight != nil {
                            articleCell.imageViewConstraintHeight.constant = 420.0
                            self.tableView.estimatedRowHeight = 582.0
                        }
                    }

                    // Download the article image
                    if self.storyboard!.value(forKey: "name")! as! String == "Main_iPhone" ||
                        (self.storyboard!.value(forKey: "name")! as! String == "Main_iPhone-2" && ConfigurationManager.displayMode() != "Text") || self.storyboard!.value(forKey: "name")! as! String == "Main_iPad" {
                
                        
                        articleCell.headerImageView.sd_setImage(with: URL(string: articleImageURL)!) { (image, error, cacheType, url) -> Void in
                            
                            // Sometimes, the default image is too small to display.
                            // In this case, we will hide the thumbnail
                            guard let image = image, image.size.width >= 10 else {
                                if articleCell.imageViewConstraintHeight != nil {
                                    articleCell.imageViewConstraintHeight.constant = 0.0
                                }
                                
                                if articleCell.imageViewConstraintWidth != nil {
                                    articleCell.imageViewConstraintWidth.constant = 0.0
                                }
                                
                                return
                            }
                            
                            articleCell.headerImageView.image = image
                            
//                            if image == nil || image.size.width < 10 {
//                                if articleCell.imageViewConstraintHeight != nil {
//                                    articleCell.imageViewConstraintHeight.constant = 0.0
//                                }
//                                
//                                if articleCell.imageViewConstraintWidth != nil {
//                                    articleCell.imageViewConstraintWidth.constant = 0.0
//                                }
//                                
//                            } else {
//                                articleCell.headerImageView.image = image
//                            }
                        }
                    }
                } else {
                    // In case there is no image, we decrease the width/height constraint to zero
                    articleCell.headerImageView.image = nil
                    if articleCell.imageViewConstraintHeight != nil {
                        articleCell.imageViewConstraintHeight.constant = 0.0
                    }
                    
                    if articleCell.imageViewConstraintWidth != nil {
                        articleCell.imageViewConstraintWidth.constant = 0.0
                    }
                    
                    self.tableView.estimatedRowHeight = 130.0
                }
            } else {
                articleCell.headerImageView.image = nil
            }
        })
    }()
    
    // Dropdown Menu Configuration
    lazy var navigationMenu: REMenu = {
        var dropdownMenu = REMenu()
        dropdownMenu.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        dropdownMenu.separatorColor = UIColor.clear
        dropdownMenu.highlightedBackgroundColor = UIColor.black
        dropdownMenu.highlightedSeparatorColor = UIColor.white
        dropdownMenu.borderColor = UIColor.clear
        dropdownMenu.textColor = UIColor.white
        dropdownMenu.highlightedTextColor = UIColor.white
        dropdownMenu.font = UIFont.systemFont(ofSize: 17.0)
        dropdownMenu.separatorHeight = 0

        // Uncomment if you want to use live blur
        /*
        dropdownMenu.liveBlur = true
        dropdownMenu.liveBlurTintColor = UIColor.blackColor()
        */
        
        return dropdownMenu
    }()
    
    // Feed URLs - Configure via ReaderConf.plist
    var feedsURLs: [[String: String]] = ConfigurationManager.sharedConfigurationManager().feeds
    
    lazy var feedsMenuItems: [DropdownMenuItem] = {
        var feedsItems = [DropdownMenuItem]()
        
        for feed in self.feedsURLs {
            let title = feed["name"]
            let url = feed["url"]
            
            var item = DropdownMenuItem(title: title, image: UIImage(), highlightedImage: UIImage(), action: { [unowned self] (item: REMenuItem!) -> Void in
                let _item = item as! DropdownMenuItem
                let urlPath = _item.url?.relativePath
                self.currentFeeds = (title: item.title, url: urlPath!)
            })
            item?.url = URL(fileURLWithPath: url!)
            feedsItems.append(item!);
        }

        return feedsItems
    }()
    
    lazy var service: FeedsService? = {
        return FeedsService()
    }()
    
    lazy var adBannerView: BannerView? = {
        let adBannerView = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: view.bounds.width))
        adBannerView.adUnitID = ConfigurationManager.admobAdUnitId()
        adBannerView.delegate = self
        adBannerView.rootViewController = self

        return adBannerView
    }()
    
    
    // MARK: - ViewController overrides
    override func viewDidLoad() {
        super.viewDidLoad();
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .add, primaryAction: UIAction { [weak self] _ in
            self?.presentAddFeedSheet { [weak self] feed in
                self?.currentFeeds = (title: feed.name, url: feed.url)
            }
        })
        navigationItem.rightBarButtonItem?.accessibilityLabel = "Add RSS Feed"
        
        // Get the first feed in the list
        currentFeeds = (title: feedsURLs[0]["name"]!, url: feedsURLs[0]["url"]!)
        
        // Configure title label/dropdown menu depending on your settings
        if ConfigurationManager.isDropdownMenuEnabled() {
            navigationItem.titleView = navigationHeaderButton;
            navigationHeaderButton.titleLabel?.font = UIFont.systemFont(ofSize: 17.0)
            switch ConfigurationManager.defaultTheme() {
                case "dark":
                    navigationHeaderButton.tintColor = UIColor.white
                case "light":
                    navigationHeaderButton.tintColor = UIColor(red: 166.0/255.0, green: 37.0/255.0, blue: 15.0/255.0, alpha: 1.0)
                default: break
            }
            
        } else {
            navigationHeaderLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
            navigationHeaderLabel?.text = feedsURLs[0]["name"]!
            navigationHeaderLabel?.textAlignment = .center
            navigationHeaderLabel?.font = UIFont.systemFont(ofSize: 17.0)
            switch ConfigurationManager.defaultTheme() {
                case "dark":
                    navigationHeaderLabel?.textColor = UIColor.white
                case "light":
                    navigationHeaderLabel?.textColor = UIColor(red: 166.0/255.0, green: 37.0/255.0, blue: 15.0/255.0, alpha: 1.0)
                default: break
            }
            
            navigationItem.titleView = navigationHeaderLabel
        }
        
        // Configure the slide-out menu
        if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.phone {
            revealViewController().draggableBorderWidth = view.frame.width
            revealViewController().rearViewRevealWidth = view.frame.width * 0.7
            navigationController?.navigationBar.addGestureRecognizer(revealViewController().panGestureRecognizer())
            view.addGestureRecognizer(revealViewController().panGestureRecognizer())
            view.addGestureRecognizer(revealViewController().tapGestureRecognizer())
        }
        
        // Pull-to-refresh
        refreshControl = UIRefreshControl()
        switch ConfigurationManager.defaultTheme() {
            case "dark":
                refreshControl?.backgroundColor = UIColor(red: 0.0/255.0, green: 174.0/255.0, blue: 239.0/255.0, alpha: 1.0)
                refreshControl?.tintColor = UIColor.white
            case "light":
                refreshControl?.backgroundColor = UIColor(red: 166.0/255.0, green: 37.0/255.0, blue: 15.0/255.0, alpha: 1.0)
                refreshControl?.tintColor = UIColor.white
            default:
                break
        }
        
        refreshControl?.addTarget(self, action: #selector(FeedsViewController.refreshTableView), for: UIControl.Event.valueChanged)
        
        // Add dropdown menu to navigation bar
        navigationHeaderButton?.setTitle(feedsURLs[0]["name"]! + " ▾", for: UIControl.State());
        navigationMenu.items = feedsMenuItems
        navigationHeaderButton?.isHidden = !ConfigurationManager.isDropdownMenuEnabled()

        // Define table view delegate
        tableView.dataSource = self.dataSource
        
        // Enable Ad (depending on the settings)
        if ConfigurationManager.isHomeScreenAdsEnabled() {
            print("Google Mobile Ads SDK version: \(MobileAds.shared.versionNumber)")
        }

        // Enable self sizing cells
        self.tableView.rowHeight = UITableView.automaticDimension

    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.hidesBarsOnSwipe = false
        navigationController?.setNavigationBarHidden(false, animated: true)
    }

    // MARK: - Button handlers
    @IBAction func navigationHeaderButtonDidPressed(_ sender: UIButton) {
        if !navigationMenu.isOpen {
            navigationMenu.show(from: self.navigationController);
        } else {
            navigationMenu.close()
        }
    }
    
    @IBAction func sideMenuButtonDidpressed(_ sender: UIBarButtonItem) {
        if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.phone {
            revealViewController().revealToggle(animated: true)
        }
    }
    
    // MARK: - Table reload handlers
    func loadTableView(_ url: String!, title: String?) {
        self.service?.getFeedsWithURL(url, completion: { [unowned self] (articles) -> () in
            // Table rows to delete
            let countOfCurrentArticles = self.dataSource?.articles.count
            var indexPathsToDelete = [IndexPath]()
            for _index in 0..<countOfCurrentArticles! {
                indexPathsToDelete.append(IndexPath(row: _index, section: 0))
            }

            // Table rows to insert
            var indexPathsToInsert = [IndexPath]()
            for row in 0..<articles.count {
                indexPathsToInsert.append(IndexPath(row: row, section: 0))
            }
            
            // Update the table view to display the articles
            self.dataSource?.articles = articles
            self.tableView.beginUpdates()
            self.tableView.deleteRows(at: indexPathsToDelete, with: .none)
            self.tableView.insertRows(at: indexPathsToInsert, with: .none)
            self.tableView.endUpdates()

            // Scroll to the top of the table view
            if !articles.isEmpty {
                self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
            }
            
            
            // Hide refreshing control
            if let isRefreshing = self.refreshControl?.isRefreshing {
                if isRefreshing {
                    OperationQueue.main.addOperation({
                        self.refreshControl?.endRefreshing()
                    })
                }
            }
            
            // let headerButton = self.navigationHeaderButton!
            if let menuTitle = title {
                self.navigationHeaderButton?.setTitle(menuTitle + " ▾", for: UIControl.State())
                self.navigationHeaderLabel?.text = menuTitle
            }
            
            // Enable banner ad
            if ConfigurationManager.isHomeScreenAdsEnabled() {
                self.adBannerView?.load(Request())
                print("Request ad banner")
                print("Ad unit ID: \(self.adBannerView?.adUnitID ?? "")")
            }

        }) { (error: Error) -> (Void) in
            print("Error: \(error.localizedDescription)", terminator: "")
            
            // Display alert
            let alertController = UIAlertController(title: "Download Error", message: "Failed to retrieve articles from \(title!). Please try again later.", preferredStyle: UIAlertController.Style.alert)
            let okAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.cancel, handler: nil)
            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)

            // Hide refreshing control
            if let isRefreshing = self.refreshControl?.isRefreshing {
                if isRefreshing {
                    OperationQueue.main.addOperation({
                        self.refreshControl?.endRefreshing()
                    })
                }
            }
        }
        
    }
    
    // Action method when the user triggers a refresh
    func refreshStatusDidChange() {
        refreshTableView()
    }
    
    // Reload the table data from the selected feed
    @objc func refreshTableView() {
        // Update last-update date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, h:mm a"
        let currentDateTime = dateFormatter.string(from: Date())
        refreshControl?.attributedTitle = NSAttributedString(string: "Last Updated: \(currentDateTime)", attributes: [NSAttributedString.Key.foregroundColor: UIColor.white])
        
        loadTableView(currentFeeds?.url, title: currentFeeds?.title)
    }

    // MARK: - Segues
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            if let indexPath = tableView.indexPathForSelectedRow {
                let destinationViewController: ArticleDetailViewController
                destinationViewController = segue.destination as! ArticleDetailViewController
                destinationViewController.article = dataSource?[indexPath.row] // selectedArticle
                
                // Use custom transition animator for Main_iPhone-2.storyboard
                if self.storyboard!.value(forKey: "name")! as! String == "Main_iPhone-2" {
                    UIApplication.shared.setStatusBarHidden(true, with: UIStatusBarAnimation.slide)
                    destinationViewController.transitioningDelegate = slideUpTransitionAnimator
                    destinationViewController.modalPresentationStyle = .fullScreen
                }
            }
        }

    }
    
    @IBAction func unwindToFeedScreen(_ segue: UIStoryboardSegue) {
        if UIApplication.shared.isStatusBarHidden {
            UIApplication.shared.setStatusBarHidden(false, with: UIStatusBarAnimation.slide)
        }
    }
    
    // MARK: - Google Admob
    
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        print("Banner loaded successfully")

        // Reset the content offset
        tableView.contentOffset = CGPoint(x: 0, y: -tableView.contentInset.top)

        // Reposition the banner ad to create a slide down effect
        let translateTransform = CGAffineTransform(translationX: 0, y: -bannerView.bounds.size.height)
        bannerView.transform = translateTransform
        
        UIView.animate(withDuration: 0.5, animations: {
            self.tableView.tableHeaderView?.frame = bannerView.frame
            bannerView.transform = CGAffineTransform.identity
            self.tableView.tableHeaderView = bannerView
        }) 

    }
    
    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        print("Fail to receive ads")
        print(error)
    }
}
