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
    override var prefersStatusBarHidden: Bool { true }
    
    @IBOutlet var webView: WKWebView!
    @IBOutlet var loadingIndicator: UIImageView!
    
    lazy var adBannerView: BannerView? = {
        let adBannerView = BannerView()
        adBannerView.adUnitID = ConfigurationManager.admobAdUnitId()
        adBannerView.delegate = self
        adBannerView.rootViewController = self
        
        return adBannerView
    }()
    
    private var bannerHeight: CGFloat = 0
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if adBannerView?.superview != nil { loadAdBanner() }
    }

    private func loadAdBanner() {
        guard ConfigurationManager.isDetailViewAdsEnabled(), let banner = adBannerView else { return }
        AdMobManager.shared.load(banner, from: self, table: nil)
    }

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
        webView.backgroundColor = .systemBackground
        webView.underPageBackgroundColor = .systemBackground
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.allowsBackForwardNavigationGestures = true
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
        

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadAdBanner()
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
    
}

extension ArticleDetailViewController: BannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        guard ConfigurationManager.isDetailViewAdsEnabled(), AdMobManager.shared.canDisplayAds else { return }
        if bannerView.superview == nil {
            bannerView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(bannerView)
            NSLayoutConstraint.activate([
                bannerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
                bannerView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor)
            ])
        }
        setBannerHeight(bannerView.adSize.size.height)
    }
    
    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        AdMobManager.shared.didFail(bannerView)
        bannerView.removeFromSuperview()
        setBannerHeight(0)
        print("Fail to receive ads")
        print(error)
    }

    private func setBannerHeight(_ height: CGFloat) {
        webView.scrollView.contentInset.bottom += height - bannerHeight
        webView.scrollView.verticalScrollIndicatorInsets.bottom += height - bannerHeight
        bannerHeight = height
    }

}

extension ArticleDetailViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        // When the web view started to receive content, we stop and hide the loading indicator
        loadingIndicator.stopAnimating()
        loadingIndicator.isHidden = true
    }

}
