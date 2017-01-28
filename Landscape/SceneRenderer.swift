//
//  SceneManager.swift
//  Landscape
//
//  Created by KO on 2017/01/04.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit
import CoreLocation

// ラベルに表示する文字サイズ
private let labelFontSize: CGFloat = 12.0

// ラベルの文字と枠間のパディング
private let labelPadding: CGFloat = 3.0

// ラベルの間隔
private let labelSpacing: CGFloat = 4.0

// 画角の1/2のタンジェント
private var tanFA_2: Double = 0.0

private var w_2: CGFloat = 0.0

class Label {
  let poi: Poi
  let center: CGFloat
  let width: CGFloat
  let left: CGFloat = 0.0
  
  init(poi: Poi) {
    self.poi = poi
    center = w_2 * CGFloat(1 + tan(toRadian(poi.azimuth)) / tanFA_2)
    width = poi.name.size(attributes:
      [NSFontAttributeName: UIFont.systemFont(ofSize: labelFontSize)]).width + 2 * labelPadding
  }
}

class SceneRenderer: NSObject, CALayerDelegate {
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
  private let rowCount = 8
  
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
  
  // 画面のサイズ
  private var size = CGSize.zero
  
  // 描画対象のレイヤ
  private var layer: CALayer?
  
  // 描画コンテキスト
  private var context: CGContext?
  
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
      [NSFontAttributeName: UIFont.systemFont(ofSize: labelFontSize)]).height + 2 * labelPadding
    
    tickCount = Int(360.0 / tickDegree)
    tickPerDir = tickCount / directions.count
  }
  
  private func setupViewParameter() {
    fieldAngle = size.width > size.height ? fieldAngleH : fieldAngleV
    tanFA_2 = tan(toRadian(fieldAngle / 2.0))
    w_2 = size.width / 2
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
    let pois = poiManager.getVisiblePois(startAzimuth: startAngle, endAzimuth: endAngle)
    let rows = self.createRows(pois: pois)
    
    ctx.setStrokeColor(labelFontColor)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    let attrs = [NSFontAttributeName: UIFont.systemFont(ofSize: labelFontSize), NSParagraphStyleAttributeName: paragraphStyle]
    
    for (index, row) in rows.enumerated() {
      let y = labelSpacing + (labelHeight + labelSpacing) * CGFloat(index)
      for label in row {
        let color = getPoiColor(type: label.poi.type)
        ctx.setFillColor(color)
        ctx.fill(CGRect(x: label.left, y: y, width: label.width, height: labelHeight))
        ctx.fill(CGRect(x: label.center - labelLineWidth * 0.5, y: y + labelHeight,
                        width: labelLineWidth, height: labelLineLength))
        
        label.poi.name.draw(with: CGRect(x: label.left + labelPadding, y: y + labelPadding,
                                         width: label.width, height: labelHeight),
                            options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
      }
    }
    
    // デバッグ出力
    //    let rect3 = CGRect(x: 40, y: 40, width: size.width - 100, height: size.height - 100)
    //    ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 0.5)
    //    ctx.fill(rect3)
    //    
    //    ctx.setStrokeColor(UIColor.black.cgColor)
    //    var string = "size: \(size)\n"
    //    string += "layer size: \(layer.bounds)\n"
    //    string += "layer postion: \(layer.position)\n"
    //    string += "layer scale: \(layer.contentsScale)\n"
    //    string += "view: \(cameraView?.bounds)\n"
    //    string += "heading: \(headingAngle)\n"
    //    string += "fieldAngle: \(fieldAngle)\n"
    //  
    //    string.draw(with: CGRect(x: 50, y: 50, width: 200, height: 200), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    
    UIGraphicsPopContext()
    ctx.restoreGState()
  }
  
  private func getPoiColor(type: PoiType) -> CGColor {
    switch type {
    case .mountain:
      return UIColor.green.cgColor
    case .building:
      return UIColor.darkGray.cgColor
    case .userDefined:
      return UIColor.orange.cgColor
    }
  }
  
  private func drawDirection(tickIndex: Int) {
    var angle = Double(tickIndex) * tickDegree - heading!
    if angle < -180 {
      angle += 360
    } else if angle > 180 {
      angle -= 360
    }
    let w_2 = size.width / 2
    let x = w_2 * CGFloat(1 + tan(toRadian(angle)) / tanFA_2)
    
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
  
  private func createRows(pois: [Poi]) -> [[Label]] {
    return [[]]
  }
}

