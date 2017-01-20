//
//  SceneManager.swift
//  Landscape
//
//  Created by KO on 2017/01/04.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit
import CoreLocation

class SceneManager: NSObject, CLLocationManagerDelegate, CALayerDelegate {
  // 位置情報サービスの許可状態
  var authorizationStatus = CLLocationManager.authorizationStatus()
  
  // 位置情報サービスが動作可能かどうか
  let supportsLocation = CLLocationManager.headingAvailable() &&
                          CLLocationManager.locationServicesEnabled()
  
  // 位置情報サービス
  let lm = CLLocationManager()
  
  // カメラ画像の画角
  var fieldAngleH = 62.0
  var fieldAngleV = toDegree(atan(375.0 / 663.0 * tan(toRadian(31.0)))) * 2.0
  var fieldAngle = 0.0
  var tanFA = 0.0
  
  // デバイスの背面の指す方位
  var heading: CLHeading?
  
  // デバイスの緯度経度
  var location: CLLocationCoordinate2D?
  
  var orientations: [Orientation] = []
  
  private weak var cameraView: CameraView? = nil
  
  private var size = CGSize()
  
  var layer: CALayer?
  
  init(cameraView: CameraView) {
    super.init()
    self.cameraView = cameraView
    size = cameraView.frame.size

    if supportsLocation {
      
      if let layer = layer {
        layer.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
      }
 
      //fieldAngle = getFieldAngle()
      lm.headingOrientation = UIDevice.current.orientation.headingOrientation
      self.fieldAngle = size.width > size.height ? self.fieldAngleH : self.fieldAngleV

      tanFA = tan(toRadian(fieldAngle / 2))
      setupApplicationEvent()
      lm.delegate = self

      lm.requestWhenInUseAuthorization()
      
      startLocationService()
      startHeadingService()
      
      createOrientations()
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
    self.location = locations.last!.coordinate
    
    // 対象POIの再計算
    
    
    // レイヤの再描画
    layer!.setNeedsDisplay()
  }
  
  
  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    self.heading = newHeading
    
    // レイヤの再描画
    layer!.setNeedsDisplay()
  }
  
  func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    lm.headingOrientation = UIDevice.current.orientation.headingOrientation
    self.fieldAngle = size.width > size.height ? self.fieldAngleH : self.fieldAngleV
    self.tanFA = tan(toRadian(fieldAngle / 2))
    self.layer!.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
    self.size = size
    
    layer!.setNeedsDisplay()
  }
  
  /**
   * 方位検知サービスを開始する
   */
  func startHeadingService() {
    lm.headingOrientation = UIDevice.current.orientation.headingOrientation
    lm.headingFilter = 0.1
    lm.startUpdatingHeading()
  }
  
  /**
   * 位置検知サービスを開始する
   */
  func startLocationService() {
    lm.desiredAccuracy = kCLLocationAccuracyBest
    lm.distanceFilter = 100
    lm.startUpdatingLocation()
  }

  func draw(_ layer: CALayer, in ctx: CGContext) {
    if heading == nil {
      return
    }
    
    ctx.saveGState()
    UIGraphicsPushContext(ctx)
    
    // 描画範囲
    let headingAngle = heading!.trueHeading
    var startAngle = headingAngle - fieldAngle * 0.5
    if startAngle < 0 {
      startAngle += 360
    }
    var endAngle = headingAngle + fieldAngle * 0.5
    if endAngle > 360 {
      endAngle -= 360
    }
    
    // 方位の表示
    let scaleH = CGFloat(30.0)
    let rect = CGRect(x: 0, y: size.height - scaleH, width: size.width, height: scaleH)
    ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
    ctx.fill(rect)
    
    ctx.setStrokeColor(UIColor.black.cgColor)
    
//    if startAngle < endAngle {
//      for or in orientations {
//        if or.orientation < startAngle {
//          continue
//        } else if or.orientation > endAngle {
//          break
//        }
//        
//        drawOrientation(context: ctx, orientation: or, textAttrs: attrs)
//      }
//    } else {
//      for or in orientations {
//        if or.orientation > endAngle && or.orientation < startAngle {
//          continue
//        }
//        
//        drawOrientation(context: ctx, orientation: or, textAttrs: attrs)
//      }
//    }
    let tick = 1.5
    let startIndex = Int(startAngle / tick) + 1
    let endIndex = Int(endAngle / tick)
    if startAngle < endAngle {
      for i in startIndex ... endIndex {
        drawOrientation(context: ctx, tick: i)
      }
    } else {
      for i in 0 ... endIndex {
        drawOrientation(context: ctx, tick: i)
      }
      for i in startIndex ..< 240 {
        drawOrientation(context: ctx, tick: i)
      }
    }
    
    // POIの描画
    
//    let rect3 = CGRect(x: 40, y: 40, width: size.width - 100, height: size.height - 100)
//    ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 0.5)
//    ctx.fill(rect3)
//    
//    ctx.setStrokeColor(UIColor.black.cgColor)
//    var string = "size: \(size)\n"
//    string += "layer size: \(layer.bounds)\n"
//    string += "layer postion: \(layer.position)\n"
//    string += "layer scale: \(layer.contentsScale)\n"
//    string += "view: \(cameraView?.bounds)\n"
//    string += "heading: \(headingAngle)\n"
//    string += "fieldAngle: \(fieldAngle)\n"
//  
//    string.draw(with: CGRect(x: 50, y: 50, width: 200, height: 200), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    
    UIGraphicsPopContext()
    ctx.restoreGState()
  }
  
  private func getFieldAngle() -> Double {
    return 62.0
  }
  
  private func createOrientations() {
    let labels = ["北", "北北東", "北東", "東北東",
                  "東", "東南東", "南東", "南南東",
                  "南", "南南西", "南西", "西南西",
                  "西", "西北西", "北西", "北北西"]
    
    for i in 0 ..< 16 {
      let angle = Double(i) * 22.5
      orientations.append(Orientation(name: labels[i], orientation: angle))
    }
  }
  
  private func drawOrientation(context: CGContext, tick: Int) {
    let centerAngle = Double(heading!.trueHeading)
    var angle = Double(tick) * 1.5 - centerAngle
    if angle < -180 {
      angle += 360
    } else if angle > 180 {
      angle -= 360
    }
    let w_2 = size.width / 2
    let x = w_2 * CGFloat(1 + tan(toRadian(angle)) / tanFA)
    let longTickLength: CGFloat = 12
    let tickLength: CGFloat = 6
    
    if tick % 15 == 0 {
      let orientation = orientations[tick / 15]
      var fontSize: CGFloat = 0
      switch orientation.level {
      case 1:
        fontSize = 16
      case 2:
        fontSize = 14
      case 3:
        fontSize = 12
      default:
        fontSize = 10
      }
      
      let paragraphStyle = NSMutableParagraphStyle()
      paragraphStyle.alignment = .center
      let attrs = [NSFontAttributeName: UIFont.systemFont(ofSize: fontSize), NSParagraphStyleAttributeName: paragraphStyle]
      
      // 長目の目盛り　＋　文字列
      context.strokeLineSegments(between:
        [CGPoint(x: x, y: size.height - longTickLength), CGPoint(x: x, y: size.height)])
      orientation.name.draw(with: CGRect(x: x - 30, y: size.height - longTickLength - fontSize - 4, width: 60, height: 18), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    } else {
      // 短めの目盛り
      context.strokeLineSegments(between:
        [CGPoint(x: x, y: size.height - tickLength), CGPoint(x: x, y: size.height)])
    }
  }
}

func toRadian(_ degree: Double) -> Double {
  return degree / 180 * M_PI
}

func toDegree(_ radian: Double) -> Double {
  return radian * 180 / M_PI
}
