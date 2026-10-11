//
//  ArticleDetailViewController.swift
//  RssReader
//
//  Created by Simon Ng on 10/2/2021.
//  Copyright © 2021 AppCoda Limited. All rights reserved.
//

import UIKit
import WebKit
import GoogleMobileAds

class ArticleDetailViewController: UIViewController {

    var article: Article?
    var statusBarHidden = false
    
    @IBOutlet var webView: WKWebView!
    @IBOutlet var loadingIndicator: UIImageView!
    
    lazy var adBannerView: BannerView? = {
        let adBannerView = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: view.bounds.width))
        adBannerView.adUnitID = ConfigurationManager.admobAdUnitId()
        adBannerView.delegate = self
        adBannerView.rootViewController = self
        
        return adBannerView
    }()
    
    fileprivate var hasSetWebViewContentInset = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let article {
            do { try ArticleStore.shared.get().markRead(article) }
            catch { print("Unable to save read state: \(error)") }
        }

        // Set the navigation bar title
        self.title = article?.title
        
        // Initialize custom loading indicator
        loadingIndicator.animationImages = [UIImage]()
        for index in 1..<19 {
            loadingIndicator.animationImages?.append(UIImage(named: "loading-\(index)")!)
        }
        
        loadingIndicator.isHidden = false
        loadingIndicator.alpha = 0.5
        loadingIndicator.animationDuration = 1.0
        loadingIndicator.startAnimating()
        
        // Load the web content
        self.webView.navigationDelegate = self
        self.webView.scrollView.delegate = self
        if var articlelink = article?.link {
            
            // In case the link is missing, we use the GUID instead
            if articlelink == "" {
                if let guid = article?.guid {
                    articlelink = guid
                }
            }
            
            if articlelink.range(of: "redirect.mp4") != nil {
                loadingIndicator.stopAnimating()
                loadingIndicator.isHidden = true
            }
            
            if let webPageURL = URL(string: articlelink) {
                self.webView.load(URLRequest(url: webPageURL))
            }
        }
        
        // Enable iAd (depends on the settings)
        if ConfigurationManager.isDetailViewAdsEnabled() {
            adBannerView?.load(Request())
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        navigationController?.hidesBarsOnSwipe = true
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
    
    // Toggle the status bar
    // - Hide the status bar when the navigation bar is hidden
    // - Show the status bar when the navigation bar is displayed
    func toggleStatusBar() {
        if let navigationBarHidden = navigationController?.isNavigationBarHidden {
            if navigationBarHidden && !UIApplication.shared.isStatusBarHidden {
                UIApplication.shared.setStatusBarHidden(true, with: UIStatusBarAnimation.fade)
            } else if !navigationBarHidden && UIApplication.shared.isStatusBarHidden {
                UIApplication.shared.setStatusBarHidden(false, with: UIStatusBarAnimation.fade)
            }
        }
    }
}


extension ArticleDetailViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        toggleStatusBar()
    }
}

extension ArticleDetailViewController: BannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        print("Banner loaded successfully")
        
        guard let adBannerView = adBannerView else {
            return
        }
        
        webView.addSubview(adBannerView)
        
        // To prevent the banner ad from blocking the content
        // The contentInset should be changed once when the ad banner is first loaded.
        // We don't want to change it again when the ad is reloaded.
        if !hasSetWebViewContentInset {
            webView.scrollView.contentInset = UIEdgeInsets(top: webView.scrollView.contentInset.top, left: webView.scrollView.contentInset.left, bottom: webView.scrollView.contentInset.bottom + adBannerView.bounds.height, right: webView.scrollView.contentInset.right)
            hasSetWebViewContentInset = true
        }
        
        // Auto layout constraints for the ad banner
        // It is placed at the bottom of the screen (or web view)
        adBannerView.translatesAutoresizingMaskIntoConstraints = false
        let bottomSpaceConstraint = NSLayoutConstraint(item: adBannerView, attribute: .bottom, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self.webView, attribute: .bottom, multiplier: 1.0, constant: 0)
        bottomSpaceConstraint.isActive = true
        let leadingSpaceConstraint = NSLayoutConstraint(item: adBannerView, attribute: .leading, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self.webView, attribute: .leading, multiplier: 1.0, constant: 0)
        leadingSpaceConstraint.isActive = true
        let trailingSpaceConstraint = NSLayoutConstraint(item: adBannerView, attribute: .trailing, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self.webView, attribute: .trailing, multiplier: 1.0, constant: 0)
        trailingSpaceConstraint.isActive = true


    }
    
    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        print("Fail to receive ads")
        print(error)
    }

}

extension ArticleDetailViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        // When the web view started to receive content, we stop and hide the loading indicator
        loadingIndicator.stopAnimating()
        loadingIndicator.isHidden = true
    }

}
