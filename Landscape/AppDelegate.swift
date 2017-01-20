//
//  AppDelegate.swift
//  Landscape
//
//  Created by KO on 2017/01/04.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?

  func applicationDidEnterBackground(_ application: UIApplication) {
    let n = Notification(name: Notification.Name(rawValue: "applicationDidEnterBackground"),
                         object: self)
    NotificationCenter.default.post(n)
  }

  func applicationWillEnterForeground(_ application: UIApplication) {
    let n = Notification(name: Notification.Name(rawValue: "applicationWillEnterForeground"),
                         object: self)
    NotificationCenter.default.post(n)
  }
}

