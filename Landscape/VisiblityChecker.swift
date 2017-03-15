//
//  VisiblityChecker.swift
//  Landscape
//
//  Created by KO on 2017/03/10.
//  Copyright © 2017年 KO. All rights reserved.
//

import Foundation
import CoreLocation
import Dispatch

class VisiblityChecker {
  private var y1 = 0.0
  private var sin_y1 = 0.0
  private var cos_y1 = 0.0
  
  
  private var cx = 0.0
  private var cy = 0.0
  private var cz = 0.0
  
  private let a = 1.0 / (2.0 * EARTH_R)
  private var b = 0.0
  
  private let maxDistance = 400_000.0
  
  /// 各3次メッシュの標高（平均高さと最高高さの平均）
  private var meshHeights: [Int16] = []
  
  /// 独自の3次メッシュ座標系の原点の1次メッシュコード（4629）のX成分
  private static let originMeshX = 29
  
  /// 独自の3次メッシュ座標系の原点の1次メッシュコード（4629）のY成分
  private static let originMeshY = 46
  
  /// 3次メッシュのX方向の数
  private static let numMeshX = (45 - 29 + 1) * 80
  
  /// 3次メッシュのY方向の数
  private static let numMeshY = (68 - 46 + 1) * 80
  
  
  private static let xPitch = 1 / 80.0
  private static let yPitch = 1 / 120.0
  
  private static let originLng = 129.0 + xPitch * 0.5
  
  private static let originLat = 46.0 * 2.0 / 3.0 + yPitch * 0.5
  
  var memLoaded = false
  
  init() {
    meshHeights = Array(repeating: Int16(0),
                        count:VisiblityChecker.numMeshX * VisiblityChecker.numMeshY)
    DispatchQueue.global(qos: .userInitiated).async {
      self.loadMem()
    }
  }
  
  var currentLocation: CLLocation? {
    didSet {
      let coord = currentLocation!.coordinate
      y1 = toRadian(coord.latitude)
      sin_y1 = sin(y1)
      cos_y1 = cos(y1)

      (cx, cy) = VisiblityChecker.meshPosition(of: coord)
      cz = currentLocation!.altitude
      b = -sqrt(2.0 * EARTH_R * cz) / EARTH_R
      
      print(String(format:"現在地: %@(%.3f/%.3f) H=%.0f",
                   VisiblityChecker.meshCode(x: Int(round(cx)), y: Int(round(cy))),
                   coord.longitude, coord.latitude, currentLocation!.altitude))
    }
  }
  
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
  
  func checkVisibility(of poi: Poi) -> Bool {
    let d = poi.distance
    if d > 400_000.0 {
      print(String(format:"\(poi.name),%.0f,%.1f,D", poi.height, poi.distance / 1000.0))
      return false
    }
    let minH = a * d * d + b * d + cz
    if poi.height < minH {
      print(String(format:"\(poi.name),%.0f,%.1f,H,%.0f", poi.height, poi.distance / 1000.0, minH))
      return false
    }
    
    let (px, py) = VisiblityChecker.meshPosition(of: poi.location)
    let vx = px - cx
    let vy = py - cy
    
    let bb = (poi.height - minH) / d + b
    let hor = (45.0 ... 135.0).contains(poi.azimuth) || (225.0 ... 315.0).contains(poi.azimuth)
    
    if hor {
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
        let mz = meshHeight(x: mx, y: my)
        if mz > 0.0 {
          let md = poi.distance * ra
          let hc = a * md * md + bb * md + cz
          if mz > hc {
            print(String(format:"\(poi.name),%.0f,%.1f,M,%.3f,%.3f,%@,%.2f,%.0f,%.0f",
              poi.height, poi.distance / 1000.0, poi.location.longitude, poi.location.latitude,
              VisiblityChecker.meshCode(x: mx, y: my), ra, hc, mz))
            return false
          }
        }
      }
      
    } else {
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
        let mz = meshHeight(x: mx, y: my)
        if mz > 0.0 {
          let md = poi.distance * ra
          let hc = a * md * md + bb * md + cz
          if mz > hc {
            print(String(format:"\(poi.name),%.0f,%.1f,M,%.3f,%.3f,%@,%.2f,%.0f,%.0f",
              poi.height, poi.distance / 1000.0, poi.location.longitude, poi.location.latitude,
              VisiblityChecker.meshCode(x: mx, y: my), ra, hc, mz))
            return false
          }
        }
      }
    }
    print(String(format:"\(poi.name),%.0f,%.1f,G", poi.height, poi.distance / 1000.0))
    return true
  }
  
  private static func meshPosition(of location: CLLocationCoordinate2D) -> (Double, Double) {
    let x = (Double(location.longitude) - originLng) / xPitch
    let y = (Double(location.latitude) - originLat) / yPitch
    return (x, y)
  }
  
  private func meshHeight(x: Int, y: Int) -> Double {
    return Double(meshHeights[y * VisiblityChecker.numMeshX + x])
  }
  
  func loadMem() {
    let start = Date()
    let docDir = FileUtil.documentDir
    let csvPath = docDir.appending("/mem.csv")
    let binPath = docDir.appending("/mem.bin")
    let binLength = MemoryLayout<Int16>.size * meshHeights.count
    
    let fm = FileManager.default
    if fm.fileExists(atPath: csvPath) {
      let lines = FileUtil.readLines(path: csvPath)
      for line in lines {
        let parts = line.components(separatedBy: ",")
        let (mx, my) = VisiblityChecker.meshIndex(of: parts[0])
        let h = (Double(parts[1])! + Double(parts[2])!) / 2.0
        meshHeights[my * VisiblityChecker.numMeshX + mx] = Int16(h)
      }
      print("loadMem(csv):\(Date().timeIntervalSince(start))")
      
      let data = NSMutableData(bytes: &meshHeights, length: binLength)
      data.write(toFile: binPath, atomically: true)
      try? fm.removeItem(atPath: csvPath)
    } else {
      let data = NSData(contentsOfFile: binPath)
      if let data = data {
        data.getBytes(&meshHeights, length: binLength)
      }
      print("loadMem(bin):\(Date().timeIntervalSince(start))")
    }
    memLoaded = true
  }
  
  private static func meshIndex(of code: String) -> (Int, Int) {
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
    let x = (x1 - originMeshX) * 80 + x2 * 10 + x3
    let y = (y1 - originMeshY) * 80 + y2 * 10 + y3
    return (x, y)
  }
  
  private static func meshCode(x: Int, y: Int) -> String {
    let x3 = x % 10
    let x2 = x / 10 % 8
    let x1 = x / 80 + originMeshX
    let y3 = y % 10
    let y2 = y / 10 % 8
    let y1 = y / 80 + originMeshY
    return String(format: "%d%d%d%d%d%d", y1, x1, y2, x2, y3, x3)
  }
}
