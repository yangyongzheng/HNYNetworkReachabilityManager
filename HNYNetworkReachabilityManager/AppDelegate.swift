//
//  AppDelegate.swift
//  HNYNetworkReachabilityManager
//
//  Created by Young on 2022/2/15.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions
                     launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        HNYNetworkReachabilityManager.shared().startMonitoring()
        return true
    }

}

