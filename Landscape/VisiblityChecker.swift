//
//  VisibilityChecker.swift
//  Landscape
//
//  Created by KO on 2017/03/10.
//  Copyright © 2017年 KO. All rights reserved.
//

import Foundation
import CoreLocation
import Dispatch

/// 100mメッシュの高さを管理する構造体
struct Mesh {
  
  /// 1次メッシュX方向のメッシュ数
  private static let numM1X = 900
  
  /// 1次メッシュY方向のメッシュ数
  private static let numM1Y = 600
  
  /// メッシュのX方向（経度）幅
  static let xPitch = 1 / Double(numM1X)
  
  /// メッシュのY方向（緯度）幅
  static let yPitch = 1 / 1.5 / Double(numM1Y)
  
  /// メッシュ座標系の原点の1次メッシュコード（4629）のX成分
  static let originM1X = 29
  
  /// メッシュ座標系の原点の1次メッシュコード（4629）のY成分
  static let originM1Y = 46
  
  /// 原点の経度
  static let originLng = 129.0 + xPitch * 0.5
  
  /// 原点の緯度
  static let originLat = 46.0 * 2.0 / 3.0 + yPitch * 0.5
  
  /// 右上メッシュの1次メッシュコード（6845）のX成分
  private static let maxM1X = 45
  
  /// 右上メッシュの1次メッシュコード（6845）のY成分
  private static let maxM1Y = 68
  
  /// メッシュのX方向の数
  private static let numX = (maxM1X - originM1X + 1) * numM1X
  
  /// メッシュのY方向の数
  static let numY = (maxM1Y - originM1Y + 1) * numM1Y
  
  /// 各メッシュの標高（最高高さ）、1次メッシュごとの配列に保持
  private static var _heights: [String:[Int16]] = [:]
  
  
  /// 与えられた点のメッシュ座標系における実数座標
  ///
  /// - Parameter location: 指定の点の緯度経度
  /// - Returns: 指定の点のメッシュ座標系での実数座標
  static func coordinate(of location: CLLocationCoordinate2D) -> (Double, Double) {
    let x = (Double(location.longitude) - originLng) / xPitch
    let y = (Double(location.latitude) - originLat) / yPitch
    return (x, y)
  }
  
  /// 与えられたメッシュ座標（整数）の標高
  ///
  /// - Parameters:
  ///   - x: 座標のX方向成分
  ///   - y: 座標のY方向成分
  /// - Returns: 標高
  static func height(x: Int, y: Int) -> Double {
    if x < 0 || y < 0 || x >= numX || y >= numY {
      return 0.0
    }
    let mx = x / numM1X
    let my = y / numM1Y
    let code = String((my + originM1Y) * 100 + (mx + originM1X))
    var mesh1 = _heights[code]
    if mesh1 == nil {
      mesh1 = loadMesh1(code: code)
      _heights[code] = mesh1
    }
    
    let dx = x - mx * numM1X
    let dy = y - my * numM1Y
    return Double(mesh1![dy * numM1X + dx]) / 10.0
  }
  
  /// 指定の1次メッシュの標高データを読み込む
  ///
  /// - Parameter code: 1次メッシュコード
  /// - Returns: 標高データ配列
  static func loadMesh1(code: String) -> [Int16] {
    let binPath = Bundle.main.path(forResource: "/\(code)_MAX_10", ofType: "bin", inDirectory: "Data")
    var result = Array(repeating: Int16(0), count: numM1X * numM1Y)
    
    if let path = binPath, let data = NSData(contentsOfFile: path) {
      let binLength = MemoryLayout<Int16>.size * numM1X * numM1Y
      data.getBytes(&result, length: binLength)
    }
    return result
  }
}

/// POIが地形上、見えるかどうかを判定する機能を提供する
class VisiblityChecker {
  
  /// 現在地の緯度
  private var y1 = 0.0
  
  /// 現在地の緯度のsin
  private var sin_y1 = 0.0
  
  /// 現在地の緯度のcos
  private var cos_y1 = 0.0
  
  /// 現在地のメッシュ座標X（実数）
  private var cx = 0.0
  
  /// 現在地のメッシュ座標Y（実数）
  private var cy = 0.0
  
  /// 現在地の標高
  private var cz = 0.0
  
  /// 気差(0.135とする）を考慮した地球のみなし半径
  private let earthR = EARTH_R / (1.0 - 0.135)
  
  /// 距離と可視高さの2次式の係数A
  private var a = 0.0
  
  /// 距離と可視高さの2次式の係数B（現在地の標高により定まる）
  private var b = 0.0
  
  /// 水平線までの距離
  private var hd = 0.0
  
  /// 判定対象として扱う最大距離
  private let maxDistance = 400_000.0
  
  /// 判定対象として扱う最小距離
  private let minDistance = 100.0
  
  /// 都市の場合の判定対象として扱う最大距離
  private let cityMaxDistance = 100_000.0
  
  /// 中間の高さをチェックする範囲（POIまでの距離に対する割合）
  private let checkRange = 0.02 ... 0.98
  
  /// 現在地
  var currentLocation: CLLocation? {
    didSet {
      let coord = currentLocation!.coordinate
      y1 = toRadian(coord.latitude)
      sin_y1 = sin(y1)
      cos_y1 = cos(y1)

      (cx, cy) = Mesh.coordinate(of: coord)
      cz = max(currentLocation!.altitude, 0.0)
      hd = sqrt(2.0 * cz * earthR)
      b = -hd / earthR
      
      print(String(format:"現在地: %.3f/%.3f H=%.0f",
                   coord.longitude, coord.latitude, currentLocation!.altitude))
    }
  }
  
  /// 最小限の（可視部分の）見上げ角
  var minimumElevation = 0.001 {
    didSet {
      UserDefaults.standard.set(minimumElevation, forKey:"minimumElevation")
    }
  }
  
  
  /// コンストラクタ
  init() {
    a = 1.0 / (2.0 * earthR)
    if let elevation = UserDefaults.standard.object(forKey: "minimumElevation") {
      minimumElevation = elevation as! Double
    }
  }
  
  /// 指定のPOIの方位と距離を、現在地からの値に更新する
  ///
  /// - Parameter poi: 対象のPOI
  func calcVector(of poi: Poi) {
    let to = poi.location
    let dx = toRadian(to.longitude - currentLocation!.coordinate.longitude)
    let y2 = toRadian(to.latitude)
    let cos_dx = cos(dx)
    
    poi.distance = EARTH_R * acos(sin_y1 * sin(y2) + cos_y1 * cos(y2) * cos_dx)
    var angle = toDegree(atan2(sin(dx), cos_y1 * tan(y2) - sin_y1 * cos_dx))
    if angle < 0 {
      angle += 360
    }
    poi.azimuth = angle
  }
  
  /// 指定のPOIが距離及び地形的に見えるかどうかを判定する
  ///
  /// - Parameter poi: 対象のPOI
  /// - Returns: 見えるかどうか
  func checkVisibility(of poi: Poi) -> Bool {
    let d = poi.distance
    if poi.type == .city {
      return d <= cityMaxDistance
    }
    if d > maxDistance || d < minDistance {
      print(String(format:"\(poi.name),%.0f,%.1f,D", poi.height, poi.distance / 1000.0))
      return false
    }
    
    // 間に障害物がない場合の最低可視高さ
    let minH = a * d * d + (b + minimumElevation) * d + cz
    if d > hd && poi.height < minH {
      print(String(format:"\(poi.name),%.0f,%.1f,H,%.0f", poi.height, poi.distance / 1000.0, minH))
      return false
    }
    
    // 間の地形で見えなくなっていないかの検討
    let (px, py) = Mesh.coordinate(of: poi.location)
    let vx = px - cx
    let vy = py - cy
    let ph = Mesh.height(x: Int(round(px)), y: Int(round(py)))
    print(String(format:"Mesh:%.0f, Poi:%.0f", ph, poi.height))
    
    let bb = (poi.height - minH) / d + b
    let hor = (45.0 ... 135.0).contains(poi.azimuth) || (225.0 ... 315.0).contains(poi.azimuth)
    
    if hor {
      // 現在地とPOIの間のメッシュX座標
      var mxs: [Int]
      if vx > 0.0 {
        let sx = Int(ceil(cx))
        let ex = Int(floor(px))
        mxs = Array(sx ... ex)
      } else {
        let sx = Int(floor(cx))
        let ex = Int(ceil(px))
        mxs = (ex ... sx).reversed()
      }
      for mx in mxs {
        let ra = (Double(mx) - cx) / vx
        if !checkRange.contains(ra) {
          continue;
        }
        let my = Int(round(ra * vy + cy))
        // 各座標のメッシュ高さ
        let mz = Mesh.height(x: mx, y: my)
        if mz > 0.0 {
          let md = poi.distance * ra
          // POIが見えるためのその座標位置における最大高さ（メッシュ高さがそれ以下なら邪魔をしない）
          let hc = a * md * md + bb * md + cz
          if mz > hc {
            print(String(format:"\(poi.name),%.0f,%.1f,M,%.3f,%.3f,%.2f,%.0f,%.0f",
              poi.height, poi.distance / 1000.0, poi.location.longitude, poi.location.latitude,
              ra, hc, mz))
            return false
          }
        }
      }
      
    } else {
      // 現在地とPOIの間のメッシュY座標
      var mys: [Int]
      if vy > 0.0 {
        let sy = Int(ceil(cy))
        let ey = Int(floor(py))
        mys = Array(sy ... ey)
      } else {
        let sy = Int(floor(cy))
        let ey = Int(ceil(py))
        mys = (ey ... sy).reversed()
      }
      for my in mys {
        let ra = (Double(my) - cy) / vy
        if !checkRange.contains(ra) {
          continue;
        }
        let mx = Int(round(ra * vx + cx))
        // 各座標のメッシュ高さ
        let mz = Mesh.height(x: mx, y: my)
        if mz > 0.0 {
          let md = poi.distance * ra
          // POIが見えるためのその座標位置における最大高さ（メッシュ高さがそれ以下なら邪魔をしない）
          let hc = a * md * md + bb * md + cz
          if mz > hc {
            print(String(format:"\(poi.name),%.0f,%.1f,M,%.3f,%.3f,%.2f,%.0f,%.0f",
              poi.height, poi.distance / 1000.0, poi.location.longitude, poi.location.latitude,
              ra, hc, mz))
            return false
          }
        }
      }
    }
    print(String(format:"\(poi.name),%.0f,%.1f,G", poi.height, poi.distance / 1000.0))
    return true
  }
}
