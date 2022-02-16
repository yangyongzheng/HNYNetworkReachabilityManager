//
//  HomePageViewController.swift
//  HNYNetworkReachabilityManager
//
//  Created by Young on 2022/2/15.
//

import UIKit

class HomePageViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    @IBAction func refreshItemDidClick(_ sender: UIBarButtonItem) {
        switch HNYNetworkReachabilityManager.shared().networkReachabilityStatus {
        case .notReachable:
            print("Not Reachable")
        case .reachableViaWWAN:
            print("Reachable via WWAN")
        case .reachableViaWiFi:
            print("Reachable via WiFi")
        default:
            print("Unknown")
        }
    }
}
