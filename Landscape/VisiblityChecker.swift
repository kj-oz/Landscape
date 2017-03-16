//
//  swift
//  Landscape
//
//  Created by KO on 2017/03/10.
//  Copyright © 2017年 KO. All rights reserved.
//

import Foundation
import CoreLocation
import Dispatch

/// 3次メッシュの高さを管理する構造体
struct Mesh {
  /// メッシュのX方向（経度）幅
  static let xPitch = 1 / 80.0
  
  /// メッシュのY方向（緯度）幅
  static let yPitch = 1 / 120.0
  
  /// メッシュ座標系の原点の1次メッシュコード（4629）のX成分
  static let originX = 29
  
  /// メッシュ座標系の原点の1次メッシュコード（4629）のY成分
  static let originY = 46
  
  /// 原点の経度
  static let originLng = 129.0 + xPitch * 0.5
  
  /// 原点の緯度
  static let originLat = 46.0 * 2.0 / 3.0 + yPitch * 0.5
  
  /// 右上メッシュの1次メッシュコード（6845）のX成分
  private static let maxX = 45
  
  /// 右上メッシュの1次メッシュコード（6845）のY成分
  private static let maxY = 68
  
  /// 1次メッシュ各辺の3次メッシュ数
  private static let num3 = 80
  
  /// メッシュのX方向の数
  private static let numX = (maxX - originX + 1) * num3
  
  /// メッシュのY方向の数
  static let numY = (maxY - originY + 1) * num3
  
  /// 各3次メッシュの標高（平均高さと最高高さの平均）
  private static var _heights: [Int16] = []
  
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
    return Double(_heights[y * numX + x])
  }
  
  /// メッシュ標高データを読み込む
  /// 各メッシュの標高は、最高高さと平均高さの平均値とする
  static func loadMem() {
    let start = Date()
    let docDir = FileUtil.documentDir
    let csvPath = docDir.appending("/mem.csv")
    let binPath = docDir.appending("/mem.bin")
    let binLength = MemoryLayout<Int16>.size * numX * numY
    
    _heights = Array(repeating: Int16(0), count: numX * numY)

    let fm = FileManager.default
    if fm.fileExists(atPath: csvPath) {
      let lines = FileUtil.readLines(path: csvPath)
      for line in lines {
        let parts = line.components(separatedBy: ",")
        let (mx, my) = index(of: parts[0])
        
        // 高さは、最高高さと平均高さの平均
        let h = (Double(parts[1])! + Double(parts[2])!) / 2.0
        _heights[my * numX + mx] = Int16(h)
      }
      print("loadMem(csv):\(Date().timeIntervalSince(start))")
      
      let data = NSMutableData(bytes: &_heights, length: binLength)
      data.write(toFile: binPath, atomically: true)
      try? fm.removeItem(atPath: csvPath)
    } else {
      let data = NSData(contentsOfFile: binPath)
      if let data = data {
        data.getBytes(&_heights, length: binLength)
      }
      print("loadMem(bin):\(Date().timeIntervalSince(start))")
    }
  }
  
  /// 与えられたメッシュコードに対するメッシュ座標（整数）を得る
  ///
  /// - Parameter code: メッシュコード
  /// - Returns: 整数座標
  private static func index(of code: String) -> (Int, Int) {
    var startIndex = code.startIndex
    var endIndex = code.index(startIndex, offsetBy: 2)
    let y1 = Int(code.substring(with: startIndex ..< endIndex))!
    startIndex = endIndex
    endIndex = code.index(startIndex, offsetBy: 2)
    let x1 = Int(code.substring(with: startIndex ..< endIndex))!
    startIndex = endIndex
    endIndex = code.index(startIndex, offsetBy: 1)
    let y2 = Int(code.substring(with: startIndex ..< endIndex))!
    startIndex = endIndex
    endIndex = code.index(startIndex, offsetBy: 1)
    let x2 = Int(code.substring(with: startIndex ..< endIndex))!
    startIndex = endIndex
    endIndex = code.index(startIndex, offsetBy: 1)
    let y3 = Int(code.substring(with: startIndex ..< endIndex))!
    startIndex = endIndex
    endIndex = code.index(startIndex, offsetBy: 1)
    let x3 = Int(code.substring(with: startIndex ..< endIndex))!
    let x = (x1 - originX) * 80 + x2 * 10 + x3
    let y = (y1 - originY) * 80 + y2 * 10 + y3
    return (x, y)
  }
  
  /// 与えられた整数座標に対するメッシュコードを得る
  ///
  /// - Parameters:
  ///   - x: 座標のX方向成分
  ///   - y: 座標のY方向成分
  /// - Returns: メッシュコード
  static func code(x: Int, y: Int) -> String {
    let x3 = x % 10
    let x2 = x / 10 % 8
    let x1 = x / 80 + originX
    let y3 = y % 10
    let y2 = y / 10 % 8
    let y1 = y / 80 + originY
    return String(format: "%d%d%d%d%d%d", y1, x1, y2, x2, y3, x3)
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
  
  /// 距離と可視高さの2次式の係数A
  private let a = 1.0 / (2.0 * EARTH_R)
  
  /// 距離と可視高さの2次式の係数B（現在地の標高により定まる）
  private var b = 0.0
  
  /// 判定対象として扱う最大距離
  private let maxDistance = 400_000.0
  
  /// メッシュ標高の読み込みが済んでいるか
  var memLoaded = false
  
  /// 現在地
  var currentLocation: CLLocation? {
    didSet {
      let coord = currentLocation!.coordinate
      y1 = toRadian(coord.latitude)
      sin_y1 = sin(y1)
      cos_y1 = cos(y1)

      (cx, cy) = Mesh.coordinate(of: coord)
      cz = currentLocation!.altitude
      b = -sqrt(2.0 * EARTH_R * cz) / EARTH_R
      
      print(String(format:"現在地: %@(%.3f/%.3f) H=%.0f",
                   Mesh.code(x: Int(round(cx)), y: Int(round(cy))),
                   coord.longitude, coord.latitude, currentLocation!.altitude))
    }
  }
  
  /// コンストラクタ
  /// 非同期でメッシュ標高を読み込む
  init() {
    DispatchQueue.global(qos: .userInitiated).async {
      Mesh.loadMem()
      self.memLoaded = true
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
    if d > maxDistance {
      print(String(format:"\(poi.name),%.0f,%.1f,D", poi.height, poi.distance / 1000.0))
      return false
    }
    
    // 間に障害物がない場合の最低可視高さ
    let minH = a * d * d + b * d + cz
    if poi.height < minH {
      print(String(format:"\(poi.name),%.0f,%.1f,H,%.0f", poi.height, poi.distance / 1000.0, minH))
      return false
    }
    
    // 間の地形で見えなくなっていないかの検討
    let (px, py) = Mesh.coordinate(of: poi.location)
    let vx = px - cx
    let vy = py - cy
    
    let bb = (poi.height - minH) / d + b
    let hor = (45.0 ... 135.0).contains(poi.azimuth) || (225.0 ... 315.0).contains(poi.azimuth)
    
    if hor {
      // 現在地とPOIの間のメッシュX座標
      var mxs: [Int]
      if vx > 0.0 {
        let sx = Int(ceil(cx + 1.0))
        let ex = Int(floor(px - 1.0))
        mxs = Array(sx ... ex)
      } else {
        let sx = Int(floor(cx - 1.0))
        let ex = Int(ceil(px + 1.0))
        mxs = (ex ... sx).reversed()
      }
      for mx in mxs {
        let ra = (Double(mx) - cx) / vx
        let my = Int(round(ra * vy + cy))
        // 各座標のメッシュ高さ
        let mz = Mesh.height(x: mx, y: my)
        if mz > 0.0 {
          let md = poi.distance * ra
          // POIが見えるためのその座標位置における最大高さ（メッシュ高さがそれ以下なら邪魔をしない）
          let hc = a * md * md + bb * md + cz
          if mz > hc {
            print(String(format:"\(poi.name),%.0f,%.1f,M,%.3f,%.3f,%@,%.2f,%.0f,%.0f",
              poi.height, poi.distance / 1000.0, poi.location.longitude, poi.location.latitude,
              Mesh.code(x: mx, y: my), ra, hc, mz))
            return false
          }
        }
      }
      
    } else {
      // 現在地とPOIの間のメッシュY座標
      var mys: [Int]
      if vy > 0.0 {
        let sy = Int(ceil(cy + 1.0))
        let ey = Int(floor(py - 1.0))
        mys = Array(sy ... ey)
      } else {
        let sy = Int(floor(cy - 1.0))
        let ey = Int(ceil(py + 1.0))
        mys = (ey ... sy).reversed()
      }
      for my in mys {
        let ra = (Double(my) - cy) / vy
        let mx = Int(round(ra * vx + cx))
        // 各座標のメッシュ高さ
        let mz = Mesh.height(x: mx, y: my)
        if mz > 0.0 {
          let md = poi.distance * ra
          // POIが見えるためのその座標位置における最大高さ（メッシュ高さがそれ以下なら邪魔をしない）
          let hc = a * md * md + bb * md + cz
          if mz > hc {
            print(String(format:"\(poi.name),%.0f,%.1f,M,%.3f,%.3f,%@,%.2f,%.0f,%.0f",
              poi.height, poi.distance / 1000.0, poi.location.longitude, poi.location.latitude,
              Mesh.code(x: mx, y: my), ra, hc, mz))
            return false
          }
        }
      }
    }
    print(String(format:"\(poi.name),%.0f,%.1f,G", poi.height, poi.distance / 1000.0))
    return true
  }
  
}
