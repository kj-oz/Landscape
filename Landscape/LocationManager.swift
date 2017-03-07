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
  
//  private var updatingHeading = false
  
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
        renderer.updateLocation(location: newLocation)
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
  
  // 現在の方位
  private var currentValue = 0.0
  
  // 1回の描画での方位の増加値
  private var delta = 0.0
  
  // 最終方位
  private var endValue = 0.0

  // 直前の描画の時刻
  private var prevUpdate: Date?
  
  // 直前の方位変更イベントの時刻
  private var prevEvent: Date?
  
  // 描画間隔（30fps)
  private let renderingPeriod = 1.0 / 30.0

  // 1回のイベントでの最大の描画回数
  private let numUpadateMax = 15.0
  
  
  init(renderer: SceneRenderer) {
    self.renderer = renderer
  }
  
  func animate(to: Double) {
    print("▷▷ Heading:\(to)  ", terminator: "")
    endValue = to
    let now = Date()
    if renderer.heading == nil {
      renderer.heading = endValue
      print("")
    } else {
      if delta == 0.0 {
        currentValue = renderer.heading!
      }
      let period = now.timeIntervalSince(prevEvent!)
      let numUpdate = min(ceil(period / renderingPeriod), numUpadateMax)
      print("n:\(numUpdate)")
      
      delta = angle(from: currentValue, to: endValue) / numUpdate
      prevUpdate = nil
      
      let displayLink = CADisplayLink(target: self, selector: #selector(updateHeading(link:)))
      displayLink.add(to: .current, forMode: .commonModes)
    }
    prevEvent = now
  }
  
  @objc func updateHeading(link: AnyObject) {
    currentValue = angleAdd(to: currentValue, delta: delta)
    if abs(currentValue - endValue) < 0.01 {
      link.invalidate()
      delta = 0.0
    } else {
      let now = Date()
      if let prev = prevUpdate {
        let time = now.timeIntervalSince(prev)
        let delay = renderingPeriod - time
        if delay > 0 {
          DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            print("delay:\(delay)")
            self.prevUpdate = Date()
            self.renderer.heading = self.currentValue
            return
          }
        }
      }
      prevUpdate = now
      renderer.heading = currentValue
    }
  }
  
}
