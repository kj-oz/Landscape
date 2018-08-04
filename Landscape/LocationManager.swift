//
//  LocationManager.swift
//  Landscape
//
//  Created by KO on 2017/01/25.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit
import CoreLocation

/// 端末の存在する位置や向きを管理するクラス
class LocationManager: NSObject, CLLocationManagerDelegate {
  
  /// 位置情報サービスの許可状態
  var authorizationStatus = CLLocationManager.authorizationStatus()
  
  /// 位置情報サービスが動作可能かどうか
  let supportsLocation = CLLocationManager.headingAvailable() &&
    CLLocationManager.locationServicesEnabled()
  
  /// 位置情報サービス
  private let lm = CLLocationManager()
  
  /// 位置の更新を通知する距離(m)
  private let distanceFilter = 100.0
  
  /// 方向の更新を通知する角度(°）
  private let headingFilter = 1.0
  
  /// 測定値の測定時刻の許容値（60秒以上前の測定値は対象にしない）
  private let timeTolerance = 60.0
  
  /// 画面描画オブジェクト
  private var renderer: SceneRenderer
  
  /// 方向の変更のアニメーションを管理するオブジェクト
  private let animator: HeadingAnimator
  
  /// 前回の通知時の緯度経度
  var prevLocation = CLLocationCoordinate2D()
  
  // シミュレータ時の緯度経度高度
//  // 八ヶ岳 阿弥陀が岳
//  let simuLat = 35.973213
//  let simuLng = 138.357356
//  let simuAtt = 2780.0
//  let simuHeadding = 285.0
//  // 六本木ヒルズ
//  let simuLat = 35.6605
//  let simuLng = 139.729056
//  let simuAtt = 238.1
//  let simuHeadding = 85.0
//  // 田代平湿原から八甲田
//  let simuLat = 40.695681
//  let simuLng = 140.912650
//  let simuAtt = 565.0
//  let simuHeadding = 225.0
  // 福島実家
  let simuLat = 37.772621
  let simuLng = 140.443796
  let simuAtt = 86.0
  let simuHeadding = 240.0
//  // 弘前城から八甲田
//  let simuLat = 40.607781
//  let simuLng = 140.463317
//  let simuAtt = 45.0
//  let simuHeadding = 90.0

  /// コンストラクタ
  ///
  /// - Parameter renderer: 画面描画オブジェクト
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
    } else {
      let ll = CLLocationCoordinate2D(latitude: simuLat, longitude: simuLng)
      let loc = CLLocation(coordinate: ll, altitude: simuAtt, horizontalAccuracy: 1.0, verticalAccuracy: 1.0, timestamp: Date())
      renderer.updateLocation(location: loc)
      renderer.heading = simuHeadding
      renderer.isSimulator = true
    }
  }
  
  /// アプリの状態が変化する際のイベントの待ち受けを登録する
  private func setupApplicationEvent() {
    let nc = NotificationCenter.default;
    nc.addObserver(self, selector: #selector(applicationWillEnterForeground),
                   name: NSNotification.Name(rawValue: "applicationWillEnterForeground"), object: nil);
    nc.addObserver(self, selector: #selector(applicationDidEnterBackground),
                   name: NSNotification.Name(rawValue: "applicationDidEnterBackground"), object: nil);
  }
  
  /// アプリ・フォアグラウンド化時の処理
  @objc func applicationWillEnterForeground() {
    lm.startUpdatingLocation()
    lm.startUpdatingHeading()
  }
  
  /// アプリ・バックグラウンド化時の処理
  @objc func applicationDidEnterBackground() {
    lm.stopUpdatingLocation()
    lm.stopUpdatingHeading()
  }
  
  /// 機器の縦横の変更時に呼び出される
  ///
  /// - Parameter size: 機器の画面の（機器の向きに準じた）サイズ
  func changeOrientation(to size: CGSize) {
    lm.headingOrientation = UIDevice.current.orientation.headingOrientation
    renderer.changeOrientation(to: size)
  }
  
  // MARK: - CLLocationManagerDelegate
  // 使用許可状態が変更された場合に呼び出される
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
  
  /// 方位検知サービスを開始する
  private func startHeadingService() {
    lm.headingOrientation = UIDevice.current.orientation.headingOrientation
    lm.headingFilter = headingFilter
    lm.startUpdatingHeading()
  }
  
  /// 位置検知サービスを開始する
  private func startLocationService() {
    lm.desiredAccuracy = kCLLocationAccuracyBest
    lm.distanceFilter = distanceFilter
    lm.startUpdatingLocation()
  }

  // 位置が変更された場合に呼び出される
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
  
  // 方位が変更された場合に呼び出される
  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    if Date().timeIntervalSince(newHeading.timestamp) < timeTolerance
      && newHeading.trueHeading >= 0.0 {
      animator.animate(to: Double(newHeading.trueHeading))
    }
  }
}

/// 方位変更のアニメーションを管理するクラス
class HeadingAnimator {
  
  /// 描画オブジェクト
  private let renderer: SceneRenderer
  
  /// 最終方位
  private var endValue = 0.0

  /// 直前の描画の時刻
  private var prevUpdateTime: Date?
  
  /// 描画間隔（30fps)
  private let renderingPeriod = 1.0 / 30.0
  
  /// アニメーションを停止する終点からの誤差
  private let stopTolerance = 0.1
  
  /// 1回のアニメーションで変更する率
  private let animationStepRatio = 0.1
  
  
  /// コンストラクタ
  ///
  /// - Parameter renderer: 画面描画オブジェクト
  init(renderer: SceneRenderer) {
    self.renderer = renderer
  }
  
  /// 指定の方位まで、アニメーションを行う
  ///
  /// - Parameter to: 最終的な方位
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
  
  /// アニメーションの一コマごとに呼び出される
  ///
  /// - Parameter link: ディスプレイ・リンク・オブジェクト
  @objc func updateHeading(link: AnyObject) {
    var currentValue = renderer.heading!
    let delta = angle(from: currentValue, to: endValue)
    if abs(delta) < stopTolerance {
      link.invalidate()
    } else {
      let now = Date()
      if let prev = prevUpdateTime {
        let time = now.timeIntervalSince(prev)
        if time < renderingPeriod {
          return
        }
      }
      currentValue = angleAdd(to: currentValue, delta: delta * animationStepRatio)
      prevUpdateTime = now
      renderer.heading = currentValue
    }
  }
}
