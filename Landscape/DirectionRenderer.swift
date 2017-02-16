//
//  DirectionRenderer.swift
//  Landscape
//
//  Created by KO on 2017/02/14.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit

class DirectionRenderer: NSObject {
  // 方位文字列
  private let directions = ["北", "北北東", "北東", "東北東",
                            "東", "東南東", "南東", "南南東",
                            "南", "南南西", "南西", "西南西",
                            "西", "西北西", "北西", "北北西"]
  
  // 方位目盛りの間隔（度）
  private let tickDegree = 1.5
  
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
  
  override init() {
    tickCount = Int(360.0 / tickDegree)
    tickPerDir = tickCount / directions.count
  }
  
  func drawDirections(params: RenderingParams) {
    let ctx = params.context!
    
    // 方位の描画
    let rect = CGRect(x: 0, y: params.height - dirBarHeight, width: params.width, height: dirBarHeight)
    ctx.setFillColor(dirBandColor)
    ctx.fill(rect)
    
    ctx.setStrokeColor(dirFontColor)
    let startIndex = Int(params.startAngle / tickDegree) + 1
    let endIndex = Int(params.endAngle / tickDegree)
    if params.startAngle < params.endAngle {
      for i in startIndex ... endIndex {
        drawTick(tickIndex: i, params: params)
      }
    } else {
      for i in 0 ... endIndex {
        drawTick(tickIndex: i, params: params)
      }
      for i in startIndex ..< tickCount {
        drawTick(tickIndex: i, params: params)
      }
    }
    
  }
  
  private func drawTick(tickIndex: Int, params: RenderingParams) {
    let azimuth = Double(tickIndex) * tickDegree
    let x = params.calcX(of: azimuth)
    
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
      params.context!.strokeLineSegments(between:
        [CGPoint(x: x, y: params.height - longTickLength), CGPoint(x: x, y: params.height)])
      label.draw(with: CGRect(x: x - 30, y: params.height - longTickLength - fontSize - 4, width: 60, height: 18), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    } else {
      // 短めの目盛り
      params.context!.strokeLineSegments(between:
        [CGPoint(x: x, y: params.height - tickLength), CGPoint(x: x, y: params.height)])
    }
  }
}
