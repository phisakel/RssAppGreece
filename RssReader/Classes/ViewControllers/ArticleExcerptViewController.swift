//
//  ArticleExcerptViewController.swift
//  RssReader
//
//  Created by Simon Ng on 5/6/15.
//  Copyright (c) 2015 AppCoda Limited. All rights reserved.
//

import UIKit
import GoogleMobileAds

let ARTICLE_EXCERPT_LIMIT = 14896

class ArticleExcerptViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate, UITextViewDelegate, BannerViewDelegate {
    @IBOutlet weak var tableView:UITableView!
    @IBOutlet weak var headerView:ArticleHeaderView!

    var article: Article?
    
    // Header view configuration
    fileprivate var defaultTableHeaderHeight:CGFloat = 250.0
    fileprivate var lastContentOffset:CGFloat = 0.0
    fileprivate let defaultHeaderImageName = "bg-pattern"
  
    // Transition animator for 
    var transitionAnimator:SlideUpTransitionAnimator = SlideUpTransitionAnimator()
    
    fileprivate var tappedLink:String = ""

    // Ad Banner
    lazy var adBannerView: BannerView? = {
        let adBannerView = BannerView()
        adBannerView.adUnitID = ConfigurationManager.admobAdUnitId()
        adBannerView.delegate = self
        adBannerView.rootViewController = self
        
        return adBannerView
    }()

    
    fileprivate var isDragged = false
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadAdBanner()
    }

    private func loadAdBanner() {
        guard ConfigurationManager.isDetailViewAdsEnabled(), let banner = adBannerView else { return }
        AdMobManager.shared.load(banner, from: self, table: tableView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let article {
            do { try ArticleStore.shared.get().markRead(article) }
            catch { print("Unable to save read state: \(error)") }
        }

        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.contentInsetAdjustmentBehavior = .never
        if #available(iOS 26.0, *) {
            tableView.topEdgeEffect.isHidden = true
        }
        
        // Add the header view to the table view background
        defaultTableHeaderHeight = headerView.frame.size.height
        lastContentOffset = -defaultTableHeaderHeight
        
        tableView.tableHeaderView = nil
        tableView.addSubview(headerView)
        tableView.sendSubviewToBack(headerView)
        
        tableView.contentInset = UIEdgeInsets(top: defaultTableHeaderHeight, left: 0, bottom: 0, right: 0)
        tableView.contentOffset = CGPoint(x: 0, y: -defaultTableHeaderHeight)

        
        if let articleImageURL = article?.headerImageURL {
            if articleImageURL != "" {
                // Download the article image
                headerView.imageView.sd_setImage(with: URL(string: articleImageURL), completed: { (image, error, SDImageCacheType, url) -> Void in
                    if image != nil {
                        self.headerView.imageView.image = image
                    } else {
                        
                        self.headerView.imageView.image = UIImage(named: self.defaultHeaderImageName)
                    }
                    
                })
            } else {
                headerView.imageView.image = UIImage(named: defaultHeaderImageName)
            }
        }
        

    }
    
    override func viewDidLayoutSubviews() {
        if adBannerView?.superview != nil { loadAdBanner() }
        super.viewDidLayoutSubviews()
        updateHeaderView()
    }
    
    func updateHeaderView() {
        let headerViewFrame = CGRect(x: 0, y: -defaultTableHeaderHeight, width: tableView.bounds.size.width, height: defaultTableHeaderHeight)
        headerView.frame = headerViewFrame
    }
    
    // MARK: - UIScrollViewDelegate
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // Indicate the user has interacted with the table view
        isDragged = true
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        var headerViewFrame = CGRect(x: 0, y: -defaultTableHeaderHeight, width: tableView.bounds.size.width, height: defaultTableHeaderHeight)
        
        // The ad banner is put in the section header view of the table view.
        // To correctly position the ad banner, we have to change the contentInset property as users scrolls through the table
        if ConfigurationManager.isDetailViewAdsEnabled() {
            if isDragged {
                if -offsetY < defaultTableHeaderHeight && -offsetY > 0 {
                    tableView.contentInset = UIEdgeInsets(top: -offsetY, left: 0, bottom: 0, right: 0)
                } else if offsetY > 0 {
                    // Keep the ad baner
                    tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
                }
            }
        }

        // Keep the view origin to the top and scale the height of the frame
        // to create a stretchy effect
        //        if offsetY < -defaultTableHeaderHeight {
        if offsetY < 0 {
            headerViewFrame.origin.y = offsetY
            headerViewFrame.size.height =  -offsetY
        }
        
        headerView.frame = headerViewFrame
        
        // Hide the status bar when scrolling up
        if offsetY + defaultTableHeaderHeight > 10 {
            UIApplication.shared.setStatusBarHidden(true, with:
                .fade)
        } else {
            UIApplication.shared.setStatusBarHidden(false, with:
                .fade)
        }
  /*
        if -offsetY >= defaultTableHeaderHeight || lastContentOffset > offsetY {
            // Scroll down
            navHeaderView.closeButton.alpha = 0.5
        } else if lastContentOffset < offsetY {
            // Scroll up
            UIView.animateWithDuration(0.2, delay: 0.0, options: nil, animations: {
                self.navHeaderView.closeButton.alpha = 0.0
                }, completion: nil)
        }

        lastContentOffset = offsetY */
        

    }
    
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        
        coordinator.animate(alongsideTransition: { (context) -> Void in
            self.updateHeaderView()
            }, completion: {(context) -> Void in
        })
        
        
    }
    
    
    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // Return the number of sections.
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        return 1
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.section == 0 {
            let headerCell = tableView.dequeueReusableCell(withIdentifier: "HeaderCell", for: indexPath) as! ArticleMetaViewCell
            headerCell.titleLabel.text = article?.title
            if let authorName = article?.authorName {
                headerCell.authorLabel.text = (authorName == "") ? "" : "BY \(authorName)".uppercased()
            }
            
            return headerCell
            
        } else if indexPath.section == 1 {
            let contentCell = tableView.dequeueReusableCell(withIdentifier: "ContentCell", for: indexPath) as! ArticleTextLabelViewCell
            
            contentCell.descriptionTextView.delegate = self
            contentCell.descriptionTextView.attributedText = NSAttributedString(string: "")
            
            var articleDescription:String?
            if article?.content != "" {
                articleDescription = article?.content
            } else {
                articleDescription = article?.rawDescription
            }
            
            // The article description is originally in HTML format. Here we call up
            // the stringByFormattingHTMLString() to generate the attributed string.
            let textDescription = articleDescription?.stringByFormattingHTMLString({ (range, string) -> Void in

                OperationQueue.main.addOperation({

                    // Once the image is downloaded, replace the image with the empty image
                    // generated by default
                    contentCell.descriptionTextView.textStorage.replaceCharacters(in: range, with: string)
                    
                    // Ask the table view cell to update its size
                    let currentSize = contentCell.descriptionTextView.bounds.size
                    let newSize = contentCell.descriptionTextView.sizeThatFits(CGSize(width: currentSize.width, height: CGFloat.greatestFiniteMagnitude))
                    
                    if newSize.height != currentSize.height {
                        self.tableView.beginUpdates()
                        self.tableView.endUpdates()
                    }

                })

            })

            contentCell.descriptionTextView.attributedText = textDescription
            
            return contentCell
        }
        
        return UITableViewCell()
    }
    
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        var cellHeight:CGFloat = 44.0
        
        if indexPath.section == 0 {
            cellHeight = 70.0
            
        } else if indexPath.section == 1 {
            cellHeight = 281.0
        }
        
        return cellHeight
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override var prefersStatusBarHidden : Bool {
        return true
    }


    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "showArticle" {
            let destinationViewController: ArticleDetailViewController
            destinationViewController = segue.destination as! ArticleDetailViewController
            destinationViewController.article = article // selectedArticle

            UIApplication.shared.setStatusBarHidden(true, with: UIStatusBarAnimation.slide)
            destinationViewController.transitioningDelegate = transitionAnimator
            destinationViewController.modalPresentationStyle = .fullScreen
        
        } else if segue.identifier == "showLink" {
            let destinationViewController: ArticleDetailViewController
            destinationViewController = segue.destination as! ArticleDetailViewController
            let articleToDisplay = Article()
            articleToDisplay.link = tappedLink
            destinationViewController.article = articleToDisplay // selectedArticle
            
            UIApplication.shared.setStatusBarHidden(true, with: UIStatusBarAnimation.slide)
            destinationViewController.transitioningDelegate = transitionAnimator
            destinationViewController.modalPresentationStyle = .fullScreen
        }

    }
    
    @IBAction func unwindToExcerptScreen(_ segue: UIStoryboardSegue) {
        if UIApplication.shared.isStatusBarHidden {
            UIApplication.shared.setStatusBarHidden(false, with: UIStatusBarAnimation.slide)
        }
    }
    
    // Action method for activating the share actions
    @IBAction func shareAction(_ sender: UIBarButtonItem) {
        
        var sharingItems = [AnyObject]()
        if let title = article?.title {
            if let link = article?.link {
                sharingItems.append(title as AnyObject)
                sharingItems.append(URL(string: link)! as AnyObject)
            } else {
                sharingItems.append(title as AnyObject)
            }
        }
        
        let activityViewController = UIActivityViewController(activityItems: sharingItems, applicationActivities: [SafariActivity()])
        
        if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad {
            activityViewController.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
        }
        
        self.present(activityViewController, animated: true, completion: nil)
    }

    // MARK: - UITextViewDelegate
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
        
        tappedLink = URL.absoluteString
        performSegue(withIdentifier: "showLink", sender: self)

        return false
    }
    
    
    func textViewDidChange(_ textView: UITextView) {
        let currentSize = textView.bounds.size
        let newSize = textView.sizeThatFits(CGSize(width: currentSize.width, height: CGFloat.greatestFiniteMagnitude))
        
        if newSize.height != currentSize.height {
            tableView.beginUpdates()
            tableView.endUpdates()
        }
    }

    
    // MARK: - Google Admob
    
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        guard AdMobManager.shared.canDisplayAds else { return }
        // Keep the reader's scroll position when an ad refreshes.
        bannerView.frame.size = bannerView.adSize.size
        let container = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: bannerView.bounds.height))
        bannerView.center = CGPoint(x: container.bounds.midX, y: container.bounds.midY)
        bannerView.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin]
        container.addSubview(bannerView)
        tableView.tableHeaderView = container
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        AdMobManager.shared.didFail(bannerView)
        bannerView.removeFromSuperview()
        tableView.tableHeaderView = nil
        print("Fail to receive ads")
        print(error)
    }

}

