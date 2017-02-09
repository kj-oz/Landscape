//
//  Poi.swift
//  Landscape
//
//  Created by KO on 2017/01/10.
//  Copyright © 2017年 KO. All rights reserved.
//

import Foundation
import CoreLocation

/**
 * POIの種類
 */
enum PoiType {
  case mountain
  case building
  case userDefined
}

/**
 * POI
 */
class Poi {
  
  let name: String
  let group: String?
  let height: Double
  let location: CLLocationCoordinate2D
  let type: PoiType
  let famous: Bool
  var azimuth = 0.0
  var distance = 0.0
  var elevation = 0.0
  
  var debugString: String {
    let nameStr = group != nil ? "\(name)(\(group!))" : "\(name)"
    let locStr = "\(location.longitude)/\(location.latitude)"
    return "\(nameStr), \(locStr), \(height), \(distance), \(azimuth), \(elevation)"
  }
  
  init(name: String, group: String?, height: Double,
       location: CLLocationCoordinate2D, type: PoiType, famous: Bool) {
    self.name = name
    self.group = group
    self.height = height
    self.location = location
    self.type = type
    self.famous = famous
  }
  
  func calcVector(from: CLLocationCoordinate2D) {
    (distance, azimuth) = calcDistanceAndAngle(from: from, to: location)
    elevation = height / distance
  }
  
  func isInside(fromAzimuth: Double, toAzimuth: Double) -> Bool {
    var result = false
    if fromAzimuth < toAzimuth {
      result = fromAzimuth < azimuth && azimuth < toAzimuth
    } else {
      result = fromAzimuth < azimuth || azimuth < toAzimuth
    }
    // print("isInside: \(fromAzimuth) - \(toAzimuth)  \(azimuth) \(result)")
    return result
  }
  
  func angle(from: Poi) -> Double {
    return angle(from: from.azimuth)
//    var diff = to.azimuth - azimuth
//    if diff > 180.0 {
//      diff = diff - 360
//    } else if diff < -180.0 {
//      diff = diff + 360
//    }
//    return diff
  }
  
  func angle(from: Double) -> Double {
    var diff = azimuth - from
    if diff > 180.0 {
      diff = diff - 360
    } else if diff < -180.0 {
      diff = diff + 360
    }
    return diff
  }
}

/**
 * POIを管理するオブジェクト
 */
class PoiManager {
  let minElevation = 0.01
  let maxDistance = 100000.0
  var poiList: [Poi] = []
  var candidates: [Poi] = []
  var includeHiddenPoi = false
  
  init() {
    loadPois()
  }
  
  /**
   * 与えれれた現在地から各POIへのベクトルを計算する。計算結果の仰角が0.01以下の山、建物は除外される
   * 
   * - parameter position: 現在地の緯度経度
   */
  func setCurrentPosition(position: CLLocationCoordinate2D) {
    print("origin: \(position.longitude)/\(position.latitude)")
    
    var pois = poiList.filter({
      $0.calcVector(from: position)
      // print($0.debugString)
      if $0.type == .userDefined {
        return true
      }
      if $0.elevation < minElevation {
        return false
      }
      if !$0.famous && $0.distance > maxDistance {
        return false
      }
      return true
    })
    print("elevation filter: \(pois.count)")
    
    pois.sort(by: { $0.height < $1.height })
    if !includeHiddenPoi {
      let start = Date()
      candidates = []
      targets: for i in 0 ..< pois.count - 1 {
        if pois[i].type == .userDefined {
          continue
        }
        for j in i + 1 ..< pois.count {
          if pois[j].type != .mountain {
            continue
          }
          let angle = abs(pois[i].angle(from: pois[j]))
          // 山の斜面の勾配が1/2とし、且つ tanθ ≒ θ　と見做して隠れるかどうか判定
          if angle < pois[j].elevation * 2 &&
              pois[i].elevation < pois[j].elevation - angle * 0.5 {
            // 隠す
            print("\(pois[i].name) is hidden by \(pois[j].name)")
            print("  \(pois[i].debugString)")
            print("  \(pois[j].debugString)")
           continue targets
          }
        }
        candidates.insert(pois[i], at: 0)
      }
      print("elapsed: \(Date().timeIntervalSince(start))")
      print("hidden filter: \(candidates.count)")
    } else {
      candidates = pois
    }
  }
  
  /**
   *
   *
   * - parameter startAzimuth:
   * - parameter endAzimuth:
   * - returns 指定の角度の間に入っていて、仰角が0.01以上あるいはユーザーが登録したPOIが仰角の大きな順にならんだ配列
   */
  func getVisiblePois(startAzimuth: Double, endAzimuth: Double) -> [Poi] {
    let filtered = candidates.filter({ $0.isInside(fromAzimuth: startAzimuth, toAzimuth: endAzimuth) })
    print("angle filtered: \(filtered.count) (\(startAzimuth) - \(endAzimuth))")
    return filtered
  }
  
  func loadPois() {
    poiList = []
    
    let docDir = FileUtil.documentDir
    let path = docDir.appending("/mountain.csv")
    let lines = FileUtil.readLines(path: path)
    
    var first = true
    for line in lines {
      if first {
        first = false
      } else {
        let parts = line.components(separatedBy: ",")
        let group = parts[2].isEmpty ? nil : parts[2]
        let coord = CLLocationCoordinate2D(latitude: CLLocationDegrees(parts[4])!,
                                           longitude: CLLocationDegrees(parts[5])!)
        let famous = !parts[6].isEmpty
        let poi = Poi(name: parts[0], group: group, height: Double(parts[3])!,
                      location: coord, type: .mountain, famous: famous)
        poiList.append(poi)
      }
      
    }
  }
}

