//
//  ArticleListViewController.swift
//  RssReader
//
//  Created by Simon Ng on 4/6/15.
//  Copyright (c) 2015 AppCoda Limited. All rights reserved.
//

import UIKit
import SwiftUI
import GoogleMobileAds

class ArticleListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate, MenuViewDelegate, BannerViewDelegate, SceneFeedReader {

    var onCurrentFeedChange: ((SceneFeed?) -> Void)?

    func restoreFeed(_ feed: SceneFeed) {
        guard ConfigurationManager.containsFeed(feed.url) else {
            onCurrentFeedChange?(nil)
            return
        }
        currentFeeds = (title: feed.title, url: feed.url)
    }

    @IBOutlet weak var headerView: ArticleListHeaderView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var navHeaderView: ArticleListNavHeaderView!
    @IBOutlet weak var loadingIndicator: UIImageView!
    @IBOutlet weak var blurringImageView:UIImageView!
    @IBOutlet weak var navHeaderViewHeightConstraint: NSLayoutConstraint!
    
    private var toolbarHost: UIHostingController<FeedToolbar>?
    private var isFeedToolbarHidden = false
    private var lastToolbarScrollOffset: CGFloat?
    private var toolbarScrollDistance: CGFloat = 0
    private var isRestoringFeedPosition = false

    fileprivate var blurEffectView: UIVisualEffectView?
    fileprivate var defaultTableHeaderHeight: CGFloat = 250.0
    fileprivate var defaultNavHeaderOffset: CGFloat = 37.0
    fileprivate var defaultRowHeight: CGFloat = 138.0
    
    fileprivate var transitionAnimator = PopTransitionAnimator()
    
    fileprivate var _currentFeeds: (title: String, url: String)?
    fileprivate let slideUpTransitionAnimator = SlideUpTransitionAnimator()
    
    fileprivate var isRefreshingContent = false
    
    fileprivate var articles: [Article] = []
    
    // Ad Banner
    lazy var adBannerView: BannerView? = {
        let adBannerView = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: view.bounds.width))
        adBannerView.adUnitID = ConfigurationManager.admobAdUnitId()
        adBannerView.delegate = self
        adBannerView.rootViewController = self
        
        return adBannerView
    }()
    
    fileprivate var isDragged = false
    
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
    
    // Feed URLs - Configure via ReaderConf.plist
    var feedsURLs: [[String: String]] = ConfigurationManager.sharedConfigurationManager().feeds
    
    lazy var service: FeedsService? = {
        return FeedsService()
        }()

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize the custom loading indicator
        loadingIndicator.animationImages = [UIImage]()
        for index in 1..<19 {
            loadingIndicator.animationImages?.append(UIImage(named: "loading-\(index)")!)
        }
        
        loadingIndicator.alpha = 0.9
        loadingIndicator.animationDuration = 1.0
        loadingIndicator.tintColor = UIColor.gray
        
        // Initialize blurring image view
        // This image view is used to display a blurring effect while loading the RSS feed
        blurringImageView.image = UIImage(named: "nav_bg")
        let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.extraLight)
        blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView?.frame = view.bounds
        blurringImageView.isHidden = false
        blurringImageView.alpha = 0.9
        blurringImageView.addSubview(blurEffectView!)
        
        // This screen manages its own stretchy header and overlays its toolbar.
        // Automatic safe-area insets would leave space after the toolbar hides.
        tableView.contentInsetAdjustmentBehavior = .never
        if #available(iOS 26, *) {
            tableView.topEdgeEffect.isHidden = true
        }
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = defaultRowHeight
        
        // Add the header view to the table view background
        defaultTableHeaderHeight = headerView.frame.size.height
        headerView.imageView.image = nil
        headerView.titleLabel.text = ""
        headerView.authorLabel.text = ""
        headerView.columnLabel.text = ""
        
        // Gesture to handle stretchy header
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ArticleListViewController.showDetailScreen))
        headerView.titleLabel.addGestureRecognizer(tapGestureRecognizer)
        headerView.titleLabel.isUserInteractionEnabled = true
        
        tableView.tableHeaderView = nil
        tableView.addSubview(headerView)
        tableView.sendSubviewToBack(headerView)
        
        tableView.contentInset = UIEdgeInsets(top: defaultTableHeaderHeight, left: 0, bottom: 0, right: 0)
        tableView.contentOffset = CGPoint(x: 0, y: -defaultTableHeaderHeight)
        
        // Set up navigation header view
        navHeaderView.titleLabel.text = feedsURLs[0]["name"]!
        
        installFeedToolbar()

        // Get the first feed in the list
        currentFeeds = (title: feedsURLs[0]["name"]!, url: feedsURLs[0]["url"]!)

        // Enable Ad (depending on the settings)
        if ConfigurationManager.isHomeScreenAdsEnabled() {
            adBannerView?.load(Request())
        }
      
    }
    
    private func installFeedToolbar() {
        navHeaderView.titleLabel.isHidden = true
        navHeaderView.menuButton.isHidden = true
        navHeaderView.backgroundColor = .systemBackground
        let host = UIHostingController(rootView: makeFeedToolbar(title: feedsURLs[0]["name"] ?? "Feeds"))
        toolbarHost = host
        addChild(host)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        navHeaderView.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: navHeaderView.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: navHeaderView.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: navHeaderView.bottomAnchor),
            host.view.heightAnchor.constraint(equalToConstant: 44)
        ])
        host.didMove(toParent: self)
        view.bringSubviewToFront(navHeaderView)
    }

    private func makeFeedToolbar(title: String) -> FeedToolbar {
        FeedToolbar(title: title, showMenu: { [weak self] in
            self?.performSegue(withIdentifier: "showMenu", sender: self)
        }, addFeed: { [weak self] in
            self?.presentAddFeedSheet { [weak self] feed in
                self?.currentFeeds = (title: feed.name, url: feed.url)
            }
        })
    }

    private func updateFeedToolbar(title: String) {
        toolbarHost?.rootView = makeFeedToolbar(title: title)
    }

    private func setFeedToolbarHidden(_ hidden: Bool, animated: Bool = true) {
        guard #available(iOS 27, *), isFeedToolbarHidden != hidden else { return }
        isFeedToolbarHidden = hidden
        navHeaderView.isUserInteractionEnabled = !hidden
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        let changes = {
            self.navHeaderView.alpha = hidden ? 0 : 1
            self.navHeaderView.transform = hidden && !reduceMotion
                ? CGAffineTransform(translationX: 0, y: -self.navHeaderViewHeightConstraint.constant)
                : .identity
        }
        if animated && !reduceMotion {
            UIView.animate(withDuration: 0.22, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: changes)
        } else {
            changes()
        }
    }

    private func updateFeedToolbarVisibility(for scrollView: UIScrollView) {
        guard #available(iOS 27, *) else { return }
        let top = -scrollView.adjustedContentInset.top
        let bottom = max(top, scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)
        // Clamping keeps the bounce at either edge from reversing the scroll direction.
        let offset = min(max(scrollView.contentOffset.y, top), bottom)
        defer { lastToolbarScrollOffset = offset }
        if offset <= top + 4 {
            toolbarScrollDistance = 0
            setFeedToolbarHidden(false)
            return
        }
        guard !isRestoringFeedPosition, let previous = lastToolbarScrollOffset else { return }
        let delta = offset - previous
        guard abs(delta) > 0.1 else { return }
        if (delta > 0) != (toolbarScrollDistance > 0) { toolbarScrollDistance = 0 }
        toolbarScrollDistance += delta
        if abs(toolbarScrollDistance) >= 18 {
            setFeedToolbarHidden(toolbarScrollDistance > 0)
            toolbarScrollDistance = 0
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // Keep the menu button below the status bar on every device and orientation.
        navHeaderViewHeightConstraint.constant = view.safeAreaInsets.top + 44
        if isFeedToolbarHidden && !UIAccessibility.isReduceMotionEnabled {
            navHeaderView.transform = CGAffineTransform(translationX: 0, y: -navHeaderViewHeightConstraint.constant)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // Return the number of sections.
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        return (articles.count > 0) ? articles.count : 0
    }
 
    /*
    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if !ConfigurationManager.isHomeScreenAdsEnabled() {
            return nil
        }
        
        // The ad banner is only displayed in the first section (i.e. section #0). For the
        // rest of the sections, a nil is returned.
        if section != 0 {
            return nil
        }
        
        return adBannerView
    }
    */
    
    /*
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        // 1. The ad banner is only displayed in the first section (i.e. section #0). For the
        //    rest of the sections, we return a height of zero.
        // 2. If the ad banner can't be loaded (i.e. isAdDisplayed sets to false), we also return
        //    a height of zero.
        if section != 0 || !isAdDisplayed {
            return 0.0
        }
        
        guard let bannerView = adBannerView else {
            return 0.0
        }
        
        return bannerView.frame.size.height
    }
    */
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let article = articles[indexPath.row]
        
        if (indexPath.row + 1) % 4 != 0 {
            let thumbnailCell = tableView.dequeueReusableCell(withIdentifier: "ThumbnailCell", for: indexPath) as! ArticleListThumbnailCell
            
            if indexPath.row == 0 {
                thumbnailCell.isHidden = true
            }
            
            thumbnailCell.titleLabel.text = article.title
            if let authorName = article.authorName {
                thumbnailCell.authorLabel.text = (authorName == "") ? "" : "BY \(authorName)".uppercased()
            }
            
            if let articleImageURL = article.headerImageURL {
                thumbnailCell.thumbnailImageViewConstraintHeight.constant = 110.0
                thumbnailCell.thumbnailImageViewConstraintWidth.constant = 110.0
                
                if articleImageURL != "" {
                    // Download the article image
                    thumbnailCell.thumbnailImageView.sd_setImage(with: URL(string: articleImageURL), completed: { (image, error, SDImageCacheType, url) -> Void in
                        if image != nil {
                            // Load the image with a cross dissolve effect
                            UIView.transition(with: thumbnailCell.thumbnailImageView, duration: 0.3, options: UIView.AnimationOptions.transitionCrossDissolve, animations: {
                                
                                thumbnailCell.thumbnailImageView.image = image
                                }, completion: nil)
                            
                        } else {
                            // Minimize the thumbnail image view if there is no image
                            print("Failed to load \(articleImageURL): \(error?.localizedDescription ?? "")")
                            if thumbnailCell.thumbnailImageViewConstraintHeight != nil {
                                thumbnailCell.thumbnailImageViewConstraintHeight.constant = 0.0
                            }
                            
                            if thumbnailCell.thumbnailImageViewConstraintWidth != nil {
                                thumbnailCell.thumbnailImageViewConstraintWidth.constant = 0.0
                            }
                        }
    
                    })
                } else {
                    // Minimize the thumbnail image view if there is no image
                    thumbnailCell.thumbnailImageView.image = nil
                    if thumbnailCell.thumbnailImageViewConstraintHeight != nil {
                        thumbnailCell.thumbnailImageViewConstraintHeight.constant = 0.0
                    }
                    
                    if thumbnailCell.thumbnailImageViewConstraintWidth != nil {
                        thumbnailCell.thumbnailImageViewConstraintWidth.constant = 0.0
                    }
                    
                }

            }
            
            return thumbnailCell
            
        } else {
            let descriptionCell = tableView.dequeueReusableCell(withIdentifier: "DescriptionCell", for: indexPath) as! ArticleListDescriptionCell
            descriptionCell.titleLabel.text = article.title

            if let authorName = article.authorName {
                descriptionCell.authorLabel.text = (authorName == "") ? "" : "BY \(authorName)".uppercased()
            }
            
            descriptionCell.descriptionLabel.text = article.description?.replacingOccurrences(of: "\n", with: "").trimmingCharacters(in: CharacterSet.whitespaces)
            
            return descriptionCell
        }
    }

    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        showDetailScreen()
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 0 {
            return 0
        } else {
            return UITableView.automaticDimension
        }
    }
    
    // MARK: - Table reload handlers
    func loadTableView(_ url: String!, title: String?) {
        setFeedToolbarHidden(false, animated: false)
        isRestoringFeedPosition = true
        lastToolbarScrollOffset = nil
        toolbarScrollDistance = 0
        
        tableView.contentInset = UIEdgeInsets(top: defaultTableHeaderHeight, left: 0, bottom: 0, right: 0)
        isDragged = false

        blurringImageView.isHidden = false
        blurringImageView.alpha = 0.9
        
        loadingIndicator.isHidden = false
        tableView.isUserInteractionEnabled = false
        loadingIndicator.startAnimating()
        
        self.service?.getFeedsWithURL(url, completion: { [unowned self] (articles) -> () in
            
            // Table rows to delete
            let countOfCurrentArticles = self.articles.count
            var indexPathsToDelete = [IndexPath]()
            if countOfCurrentArticles != 0 {
                for index in 0..<countOfCurrentArticles {
                    indexPathsToDelete.append(IndexPath(row: index, section: 0))
                }
            }
            
            // Table rows to insert
            var indexPathsToInsert = [IndexPath]()
            for row in 0..<articles.count {
                indexPathsToInsert.append(IndexPath(row: row, section: 0))
            }
            
            // Update the table view to display the articles
            self.articles = articles
            self.tableView.beginUpdates()
            self.tableView.deleteRows(at: indexPathsToDelete, with: .none)
            self.tableView.insertRows(at: indexPathsToInsert, with: .none)
            self.tableView.endUpdates()

            // Update the featured article
            self.updateHeaderView()
            
            // Scroll to the top of the table view
            if !articles.isEmpty {
                self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
            }
            
            UIView.transition(with: self.blurringImageView, duration: 0.35, options: UIView.AnimationOptions.transitionCrossDissolve, animations: {
                
                self.blurringImageView.alpha = 0.0
                self.blurringImageView.isHidden = true
            }, completion: nil)

            self.loadingIndicator.stopAnimating()
            self.loadingIndicator.isHidden = true
            self.tableView.isUserInteractionEnabled = true
            self.isRefreshingContent = false
            self.isRestoringFeedPosition = false
            self.lastToolbarScrollOffset = self.tableView.contentOffset.y
            self.toolbarScrollDistance = 0
            
            if let menuTitle = title {
                self.navHeaderView.titleLabel.text = menuTitle
                self.updateFeedToolbar(title: menuTitle)
            }
        
        }) { (error: Error) -> (Void) in
            print("Error: \(error.localizedDescription)", terminator: "")
            
            // Display alert
            let alertController = UIAlertController(title: "Download Error", message: "Failed to retrieve articles from \(title!). Please try again later.", preferredStyle: UIAlertController.Style.alert)
            let okAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.cancel, handler: nil)
            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)
            
            // Hide the loading indicator
            self.loadingIndicator.stopAnimating()
            self.loadingIndicator.isHidden = true
            self.tableView.isUserInteractionEnabled = true
            self.isRefreshingContent = false
            self.isRestoringFeedPosition = false
            self.lastToolbarScrollOffset = self.tableView.contentOffset.y
            self.toolbarScrollDistance = 0
            
            // Hide blurring view
            self.blurringImageView.alpha = 0.0
            self.blurringImageView.isHidden = true

        }
    }
    
    
    override func viewDidLayoutSubviews() {
        updateHeaderView()
    }
    
    func updateHeaderView() {
        let headerViewFrame = CGRect(x: 0, y: -defaultTableHeaderHeight, width: tableView.bounds.size.width, height: defaultTableHeaderHeight)
        headerView.frame = headerViewFrame
        
        // The first article is set as the feature article
        if articles.count > 0 {
            let article = articles[0]
            if let articleImageURL = article.headerImageURL {
                if articleImageURL != "" {
                    // Download the article image
                    headerView.imageView.sd_setImage(with: URL(string: articleImageURL), completed: { (image, error, SDImageCacheType, url) -> Void in
                        if image != nil {
                            self.headerView.imageView.image = image
                        }
                        
                    })
                } else {
                    headerView.imageView.image = nil
                }
                
            }

            headerView.titleLabel.text = article.title
            if let authorName = article.authorName {
                headerView.authorLabel.text = (authorName == "") ? "" : "BY \(authorName)".uppercased()
            }
            headerView.columnLabel.text = (article.categories.count > 0) ? article.categories[0].uppercased() : ""
        } else {
            headerView.imageView.image = nil
            headerView.titleLabel.text = "No articles yet"
            headerView.authorLabel.text = ""
            headerView.columnLabel.text = ""
        }

    }
    
    // MARK: - UIScrollViewDelegate
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateFeedToolbarVisibility(for: scrollView)
        
        // Stretchy header
        var headerViewFrame = CGRect(x: 0, y: -defaultTableHeaderHeight, width: tableView.bounds.size.width, height: defaultTableHeaderHeight)
        
        // Keep the view origin to the top
        if scrollView.contentOffset.y < -defaultTableHeaderHeight {
            headerViewFrame.origin.y = scrollView.contentOffset.y
            headerViewFrame.size.height =  -scrollView.contentOffset.y
        }
        
        headerView.frame = headerViewFrame
        
        navHeaderView.backgroundColor = .systemBackground
        let offsetY = scrollView.contentOffset.y + defaultTableHeaderHeight

        // The ad banner is put in the section header view of the table view.
        // To correctly position the ad banner, we have to change the contentInset property as users scrolls through the table
        if ConfigurationManager.isHomeScreenAdsEnabled() {
            if isDragged {
            let contentOffsetY = scrollView.contentOffset.y
                if -contentOffsetY < defaultTableHeaderHeight && -contentOffsetY > navHeaderView.frame.size.height {
                    tableView.contentInset = UIEdgeInsets(top: -contentOffsetY, left: 0, bottom: 0, right: 0)
                } else if contentOffsetY > 0 {
                    // Keep the ad baner
                    tableView.contentInset = UIEdgeInsets(top: navHeaderView.frame.size.height, left: 0, bottom: 0, right: 0)
                }
            }
        }

        
        // Pull to refresh
        if !isRefreshingContent {
            if -offsetY > 60 {
                blurringImageView.isHidden = false
                blurringImageView.alpha = (-offsetY - 60) / 40
                
            } else {
                blurringImageView.isHidden = true
                blurringImageView.alpha = 0.0

            }
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let offsetY = scrollView.contentOffset.y + defaultTableHeaderHeight
        if -offsetY > 100 {
            isRefreshingContent = true
            loadTableView(currentFeeds?.url, title: currentFeeds?.title)
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // Start a fresh direction threshold for each gesture.
        lastToolbarScrollOffset = scrollView.contentOffset.y
        toolbarScrollDistance = 0
        isDragged = true
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        
        // Update the size of the header image
        coordinator.animate(alongsideTransition: { (context) -> Void in
            self.updateHeaderView()
            }, completion: {(context) -> Void in
        })
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        // Update the bounds of the blur effect view when the orientation change
        blurEffectView?.frame = view.bounds
    }
    
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showMenu" {
            let menuViewController = segue.destination as! MenuViewController
            menuViewController.delegate = self
        } else if segue.identifier == "showDetail" {
            let destinationViewController = segue.destination as! ArticleExcerptViewController
            destinationViewController.transitioningDelegate = transitionAnimator
            destinationViewController.modalPresentationStyle = .fullScreen
            if let indexPath = tableView.indexPathForSelectedRow {
                destinationViewController.article = articles[indexPath.row]
            } else {
                destinationViewController.article = articles[0]
            }
        }
    }
    
    @objc func showDetailScreen() {
        guard !articles.isEmpty else { return }
        self.performSegue(withIdentifier: "showDetail", sender: self)
    }
    
    @IBAction func unwindToMainScreen(_ segue: UIStoryboardSegue) {
        if UIApplication.shared.isStatusBarHidden {
            UIApplication.shared.setStatusBarHidden(false, with: UIStatusBarAnimation.slide)
        }
    }
    
    
    // MARK: - Status bar
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .default
    }

    // MARK: - MenuViewDelegate
    
    func didSelectMenuItem(_ feed:[String: String]) {
        currentFeeds = (title: feed["name"]!, url: feed["url"]!)
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
