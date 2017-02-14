//
//  SceneManager.swift
//  Landscape
//
//  Created by KO on 2017/01/04.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit
import CoreLocation

class SceneRenderer: NSObject, CALayerDelegate {
  // 画角の1/2のタンジェント
  static var tanFA_2: Double = 0.0
  
  static var w_2: CGFloat = 0.0
  
  // 方位文字列
  private let directions = ["北", "北北東", "北東", "東北東",
                            "東", "東南東", "南東", "南南東",
                            "南", "南南西", "南西", "西南西",
                            "西", "西北西", "北西", "北北西"]
  
  // 方位目盛りの間隔（度）
  let tickDegree = 1.5
  
  // 方位表示部の高さ
  private let dirBarHeight: CGFloat = 30.0
  
  // 
  private let dirBandColor = UIColor.white.cgColor
  
  private let dirFontColor = UIColor.black.cgColor
  
  // 方位文字のある場所の目盛りの長さ
  private let longTickLength: CGFloat = 12.0
  
  // 方位目盛りの長さ
  private let tickLength: CGFloat = 6.0

  // 目盛りの総数
  private var tickCount = 0
  
  // 一方位当たりの目盛り数
  private var tickPerDir = 0
  
  // POIの管理オブジェクト
  private let poiManager = PoiManager()
  
  // ラベルの行数
  private var rowCount = 0
  
  // ラベルの行数
  private var rowStartHeight: CGFloat = 0.0
  
  // ラベルの高さ
  private var labelHeight: CGFloat = 0.0
  
  // ラベルの高さ
  private let labelFontColor = UIColor.white.cgColor
  
  // 
  private let labelLineWidth: CGFloat = 2.0
  
  private var labelLineEndHeight: CGFloat = 0.0

  // 長辺方向の画角
  private var fieldAngleH = 0.0
  
  // 短辺方向の画角
  private var fieldAngleV = 0.0

  // デバイスの背面の向き
  private var heading: Double?
  
  // 水平方向の画角
  private var fieldAngle = 0.0
  
  private let angleMargin = 3.0
  
  // 画面のサイズ
  private var size = CGSize.zero
  
  private var portrait = true
  
  // 描画対象のレイヤ
  private var layer: CALayer?
  
  // 描画コンテキスト
  private var context: CGContext?
  
  private var rows: [LabelRow] = []
  
  private var selectedGroup: String?
  
  private var selectedPoi: Poi?
  
  /**
   * コンストラクタ
   *
   * - parameter layer: 描画対象レイヤ
   */
  init(layer: CALayer) {
    super.init()
    
    self.layer = layer
    layer.delegate = self
    size = layer.frame.size

    setupConstant(size: size)
    setupViewParameter()
  }
  
  func updateLocation(location: CLLocationCoordinate2D) {
    // 対象POIの再計算
    poiManager.setCurrentPosition(position: location)
    
    layer!.setNeedsDisplay()
  }
  
  
  func updateHeading(heading: Double) {
    self.heading = heading
    
    layer!.setNeedsDisplay()
  }
  
  func changeOrientation(to size: CGSize) {
    self.size = size
    self.layer!.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
    setupViewParameter()
    
    layer!.setNeedsDisplay()
  }
  
  private func setupConstant(size: CGSize) {
    let h = Double(max(size.width, size.height))
    let v = Double(min(size.width, size.height))
    fieldAngleH = getFieldAngle()
    fieldAngleV = toDegree(atan(v / h * tan(toRadian(fieldAngleH / 2.0)))) * 2.0
    
    labelHeight = "国".size(attributes:
      [NSFontAttributeName: UIFont.systemFont(ofSize: Label.fontSize)]).height + 2 * Label.padding
    
    tickCount = Int(360.0 / tickDegree)
    tickPerDir = tickCount / directions.count
  }
  
  private func setupViewParameter() {
    if size.width > size.height {
      portrait = false
      fieldAngle = fieldAngleH
      rowCount = 5
      rowStartHeight = Label.spacing
    } else {
      portrait = true
      fieldAngle = fieldAngleV
      rowCount = 7
      rowStartHeight = 20.0 + Label.spacing
    }
    SceneRenderer.tanFA_2 = tan(toRadian(fieldAngle / 2.0))
    SceneRenderer.w_2 = size.width / 2
    labelLineEndHeight = size.height * 0.45
  }
  
  func tapped(at point: CGPoint) {
    if let label = findLabel(at: point) {
      if label.group {
        selectedGroup = label.poi.group
        selectedPoi = nil
      } else {
        selectedPoi = label.poi
      }
    } else {
      if selectedPoi != nil {
        selectedPoi = nil
      } else {
        selectedGroup = nil
      }
    }
    layer!.setNeedsDisplay()
  }
  
  
  func draw(_ layer: CALayer, in ctx: CGContext) {
    if heading == nil {
      return
    }
    
    ctx.saveGState()
    UIGraphicsPushContext(ctx)
    context = ctx
    
    // 描画範囲
    var startAngle = heading! - fieldAngle * 0.5
    if startAngle < 0 {
      startAngle += 360
    }
    var endAngle = heading! + fieldAngle * 0.5
    if endAngle > 360 {
      endAngle -= 360
    }
    
    // 方位の描画
    let rect = CGRect(x: 0, y: size.height - dirBarHeight, width: size.width, height: dirBarHeight)
    ctx.setFillColor(dirBandColor)
    ctx.fill(rect)
    
    ctx.setStrokeColor(dirFontColor)
    let startIndex = Int(startAngle / tickDegree) + 1
    let endIndex = Int(endAngle / tickDegree)
    if startAngle < endAngle {
      for i in startIndex ... endIndex {
        drawDirection(tickIndex: i)
      }
    } else {
      for i in 0 ... endIndex {
        drawDirection(tickIndex: i)
      }
      for i in startIndex ..< tickCount {
        drawDirection(tickIndex: i)
      }
    }
    
    // POIの描画
    var startAzimuth = startAngle + angleMargin
    if startAzimuth > 360.0 {
      startAzimuth -= 360.0
    }
    var endAzimuth = endAngle - angleMargin
    if endAzimuth < 0 {
      endAzimuth += 360.0
    }

    let pois = poiManager.getVisiblePois(startAzimuth: startAzimuth, endAzimuth: endAzimuth)
    rows = self.createRows(pois: pois)
    drawPois()
    
    
    // デバッグ出力
    if let poi = selectedPoi {
      var y = size.height - (portrait ? 200 : 165)
      let rect = CGRect(x: 40, y: y, width: size.width - 80, height: portrait ? 150 : 115)
      ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 0.5)
      ctx.fill(rect)
      
      let details = poi.detail!.components(separatedBy: ",")
      
      var attrs = [NSFontAttributeName: UIFont.systemFont(ofSize: 16),
                   NSForegroundColorAttributeName: UIColor.black]
      var string = "\(poi.name)　\(details[0])"
      y += 5;
      string.draw(with: CGRect(x: 45, y: y, width: size.width - 90, height: 20), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)

      attrs[NSFontAttributeName] = UIFont.systemFont(ofSize: 14)
      string = ""
      if !details[1].isEmpty {
        string += "別名　　：\(details[1])　\(details[2])\n"
      }
      string += "標高　　：\(String(format: "%.0f", poi.height)) m\n"
      string += "緯度経度：北緯 \(String(format: "%.2f", poi.location.latitude)) 度"
      string += portrait ? "\n　　　　　" : "　"
      string += "東経 \(String(format: "%.2f", poi.location.longitude)) 度\n"
      string += "山域　　：\(details[4])"
      string += portrait ? "\n　　　　　" : "　"
      string += "（\(details[3])）\n"
      if !details[5].isEmpty {
        string += "その他　：\(details[5])\n"
      }
      y += 20;
      string.draw(with: CGRect(x: 60, y: y, width: size.width - 90, height: portrait ? 125 : 90), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    }
    
    UIGraphicsPopContext()
    ctx.restoreGState()
  }
  
  private func getColor(of label: Label) -> CGColor {
    switch label.height {
    case 0 ..< 1000:
      return UIColor(red: 0, green: 0.8, blue:1, alpha: 1).cgColor
    case 1000 ..< 1500:
      return UIColor(red: 0.5, green: 1, blue:0.8, alpha: 1).cgColor
    case 1500 ..< 2000:
      return UIColor(red: 0.7, green: 1, blue:0.1, alpha: 1).cgColor
    case 2000 ..< 2500:
      return UIColor.yellow.cgColor
    case 2500 ..< 3000:
      return UIColor.orange.cgColor
    default:
      return UIColor.red.cgColor
    }
  }
  
  private func drawDirection(tickIndex: Int) {
    var angle = Double(tickIndex) * tickDegree - heading!
    if angle < -180 {
      angle += 360
    } else if angle > 180 {
      angle -= 360
    }
    let x = SceneRenderer.w_2 * CGFloat(1 + tan(toRadian(angle)) / SceneRenderer.tanFA_2)
    
    if tickIndex % tickPerDir == 0 {
      let label = directions[tickIndex / tickPerDir]
      var fontSize: CGFloat = 0.0
      switch label.characters.count {
      case 1:
        fontSize = 16.0
      case 2:
        fontSize = 14.0
      default:
        fontSize = 12.0
      }
      
      let paragraphStyle = NSMutableParagraphStyle()
      paragraphStyle.alignment = .center
      let attrs = [NSFontAttributeName: UIFont.systemFont(ofSize: fontSize), NSParagraphStyleAttributeName: paragraphStyle]
      
      // 長目の目盛り　＋　文字列
      context!.strokeLineSegments(between:
        [CGPoint(x: x, y: size.height - longTickLength), CGPoint(x: x, y: size.height)])
      label.draw(with: CGRect(x: x - 30, y: size.height - longTickLength - fontSize - 4, width: 60, height: 18), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    } else {
      // 短めの目盛り
      context!.strokeLineSegments(between:
        [CGPoint(x: x, y: size.height - tickLength), CGPoint(x: x, y: size.height)])
    }
  }
  
  private func getFieldAngle() -> Double {
    return 62.0
  }
  
  private func createRows(pois: [Poi]) -> [LabelRow] {
    print("■view: w \(size.width)")
    var rows: [LabelRow] = []
    let depth = labelLineEndHeight - (labelHeight + Label.spacing) * CGFloat(rowCount)
    for i in 0 ..< rowCount {
      rows.append(LabelRow(length: size.width,
                           depth: depth + CGFloat(i) * (labelHeight + Label.spacing)))
    }
    var groups = Set<String>()
    var labels: [Label] = []
    for poi in pois {
      let label: Label
      if let selectedGroup = selectedGroup {
        if poi.group != selectedGroup {
          continue
        }
        label = Label(poi: poi, group: false, groupHeight: nil, heading: heading!)
      } else if let group = poi.group {
        if groups.contains(group) {
          continue
        }
        label = Label(poi: poi, group: true,
                        groupHeight: poiManager.getHeight(of: group), heading: heading!)
        groups.insert(group)
      } else {
        label = Label(poi: poi, group: false, groupHeight: nil, heading: heading!)
      }
      labels.append(label)
      // print("label: \(label.text) \(poi.azimuth) c:\(label.point) w:\(label.width)")
    }
    labels.sort(by: { $0.poi.distance < $1.poi.distance})
    
    var startRow = 0
    labels: for label in labels {
      for i in startRow ..< rows.count {
        if rows[i].insert(label: label) {
          startRow = i
          continue labels
        }
      }
      print("missed label: \(label.text) (\(label.height))")
    }
    if startRow < rows.count - 1 {
      rows.removeLast()
    }
    rows.reverse()
    return rows
  }
  
  private func drawPois() {
    let ctx = context!
    ctx.setStrokeColor(labelFontColor)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    var attrs = [NSFontAttributeName: UIFont.systemFont(ofSize: Label.fontSize),
                 NSParagraphStyleAttributeName: paragraphStyle,
                 NSForegroundColorAttributeName: UIColor.black]
    
    var lineSpacing = Label.spacing
    if rows.count < rowCount {
      lineSpacing += (Label.spacing + labelHeight) / CGFloat(rows.count)
    }

    for (index, row) in rows.enumerated() {
      if row.labels.count == 0 {
        continue
      }
      // print("ROW-\(index)")
      let y = rowStartHeight + (labelHeight + lineSpacing) * CGFloat(index)
      for label in row.labels {
        let color = getColor(of: label)
        ctx.setFillColor(color)
        ctx.fill(CGRect(x: label.left, y: y, width: label.width, height: labelHeight))
        
        ctx.setStrokeColor(color)
        let x: CGFloat
        if label.point > label.right {
          x = label.right - 1
        } else if label.point < label.left {
          x = label.left + 1
        } else {
          x = label.point
        }
        ctx.setLineWidth(labelLineWidth)
        ctx.move(to: CGPoint(x: x, y: y + labelHeight))
        ctx.addLine(to: CGPoint(x: label.point, y: labelLineEndHeight))
        ctx.addLine(to: CGPoint(x: label.point, y: labelLineEndHeight + 15))
        ctx.strokePath()
        
        attrs[NSFontAttributeName] = UIFont.systemFont(ofSize: Label.fontSize)
        label.text.draw(with: CGRect(x: label.left, y: y + Label.padding,
                                     width: label.width, height: labelHeight),
                        options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
        // print("\(label.text): L \(label.left) W \(label.width) C \(label.point) E \(label.poi.elevation)")
      }
    }
  }
  
  private func findLabel(at point: CGPoint) -> Label? {
    var lineSpacing = Label.spacing
    if rows.count < rowCount {
      lineSpacing += (Label.spacing + labelHeight) / CGFloat(rows.count)
    }

    for (index, row) in rows.enumerated() {
      let y = rowStartHeight + (labelHeight + lineSpacing) * CGFloat(index)
      if point.y < y || point.y > y + labelHeight {
        continue
      }
      
      for label in row.labels {
        if point.x < label.left || point.x > label.right {
          continue
        }
        return label
      }
    }
    return nil
  }
}

