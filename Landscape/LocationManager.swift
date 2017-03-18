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
  
  private let headingFilter = 1.0
  
  private let timeTolerance = 60.0
  
  // 画面描画オブジェクト
  private var renderer: SceneRenderer
  
  private let animator: HeadingAnimator
  
  //
  var prevLocation = CLLocationCoordinate2D()
  
  init(renderer: SceneRenderer) {
    self.renderer = renderer
    animator = HeadingAnimator(renderer: renderer)
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
        renderer.updateLocation(location: location)
      }
      prevLocation = newLocation
    }
  }
  
  
  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    if Date().timeIntervalSince(newHeading.timestamp) < timeTolerance
        && newHeading.trueHeading >= 0.0 {
      animator.animate(to: Double(newHeading.trueHeading))
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

class HeadingAnimator {
  // 描画オブジェクト
  private let renderer: SceneRenderer
  
  // 最終方位
  private var endValue = 0.0

  // 直前の描画の時刻
  private var prevUpdateTime: Date?
  
  // 描画間隔（30fps)
  private let renderingPeriod = 1.0 / 30.0

  init(renderer: SceneRenderer) {
    self.renderer = renderer
  }
  
  func animate(to: Double) {
    Logger.log(String(format:"▷ heading: %7.3f -> %7.3f", renderer.heading ?? 999.0, to))
    endValue = to
    if renderer.heading == nil {
      renderer.heading = endValue
    } else {
      let displayLink = CADisplayLink(target: self, selector: #selector(updateHeading(link:)))
      displayLink.add(to: .current, forMode: .commonModes)
    }
  }
  
  @objc func updateHeading(link: AnyObject) {
    var currentValue = renderer.heading!
    let delta = angle(from: currentValue, to: endValue)
    if abs(delta) < 0.1 {
      link.invalidate()
    } else {
      let now = Date()
      if let prev = prevUpdateTime {
        let time = now.timeIntervalSince(prev)
        if time < renderingPeriod {
          return
        }
      }
      currentValue = angleAdd(to: currentValue, delta: delta * 0.1)
      prevUpdateTime = now
      renderer.heading = currentValue
    }
  }
}
