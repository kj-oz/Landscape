//
//  Util.swift
//  Landscape
//
//  Created by KO on 2017/01/26.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit
import AVFoundation
import CoreLocation


/**
 * UIDeviceOrientationに、対応するビデオの向き、方位基準の向きを返すプロパティを追加
 */
extension UIDeviceOrientation {
  var videoOrientation: AVCaptureVideoOrientation? {
    switch self {
    case .portrait: return .portrait
    case .portraitUpsideDown: return .portraitUpsideDown
    case .landscapeLeft: return .landscapeRight
    case .landscapeRight: return .landscapeLeft
    default: return nil
    }
  }
  var headingOrientation: CLDeviceOrientation {
    switch self {
    case .portrait: return .portrait
    case .portraitUpsideDown: return .portraitUpsideDown
    case .landscapeLeft: return .landscapeLeft
    case .landscapeRight: return .landscapeRight
    default: return .unknown
    }
  }
}

/**
 * UIInterfaceOrientationに、対応するビデオの向きを返すプロパティを追加
 */
extension UIInterfaceOrientation {
  var videoOrientation: AVCaptureVideoOrientation? {
    switch self {
    case .portrait: return .portrait
    case .portraitUpsideDown: return .portraitUpsideDown
    case .landscapeLeft: return .landscapeLeft
    case .landscapeRight: return .landscapeRight
    default: return nil
    }
  }
}

func toRadian(_ degree: Double) -> Double {
  return degree / 180 * M_PI
}

func toDegree(_ radian: Double) -> Double {
  return radian * 180 / M_PI
}

let EARTH_R = 6_378_137.0

func calcDistanceAndAngle(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D)
    -> (Double, Double) {
  let dx = toRadian(to.longitude - from.longitude)
  let y1 = toRadian(from.latitude)
  let y2 = toRadian(to.latitude)
  let sin_y1 = sin(y1)
  let cos_y1 = cos(y1)
  let cos_dx = cos(dx)
  
  let distance = EARTH_R * acos(sin_y1 * sin(y2) + cos_y1 * cos(y2) * cos_dx)
  var angle = toDegree(atan2(sin(dx), cos_y1 * tan(y2) - sin_y1 * cos_dx))
  if angle < 0 {
    angle += 360
  }
  return (distance, angle)
}

func angle(from: Double, to: Double) -> Double {
  var diff = to - from
  if diff > 180.0 {
    diff -= 360
  } else if diff < -180.0 {
    diff += 360
  }
  return diff
}

func angleAdd(to: Double, delta: Double) -> Double {
  var add = to + delta
  if add < 0 {
    add += 360
  } else if add > 360 {
    add -= 360
  }
  return add
}

