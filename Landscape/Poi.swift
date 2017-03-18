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
  case island
  case building
  case city
  case userDefined
}

protocol LabelSource {
  var name: String { get }
  var type: PoiType { get }
  var height: Double { get }
  var azimuth: Double { get }
  var distance: Double { get }
}

class PoiGroup: Hashable, LabelSource {
  static func == (lhs: PoiGroup, rhs: PoiGroup) -> Bool {
    return lhs.name == rhs.name
  }
  
  let name: String
  var poi: Poi!
  var height = 0.0
  lazy var label: Label = Label(of: self)
  
  var hashValue: Int {
    return name.hashValue
  }
  
  var type: PoiType {
    return poi.type
  }
  
  var azimuth: Double {
    return poi.azimuth
  }
  
  var distance: Double {
    return poi.distance
  }
  
  init(name: String) {
    self.name = name
  }
}

/**
 * POI
 */
class Poi: LabelSource {
  
  let name: String
  let detail: String?
  let group: PoiGroup?
  let height: Double
  let location: CLLocationCoordinate2D
  let type: PoiType
  let famous: Bool
  var azimuth = 0.0
  var distance = 0.0
  lazy var label: Label = Label(of: self)

  
  var debugString: String {
    let nameStr = group != nil ? "\(name)(\(group!))" : "\(name)"
    let locStr = "\(location.longitude)/\(location.latitude)"
    return "\(nameStr), \(locStr), \(height), \(distance), \(azimuth)"
  }
  
  init(name: String, detail: String?, group: PoiGroup?, height: Double,
       location: CLLocationCoordinate2D, type: PoiType, famous: Bool) {
    self.name = name
    self.detail = detail
    self.group = group
    self.height = height
    self.location = location
    self.type = type
    self.famous = famous
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
    return Landscape.angle(from: from.azimuth, to: azimuth)
  }
}

/**
 * POIを管理するオブジェクト
 */
class PoiManager {
  let minElevation = 0.01
  let maxDistance = 50_000.0
  var pois: [Poi] = []
  var candidates: [Poi] = []
  var groups: [String : PoiGroup] = [:]
  
  
  var currentPosition: CLLocation? {
    didSet {
      let position = currentPosition!
      print(String(format:"現在地: %.3f / %.3f / %.0f",
                   position.coordinate.longitude, position.coordinate.latitude, position.altitude))
      checker.currentLocation = position
      if checker.memLoaded {
        candidates = pois.filter({
          checker.calcVector(of: $0)
          if $0.type == .userDefined {
            return true
          }
          return checker.checkVisibility(of: $0)
        })
        print("elevation filter: \(candidates.count)")
        notLoaded = false
      } else {
        notLoaded = true
      }
    }
  }
  
  private var checker: VisiblityChecker
  
  private var notLoaded = false
  
  init() {
    checker = VisiblityChecker()
    loadPois()
  }
  
  /**
   *
   *
   * - parameter startAzimuth:
   * - parameter endAzimuth:
   * - returns 指定の角度の間に入っていて、仰角が0.01以上あるいはユーザーが登録したPOIが仰角の大きな順にならんだ配列
   */
  func getVisiblePois(startAzimuth: Double, endAzimuth: Double) -> [Poi] {
    if notLoaded {
      currentPosition = checker.currentLocation!
    }
    let filtered = candidates.filter({ $0.isInside(fromAzimuth: startAzimuth, toAzimuth: endAzimuth) })
    //print("angle filtered: \(filtered.count) (\(startAzimuth) - \(endAzimuth))")
    return filtered
  }
    
  func loadPois() {
    pois = []
    
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
        let groupName = parts[5].isEmpty ? nil : parts[5]
        let height = Double(parts[6])!
        
        var group: PoiGroup?
        if let groupName = groupName {
          if let g = groups[groupName] {
            group = g
            group!.height = max(height, group!.height)
          } else {
            group = PoiGroup(name: groupName)
            group!.height = height
            groups[groupName] = group!
          }
        }

        let coord = CLLocationCoordinate2D(latitude: CLLocationDegrees(parts[7])!,
                                           longitude: CLLocationDegrees(parts[8])!)
        let famous = !parts[11].isEmpty
        let detail = parts[2] + "," + parts[3] + "," + parts[4] + "," +
            parts[9] + "," + parts[10] + "," + parts[11]
        let poi = Poi(name: parts[1], detail: detail, group: group, height: height,
                      location: coord, type: .mountain, famous: famous)
        pois.append(poi)
        
      }
      
    }
  }
}

