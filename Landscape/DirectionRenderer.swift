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
  
  // 方位文字列のフォント
  private let dirFont1 = UIFont.systemFont(ofSize: 16)
  private let dirFont2 = UIFont.systemFont(ofSize: 14)
  private let dirFont3 = UIFont.systemFont(ofSize: 12)
  
  // 方位目盛りの間隔（度）
  private let tickPitch = 1.5
  
  // 方位表示部の高さ
  private let bandHeight: CGFloat = 30.0
  
  // 方位表示部の色
  private let bandColor = UIColor.white.cgColor
  
  // 方位文字のある場所の目盛りの長さ
  private let longTickLength: CGFloat = 12.0
  
  // 方位目盛りの長さ
  private let shortTickLength: CGFloat = 6.0
  
  // 目盛りの総数
  private let tickCount: Int
  
  // 一方位当たりの目盛り数
  private var tickPerDir: Int
  
  // 方位文字列の幅
  private let dirWidth: CGFloat = 60.0
  
  // 方位文字列の高さ
  private let dirHeight: CGFloat
  
  /**
   * コンストラクタ
   */
  override init() {
    tickCount = Int(360.0 / tickPitch)
    tickPerDir = tickCount / directions.count
    dirHeight = bandHeight - longTickLength
  }
  
  /**
   * 方位目盛りを描画する
   *
   * - parameter params 描画用パラメータ
   */
  func draw(params: RenderingParams) {
    let ctx = params.context!
    
    // 方位の描画
    let rect = CGRect(x: 0, y: params.height - bandHeight, width: params.width, height: bandHeight)
    ctx.setFillColor(bandColor)
    ctx.fill(rect)
    
    let startIndex = Int(params.startAngle / tickPitch) + 1
    let endIndex = Int(params.endAngle / tickPitch)
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
  
  /**
   * 一つの方位目盛りを描画する
   *
   * - parameter tickIndex 目盛りの番号（北＝0°が0、最大239）
   * - parameter params 描画用パラメータ
   */
  private func drawTick(tickIndex: Int, params: RenderingParams) {
    let azimuth = Double(tickIndex) * tickPitch
    let x = params.calcX(of: azimuth)
    
    if tickIndex % tickPerDir == 0 {
      let label = directions[tickIndex / tickPerDir]
      let font: UIFont
      switch label.characters.count {
      case 1:
        font = dirFont1
      case 2:
        font = dirFont2
      default:
        font = dirFont3
      }
      
      let paragraphStyle = NSMutableParagraphStyle()
      paragraphStyle.alignment = .center
      let attrs = [NSFontAttributeName: font,
                   NSParagraphStyleAttributeName: paragraphStyle] as [String : Any]
      
      // 長目の目盛り　＋　文字列
      params.context!.strokeLineSegments(between:
        [CGPoint(x: x, y: params.height - longTickLength), CGPoint(x: x, y: params.height)])
      label.draw(with: CGRect(x: x - dirWidth / 2,
                y: params.height - longTickLength - font.pointSize - 4, width: dirWidth,
                height: dirHeight), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    } else {
      // 短めの目盛り
      params.context!.strokeLineSegments(between:
        [CGPoint(x: x, y: params.height - shortTickLength), CGPoint(x: x, y: params.height)])
    }
  }
}
