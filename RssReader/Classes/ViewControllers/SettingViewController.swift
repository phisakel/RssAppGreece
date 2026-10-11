//
//  SettingViewController.swift
//  RssReader
//
//  Created by Simon Ng on 5/12/14.
//  Copyright (c) 2014 AppCoda Limited. All rights reserved.
//

import UIKit
import MessageUI

class SettingViewController: UITableViewController, MFMailComposeViewControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func sendUsFeedback() {
        if MFMailComposeViewController.canSendMail() {
            let composer = MFMailComposeViewController()
            
            composer.mailComposeDelegate = self

            // Uncomment if you need to set a default email
            // composer.setToRecipients(["<your email>"])
            //composer.navigationBar.tintColor = UIColor.whiteColor()
            
            present(composer, animated: true, completion: {
                switch ConfigurationManager.defaultTheme() {
                    case "dark":
                        UIApplication.shared.setStatusBarStyle(.lightContent, animated: false)
                    case "light":
                        UIApplication.shared.setStatusBarStyle(.default, animated: false)
                    default:
                        break
                }
                
            })
        }
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        
        switch result {
        case MFMailComposeResult.cancelled:
            print("Mail cancelled")
            
        case MFMailComposeResult.saved:
            print("Mail saved")
            
        case MFMailComposeResult.sent:
            print("Mail sent")
            
        case MFMailComposeResult.failed:
            print("Failed to send mail: \(error!.localizedDescription)")
        }
        
        // Dismiss the Mail interface
        dismiss(animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 75.0
    }
    
    @IBAction func dismissController() {
        // Dismiss the current interface
        dismiss(animated: true, completion: nil)

    }
    
    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (indexPath.row == 0) {
            sendUsFeedback()
        }
    }
    

}
