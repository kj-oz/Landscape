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


// MARK: - UIDeviceOrientationに、対応するビデオに関する向き、方位に関する向きを返すプロパティを追加
extension UIDeviceOrientation {
  
  /// ビデオに関するデバイスの向き
  var videoOrientation: AVCaptureVideoOrientation? {
    switch self {
    case .portrait: return .portrait
    case .portraitUpsideDown: return .portraitUpsideDown
    case .landscapeLeft: return .landscapeRight
    case .landscapeRight: return .landscapeLeft
    default: return nil
    }
  }
  
  /// 方位に関するデバイスの向き
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

// MARK: - UIInterfaceOrientationに、対応するビデオに関する向きを返すプロパティを追加
extension UIInterfaceOrientation {
  
  /// ビデオに関するデバイスの向き
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

/// 角度（°）をラジアンに変換する
///
/// - Parameter degree: 角度（°）
/// - Returns: ラジアン
func toRadian(_ degree: Double) -> Double {
  return degree / 180 * M_PI
}

/// ラジアンを角度（°）に変換する
///
/// - Parameter radian: ラジアン
/// - Returns: 角度（°）
func toDegree(_ radian: Double) -> Double {
  return radian * 180 / M_PI
}

/// 地球の長径
let EARTH_R = 6_378_137.0

/// ある点から見たある点の位置を計算する
///
/// - Parameters:
///   - from: 距離と方位を計算する起点
///   - to: 距離と方位を求める点
/// - Returns: 指定の点の距離と方位
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

/// ある点（方位角A）からある点（方位角B）までの角度を求める
///
/// - Parameters:
///   - from: 方位角A
///   - to: 方位角B
/// - Returns: 方位角Aから方位角Bまでの角度（-180度〜180度）
/// 　         toがfromから見て向かって右側にあれば正、左側にあれば負の値が返る
func angle(from: Double, to: Double) -> Double {
  var diff = to - from
  if diff > 180.0 {
    diff -= 360
  } else if diff < -180.0 {
    diff += 360
  }
  return diff
}

/// ある方位角にある角度を加えた方位角を得る
///
/// - Parameters:
///   - to: 元の方位角
///   - delta: 加える角度
/// - Returns: ある方位角にある角度を加えた方位角
func angleAdd(to: Double, delta: Double) -> Double {
  var add = to + delta
  if add < 0 {
    add += 360
  } else if add > 360 {
    add -= 360
  }
  return add
}

/// ログ出力の行頭に現在時刻をつけるためのクラス
class Logger {
  
  /// 時刻のフォーマッター
  private static var formatter: DateFormatter = {
    var obj = DateFormatter()
    obj.dateFormat = "HH:mm:ss.SSS"
    return obj
  } ()
  
  /// 文字列の行頭に現在時刻をつけて出力する
  ///
  /// - Parameters:
  ///   - message: ログ本体の文字列
  ///   - now: 現在時刻、省略された場合メソッドの中で改めて取得
  static func log(_ message: String, now: Date = Date()) {
    print(formatter.string(from: now) + " " + message)
  }
}
