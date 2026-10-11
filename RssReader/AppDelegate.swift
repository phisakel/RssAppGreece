//
//  AppDelegate.swift
//  RssReader
//
//  Created by AppCoda on 11/20/14.
//  Copyright (c) 2014 AppCoda Limited. All rights reserved.
//

import UIKit
import GoogleMobileAds

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, shouldSaveSecureApplicationState coder: NSCoder) -> Bool {
        true
    }

    func application(_ application: UIApplication, shouldRestoreSecureApplicationState coder: NSCoder) -> Bool {
        true
    }

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        do {
            let storyboardName = UIDevice.current.userInterfaceIdiom == .pad ? "Main_iPad" : "Main_iPhone-3"
            
            // Change navigation bar appearance
            if storyboardName == "Main_iPhone" || storyboardName == "Main_iPhone-2" || storyboardName == "Main_iPad" {
                if ConfigurationManager.defaultTheme() == "dark" {
                    UINavigationBar.appearance().barTintColor = UIColor(red: 0.0/255.0, green: 174.0/255.0, blue: 239.0/255.0, alpha: 1.0)
                    UINavigationBar.appearance().tintColor = UIColor.white
                    
                    // Change status bar style
                    UIApplication.shared.statusBarStyle = .lightContent
                    
                    // Default bar font
                    let barFont = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
                    UINavigationBar.appearance().titleTextAttributes = [NSAttributedString.Key.foregroundColor:UIColor.white, NSAttributedString.Key.font:barFont]
                    
                    
                } else if ConfigurationManager.defaultTheme() == "light" {
                    UINavigationBar.appearance().barTintColor = UIColor(red: 255.0/255.0, green: 255.0/255.0, blue: 255.0/255.0, alpha: 1.0)
                    UINavigationBar.appearance().tintColor = UIColor(red: 166.0/255.0, green: 37.0/255.0, blue: 15.0/255.0, alpha: 1.0)

                    //            UINavigationBar.appearance().tintColor = UIColor(red: 25.0/255.0, green: 150.0/255.0, blue: 93.0/255.0, alpha: 1.0)
                    
                    // Change status bar style
                    UIApplication.shared.statusBarStyle = .default
                    
                    let barFont = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
                    UINavigationBar.appearance().titleTextAttributes = [NSAttributedString.Key.foregroundColor:UIColor(red: 166.0/255.0, green: 37.0/255.0, blue: 15.0/255.0, alpha: 1.0), NSAttributedString.Key.font:barFont]
                    
                }
                
            }
        }
        
        // Setup AdMob
        if ConfigurationManager.isHomeScreenAdsEnabled() || ConfigurationManager.isDetailViewAdsEnabled() {
            
            MobileAds.shared.start(completionHandler: nil)
        }
        
        // To fix the background color issue of the menu table view
        if #available(iOS 14.0, *) {
            var bgConfig = UIBackgroundConfiguration.listPlainCell()
            bgConfig.backgroundColor = UIColor.clear
            UITableViewHeaderFooterView.appearance().backgroundConfiguration = bgConfig
        }
        
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        let key = UIDevice.current.userInterfaceIdiom == .pad ? "UIMainStoryboardFile~ipad" : "UIMainStoryboardFile"
        let storyboardName = Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "Main_iPhone-3"
        configuration.storyboard = UIStoryboard(name: storyboardName, bundle: nil)
        return configuration
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

