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
  private var rowCount = 8
  
  // ラベルの高さ
  private var labelHeight: CGFloat = 0.0
  
  // ラベルの高さ
  private let labelFontColor = UIColor.white.cgColor
  
  // 
  private let labelLineWidth: CGFloat = 2.0
  
  private let labelLineLength: CGFloat = 100.0

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
  
  // 描画対象のレイヤ
  private var layer: CALayer?
  
  // 描画コンテキスト
  private var context: CGContext?
  
  var expandGroup = false
  
  private var poiIndex = 0
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
    fieldAngle = size.width > size.height ? fieldAngleH : fieldAngleV
    SceneRenderer.tanFA_2 = tan(toRadian(fieldAngle / 2.0))
    SceneRenderer.w_2 = size.width / 2
    rowCount = size.width > size.height ? 6 : 8
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
    let rows = self.createRows(pois: pois)
    
    ctx.setStrokeColor(labelFontColor)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    var attrs = [NSFontAttributeName: UIFont.systemFont(ofSize: Label.fontSize),
                 NSParagraphStyleAttributeName: paragraphStyle,
                 NSForegroundColorAttributeName: UIColor.black]
    
    for (index, row) in rows.enumerated() {
      print("ROW-\(index)")
      poiIndex = 0
      let y = Label.spacing + (labelHeight + Label.spacing) * CGFloat(index)
      for label in row.labels {
        let color = getPoiColor(poi: label.poi)
        ctx.setFillColor(color)
        if label.group {
          ctx.fill(CGRect(x: label.left, y: y - 0.5, width: label.width, height: labelHeight + 1.0))
          ctx.fill(CGRect(x: label.center - 0.5, y: y + labelHeight + 0.5,
                          width: 1, height: labelLineLength))
          attrs[NSFontAttributeName] = UIFont.systemFont(ofSize: Label.fontSize + 1)
          (label.poi.group! + " ▶").draw(with: CGRect(x: label.left, y: y + Label.padding - 0.5,
                                           width: label.width, height: labelHeight),
                              options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
        } else {
          ctx.fill(CGRect(x: label.left, y: y + 0.5, width: label.width, height: labelHeight - 1.0))
          ctx.fill(CGRect(x: label.center - 0.5, y: y + labelHeight - 0.5,
                          width: 1, height: labelLineLength))
          attrs[NSFontAttributeName] = UIFont.systemFont(ofSize: Label.fontSize - 1)
          label.poi.name.draw(with: CGRect(x: label.left, y: y + Label.padding + 0.5,
                                           width: label.width, height: labelHeight),
                              options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
        }
        print("\(label.poi.name): L \(label.left) W \(label.width) C \(label.center) E \(label.poi.elevation)")
        poiIndex += 1
      }
    }
    
    // デバッグ出力
    let rect2 = CGRect(x: 40, y: size.height - 170, width: size.width - 80, height: 100)
    ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 0.5)
    ctx.fill(rect2)
    
    attrs = [NSFontAttributeName: UIFont.systemFont(ofSize: 12),
             NSForegroundColorAttributeName: UIColor.black]
    var string = ""
    string += "heading: \(heading)\n"
    string += "fieldAngle: \(fieldAngle)\n"
  
    string.draw(with: CGRect(x: 50, y: size.height - 160, width: size.width - 100, height: 80), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    
    UIGraphicsPopContext()
    ctx.restoreGState()
  }
  
  private func getPoiColor(poi: Poi) -> CGColor {
    switch poi.height {
    case 0 ..< 500:
      return UIColor(red: 0, green: 0.5, blue: 1, alpha: 1).cgColor
    case 500 ..< 1000:
      return UIColor.cyan.cgColor
    case 1000 ..< 1500:
      return UIColor.green.cgColor
    case 1500 ..< 2000:
      return UIColor(red: 0.75, green: 1, blue: 0, alpha: 1).cgColor
    case 2000 ..< 2500:
      return UIColor.yellow.cgColor
    case 2500 ..< 3000:
      return UIColor.orange.cgColor
    default:
      return UIColor.red.cgColor
    }
    
//    switch type {
//    case .mountain:
//      return UIColor.green.cgColor
//    case .building:
//      return UIColor.darkGray.cgColor
//    case .userDefined:
//      return UIColor.orange.cgColor
//    }
  }
  
  private func drawDirection(tickIndex: Int) {
    var angle = Double(tickIndex) * tickDegree - heading!
    if angle < -180 {
      angle += 360
    } else if angle > 180 {
      angle -= 360
    }
    SceneRenderer.w_2 = size.width / 2
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
    for _ in 0 ..< rowCount {
      rows.append(LabelRow(length: size.width))
    }
    var groups = Set<String>()
    for poi in pois {
      let label: Label
      if !expandGroup, let group = poi.group {
        if groups.contains(group) {
          continue
        } else {
          label = Label(poi: poi, group: true, heading: heading!)
          print("label: \(group) \(poi.azimuth) c:\(label.center) w:\(label.width)")
          groups.insert(group)
        }
      } else {
        label = Label(poi: poi, group: false, heading: heading!)
        print("label: \(poi.name) \(poi.azimuth) c:\(label.center) w:\(label.width)")
      }
      for row in rows {
        if row.insert(label: label) {
          break
        }
      }
    }
    
    return rows
    
  }
}

