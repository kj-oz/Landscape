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
  let height: Double
  let location: CLLocationCoordinate2D
  let type: PoiType
  var azimuth = 0.0
  var distance = 0.0
  var elevation = 0.0
  
  init(name: String, height: Double, location: CLLocationCoordinate2D, type: PoiType) {
    self.name = name
    self.height = height
    self.location = location
    self.type = type
  }
  
  func calcVector(from origin: CLLocationCoordinate2D) {
    
  }
  
  func isInside(fromAzimuth: Double, toAzimuth: Double) -> Bool {
    if fromAzimuth < toAzimuth {
      return fromAzimuth < azimuth && azimuth < toAzimuth
    } else {
      return fromAzimuth < azimuth || azimuth < toAzimuth
    }
  }
}

/**
 * POIを管理するオブジェクト
 */
class PoiManager {
  let minElevation = 0.01
  var poiList: [Poi] = []
  
  
  
  /**
   * 
   * 
   * - parameter position: 現在地の緯度経度
   */
  func setCurrentPosition(position: CLLocationCoordinate2D) {
    for poi in poiList {
      poi.calcVector(from: position)
    }
  }
  
  /**
   *
   *
   * - parameter startAzimuth:
   * - parameter endAzimuth:
   * - returns 指定の角度の間に入っていて、仰角が0.01以上かあるいはユーザーが登録したPOIの配列
   */
  func getVisiblePois(startAzimuth: Double, endAzimuth: Double) -> [Poi] {
    return poiList.filter({
      if $0.type != .userDefined && $0.elevation < minElevation {
        return false
      }
      if !$0.isInside(fromAzimuth: startAzimuth, toAzimuth: endAzimuth) {
        return false
      }
      return true
    })
  }
}

