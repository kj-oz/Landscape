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
  let detail: String?
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
  
  init(name: String, detail: String?, group: String?, height: Double,
       location: CLLocationCoordinate2D, type: PoiType, famous: Bool) {
    self.name = name
    self.detail = detail
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
  let maxDistance = 50_000.0
  var poiList: [Poi] = []
  var candidates: [Poi] = []
  var groups: [String : Double] = [:]
  
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
    
    candidates = poiList.filter({
      $0.calcVector(from: position)
      // print($0.debugString)
      if $0.type == .userDefined {
        return true
      }
      if $0.elevation < minElevation {
        return false
      }
      if !$0.famous && $0.group == nil && $0.distance > maxDistance {
        return false
      }
      return true
    })
    print("elevation filter: \(candidates.count)")
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
  
  func getHeight(of group: String) -> Double? {
    return groups[group]
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
        if parts[11] == "☓" {
          continue
        }
        let group = parts[5].isEmpty ? nil : parts[5]
        let coord = CLLocationCoordinate2D(latitude: CLLocationDegrees(parts[7])!,
                                           longitude: CLLocationDegrees(parts[8])!)
        let famous = !parts[11].isEmpty
        let detail = parts[2] + "," + parts[3] + "," + parts[4] + "," +
          parts[9] + "," + parts[10] + "," + parts[11]
        let poi = Poi(name: parts[1], detail: detail, group: group, height: Double(parts[6])!,
                      location: coord, type: .mountain, famous: famous)
        poiList.append(poi)
        
        if let group = group {
          if let height = groups[group] {
            if poi.height > height {
              groups[group] = poi.height
            }
          } else {
            groups[group] = poi.height
          }
        }
      }
      
    }
  }
}

