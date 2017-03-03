//
//  LocationManager.swift
//  Landscape
//
//  Created by KO on 2017/01/25.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit
import CoreLocation

class LocationManager: NSObject, CLLocationManagerDelegate {
  // 位置情報サービスの許可状態
  var authorizationStatus = CLLocationManager.authorizationStatus()
  
  // 位置情報サービスが動作可能かどうか
  let supportsLocation = CLLocationManager.headingAvailable() &&
    CLLocationManager.locationServicesEnabled()
  
  // 位置情報サービス
  private let lm = CLLocationManager()
  
  private let distanceFilter = 100.0
  
  private let headingFilter = 2.0
  
  private let timeTolerance = 60.0
  
  // 画面描画オブジェクト
  private var renderer: SceneRenderer
  
  //
  var prevLocation = CLLocationCoordinate2D()
  
  init(renderer: SceneRenderer) {
    self.renderer = renderer
    super.init()

    if supportsLocation {
      
      lm.headingOrientation = UIDevice.current.orientation.headingOrientation
      setupApplicationEvent()
      lm.delegate = self
      
      lm.requestWhenInUseAuthorization()
      
      startLocationService()
      startHeadingService()
    }
  }
  
  /**
   * アプリの状態が変化する際のイベントの待ち受けを登録する
   */
  private func setupApplicationEvent() {
    let nc = NotificationCenter.default;
    nc.addObserver(self, selector: #selector(applicationWillEnterForeground),
                   name: NSNotification.Name(rawValue: "applicationWillEnterForeground"), object: nil);
    nc.addObserver(self, selector: #selector(applicationDidEnterBackground),
                   name: NSNotification.Name(rawValue: "applicationDidEnterBackground"), object: nil);
  }
  
  /**
   * アプリ・フォアグラウンド化時の処理
   */
  func applicationWillEnterForeground() {
    lm.startUpdatingLocation()
    lm.startUpdatingHeading()
  }
  
  /**
   * アプリ・バックグラウンド化時の処理
   */
  func applicationDidEnterBackground() {
    lm.stopUpdatingLocation()
    lm.stopUpdatingHeading()
  }
  
  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    authorizationStatus = status
    switch status {
    case .authorizedAlways, .authorizedWhenInUse :
      lm.startUpdatingLocation()
      lm.startUpdatingHeading()
    default:
      lm.stopUpdatingLocation()
      lm.stopUpdatingHeading()
    }
  }
  
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations:[CLLocation]) {
    let location = locations.last!
    if  Date().timeIntervalSince(location.timestamp) < timeTolerance {
      let newLocation = location.coordinate
      let (distance, _) = calcDistanceAndAngle(from: newLocation, to: prevLocation)
      if distance > distanceFilter {
        renderer.updateLocation(location: newLocation)
      }
      prevLocation = newLocation
    }
  }
  
  
  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    if Date().timeIntervalSince(newHeading.timestamp) < timeTolerance
        && newHeading.trueHeading >= 0.0 {
      print("▷▷ Heading:\(newHeading.trueHeading)")
      UIView.animate(withDuration: 1.0,
                     animations: { self.renderer.heading = Double(newHeading.trueHeading) })
    }
  }
  
  func viewWillTransition(to size: CGSize) {
    lm.headingOrientation = UIDevice.current.orientation.headingOrientation
    renderer.changeOrientation(to: size)
  }
  
  /**
   * 方位検知サービスを開始する
   */
  func startHeadingService() {
    lm.headingOrientation = UIDevice.current.orientation.headingOrientation
    lm.headingFilter = headingFilter
    lm.startUpdatingHeading()
  }
  
  /**
   * 位置検知サービスを開始する
   */
  func startLocationService() {
    lm.desiredAccuracy = kCLLocationAccuracyBest
    lm.distanceFilter = distanceFilter
    lm.startUpdatingLocation()
  }
  
}
