//
//  DirectionRenderer.swift
//  Landscape
//
//  Created by KO on 2017/02/14.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit

/// 方位の描画を司るクラス
class DirectionRenderer {
  
  /// 方位文字列
  private let directions = ["北", "北北東", "北東", "東北東",
                            "東", "東南東", "南東", "南南東",
                            "南", "南南西", "南西", "西南西",
                            "西", "西北西", "北西", "北北西"]
  
  /// 方位文字列の描画済み画像（高速化のため）
  private var dirImages: [UIImage] = []
  
  /// 方位文字列のフォント（大）
  private let dirFont1 = UIFont.systemFont(ofSize: 16)
  
  /// 方位文字列のフォント（中）
  private let dirFont2 = UIFont.systemFont(ofSize: 14)
  
  /// 方位文字列のフォント（小）
  private let dirFont3 = UIFont.systemFont(ofSize: 12)
  
  /// 方位目盛りの間隔（度）
  private let tickPitch = 1.5
  
  /// 方位表示部の高さ
  private let bandHeight: CGFloat = 30.0
  
  /// 方位表示部の色
  private let bandColor = UIColor.white.cgColor
  
  /// 方位文字のある場所の目盛りの長さ
  private let longTickLength: CGFloat = 12.0
  
  /// 方位目盛りの長さ
  private let shortTickLength: CGFloat = 6.0
  
  /// 目盛りの総数
  private let tickCount: Int
  
  /// 一方位当たりの目盛り数
  private var tickPerDir: Int
  
  /// 方位文字列の幅
  private let dirWidth: CGFloat = 60.0
  
  /// 方位文字列の高さ
  private let dirHeight: CGFloat
  
  /// 方位文字の余白
  private let dirSpacing: CGFloat = 2.0
  
  
  /// コンストラクタ
  init() {
    tickCount = Int(360.0 / tickPitch)
    tickPerDir = tickCount / directions.count
    dirHeight = bandHeight - longTickLength
    
    createImages()
  }
  
  /// 高速化のために予め方位文字列の画像を作成しておく
  private func createImages() {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    var attrs = [NSAttributedStringKey.paragraphStyle: paragraphStyle] as [NSAttributedStringKey : Any]
    for i in 0 ..< directions.count {
      let label = directions[i]
      let font: UIFont
      switch label.count {
      case 1:
        font = dirFont1
      case 2:
        font = dirFont2
      default:
        font = dirFont3
      }
      attrs[NSAttributedStringKey.font] = font
      
      let rect = CGRect(x: 0, y: 0, width: dirWidth, height: dirHeight)
      UIGraphicsBeginImageContext(rect.size)
      let context = UIGraphicsGetCurrentContext()!
      context.translateBy(x: 0.0, y: dirHeight)
      context.scaleBy(x: 1.0, y: -1.0)
      
      // bitmapを塗りつぶし
      context.setFillColor(UIColor.white.cgColor)
      context.fill(rect)
      
      UIGraphicsPushContext(context)
      label.draw(with: CGRect(x: 0, y: dirHeight - dirSpacing - font.pointSize,
                              width: dirWidth, height: dirHeight),
                 options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
      UIGraphicsPopContext()
      
      let image = UIGraphicsGetImageFromCurrentImageContext()!
      dirImages.append(image)
      
      UIGraphicsEndImageContext()
    }
  }
  
  /// 方位目盛りバンドを描画する
  ///
  /// - Parameter params: 描画用パラメータ
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
  
  /// 一つの方位目盛りを描画する
  ///
  /// - Parameters:
  ///   - tickIndex: 目盛りの番号（北＝0°が0、最大239）
  ///   - params: 描画用パラメータ
  private func drawTick(tickIndex: Int, params: RenderingParams) {
    let azimuth = Double(tickIndex) * tickPitch
    let x = params.calcX(of: azimuth)
    let ctx = params.context!
    
    if tickIndex % tickPerDir == 0 {
      let image = dirImages[tickIndex / tickPerDir]
      let rect = CGRect(x: x - dirWidth / 2, y: params.height - bandHeight,
                        width: dirWidth, height: dirHeight)
      ctx.draw(image.cgImage!, in: rect)
      
      // 長目の目盛り　＋　文字列
      ctx.strokeLineSegments(between:
        [CGPoint(x: x, y: params.height - longTickLength), CGPoint(x: x, y: params.height)])
    } else {
      // 短めの目盛り
      ctx.strokeLineSegments(between:
        [CGPoint(x: x, y: params.height - shortTickLength), CGPoint(x: x, y: params.height)])
    }
  }
}
