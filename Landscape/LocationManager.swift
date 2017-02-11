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
  let lm = CLLocationManager()
  
  let distanceFilter = 100.0
  
  // デバイスの背面の指す方位
  var heading: CLHeading?
  
  // 画面描画オブジェクト
  var renderer: SceneRenderer?
  
  //
  var prevLocation = CLLocationCoordinate2D()
  
  init(renderer: SceneRenderer) {
    super.init()
    self.renderer = renderer

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
    let newLocation = locations.last!.coordinate
    let (distance, _) = calcDistanceAndAngle(from: newLocation, to: prevLocation)
    if distance > distanceFilter {
      renderer!.updateLocation(location: newLocation)
    }
    prevLocation = newLocation
  }
  
  
  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    renderer!.updateHeading(heading: Double(newHeading.trueHeading))
  }
  
  func viewWillTransition(to size: CGSize) {
    lm.headingOrientation = UIDevice.current.orientation.headingOrientation
    renderer!.changeOrientation(to: size)
  }
  
  /**
   * 方位検知サービスを開始する
   */
  func startHeadingService() {
    lm.headingOrientation = UIDevice.current.orientation.headingOrientation
    lm.headingFilter = 3.0
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
