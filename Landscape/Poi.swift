//
//  Poi.swift
//  Landscape
//
//  Created by KO on 2017/01/10.
//  Copyright © 2017年 KO. All rights reserved.
//

import Foundation
import CoreLocation

/// POIの種類
///
/// - mountain: 山岳
/// - island: 島
/// - building: 建物
/// - city: 町
/// - userDefined: ユーザー定義
enum PoiType {
  case mountain
  case island
  case building
  case city
  case userDefined
}

/// ラベル表示対象
protocol LabelSource {
  
  /// 名称
  var name: String { get }
  
  /// POIの種類
  var type: PoiType { get }
  
  /// 高さ
  var height: Double { get }
  
  /// 現在地から見た方位
  var azimuth: Double { get }
  
  /// 現在地からの距離（m)
  var distance: Double { get }
}

/// POIのグループ
class PoiGroup: Hashable, LabelSource {
  
  // Hashableを満たすための==演算子
  static func == (lhs: PoiGroup, rhs: PoiGroup) -> Bool {
    return lhs.name == rhs.name
  }
  
  // Hashable
  var hashValue: Int {
    return name.hashValue
  }
  
  /// グループ名
  let name: String
  
  /// 代表POI（見える範囲で一番高さの高いPOI）
  var poi: Poi!
  
  /// 代表POIの高さ
  var height = 0.0
  
  /// ラベル（必要になったタイミングで作成）
  lazy var label: Label = Label(of: self)
  
  /// 代表POIのタイプ
  var type: PoiType {
    return poi.type
  }
  
  /// 代表POIの方位
  var azimuth: Double {
    return poi.azimuth
  }
  
  /// 代表POIまでの距離
  var distance: Double {
    return poi.distance
  }
  
  
  /// コンストラクタ
  ///
  /// - Parameter name: グループ名
  init(name: String) {
    self.name = name
  }
}

/// POI
class Poi: LabelSource {
  
  /// 名称
  let name: String
  
  /// 詳細情報
  let detail: String?
  
  /// 所属するグループ
  let group: PoiGroup?
  
  /// 高さ
  let height: Double
  
  /// 座標
  let location: CLLocationCoordinate2D
  
  /// 種別
  let type: PoiType
  
  /// 有名な地点かどうか
  let famous: Bool
  
  /// 現在地からの方位
  var azimuth = 0.0
  
  /// 現在地からの距離
  var distance = 0.0
  
  /// ラベル（必要になったタイミングで作成）
  lazy var label: Label = Label(of: self)

  /// デバッグ用文字列
  var debugString: String {
    let nameStr = group != nil ? "\(name)(\(group!))" : "\(name)"
    let locStr = "\(location.longitude)/\(location.latitude)"
    return "\(nameStr), \(locStr), \(height), \(distance), \(azimuth)"
  }
  
  /// コンストラクタ
  ///
  /// - Parameters:
  ///   - name: 名称
  ///   - detail: 詳細情報
  ///   - group: グループ名
  ///   - height: 高さ
  ///   - location: 座標
  ///   - type: 種別
  ///   - famous: 有名かどうか
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
  
  /// POIが与えられた方位の範囲に含まれるかどうかを判定する
  ///
  /// - Parameters:
  ///   - fromAzimuth: 画面向かって左端の方位
  ///   - toAzimuth: 画面向かって右端の方位
  /// - Returns: 画面の範囲に含まれているかどうか
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

/// POIを管理するオブジェクト
class PoiManager {
  
  /// 全てのPOI
  var pois: [Poi] = []
  
  /// 現在地から見える可能性のあるPOI
  var candidates: [Poi] = []
  
  /// POIグループのマップ
  var groups: [String : PoiGroup] = [:]
  
  /// 現在地の緯度経度、高度
  var currentPosition: CLLocation? {
    didSet {
      let position = currentPosition!
      checker.currentLocation = position
      if checker.memLoaded {
        let start = Date()
        candidates = pois.filter({
          checker.calcVector(of: $0)
          if $0.type == .userDefined {
            return true
          }
          return checker.checkVisibility(of: $0)
        })
        print("checkVisibility:\(Date().timeIntervalSince(start))")
        notLoaded = false
      } else {
        notLoaded = true
      }
    }
  }
  
  /// POIが現在地から見えるかどうかを判定するオブジェクト
  private var checker: VisiblityChecker
  
  /// 地形データが未ロードかどうか（未ロード=true、ロード済み=false）
  private var notLoaded = false
  
  
  /// コンストラクタ
  init() {
    checker = VisiblityChecker()
    loadPois()
  }
  
  /// POIの中から現在地から見える可能性のあるものだけを抜き出す
  ///
  /// - Parameters:
  ///   - startAzimuth: 画面左端の方位
  ///   - endAzimuth: 画面右端の方位
  /// - Returns: 現在地から見える可能性のあるPOIの中で指定の角度の間に入っているPOIの配列
  func getVisiblePois(startAzimuth: Double, endAzimuth: Double) -> [Poi] {
    if notLoaded {
      currentPosition = checker.currentLocation!
    }
    let filtered = candidates.filter({ $0.isInside(fromAzimuth: startAzimuth, toAzimuth: endAzimuth) })
    return filtered
  }
    
  /// 外部ファイルからPOIの情報を読み込む
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

