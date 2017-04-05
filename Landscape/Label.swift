//
//  Label.swift
//  Landscape
//
//  Created by KO on 2017/01/28.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit
import CoreLocation

/// 画面上の地物の名称の表示
class Label {
  
  // ラベルに表示する文字サイズ
  static let font = UIFont.systemFont(ofSize: 12.0)
  
  // ラベルの文字と枠間のパディング
  static let padding: CGFloat = 3.0
  
  // ラベルの間隔
  static let spacing: CGFloat = 9.0
  
  // ラベルの高さ
  static let height = "国".size(attributes:
    [NSFontAttributeName: Label.font]).height + 2 * Label.padding
  
  // ラベルの色（山：高さ1000m以下）
  private let color0000_1000 = UIColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 1).cgColor
  
  // ラベルの色（山：高さ1000〜1500m）
  private let color1000_1500 = UIColor(red: 0.5, green: 1.0, blue: 0.8, alpha: 1).cgColor
  
  // ラベルの色（山：高さ1500〜2000m）
  private let color1500_2000 = UIColor(red: 0.7, green: 1.0, blue: 0.1, alpha: 1).cgColor
  
  // ラベルの色（山：高さ2000〜2500m）
  private let color2000_2500 = UIColor(red: 1.0, green: 0.9, blue: 0.1, alpha: 1).cgColor
  
  // ラベルの色（山：高さ2500〜3000m）
  private let color2500_3000 = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1).cgColor
  
  // ラベルの色（山：高さ3000m以上）
  private let color3000_ = UIColor(red: 0.8, green: 0.4, blue: 0.2, alpha: 1).cgColor
  
  // ラベルの色（建造物）
  private let colorBuilding = UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1).cgColor
  
  // ラベルの色（都市）
  private let colorCity = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1).cgColor
  
  // ラベルの色（ユーザー定義）
  private let colorSpecial = UIColor(red: 1.0, green: 0.0, blue: 1.0, alpha: 1).cgColor
  
  // ラベルの文字色
  private let fontColor = UIColor.black
  
  // ラベルの色
  var color: CGColor {
    switch source.type {
    case .mountain, .island:
      let height = source.height
      switch height {
      case 0 ..< 1000:
        return color0000_1000
      case 1000 ..< 1500:
        return color1000_1500
      case 1500 ..< 2000:
        return color1500_2000
      case 2000 ..< 2500:
        return color2000_2500
      case 2500 ..< 3000:
        return color2500_3000
      default:
        return color3000_
      }
    case .building:
      return colorBuilding
    case .city:
      return colorCity
    default:
      return colorSpecial
    }
  }

  // ラベルに表示する元データ
  let source: LabelSource

  // ラベルに表示する文字列
  let text: String
  
  // ラベルの画像
  var image: UIImage!

  // 対象地物の位置の画面への投影のx座標
  var point: CGFloat = 0.0
  
  // ラベルの枠長方形の幅
  let width: CGFloat
  
  // ラベルの左端のx座標
  var left: CGFloat = 0.0
  
  // ラベルの右端のx座標
  var right: CGFloat {
    return left + width
  }
  
  
  /// POIから生成するコンストラクタ
  ///
  /// - Parameter poi: 対象のPOI
  init(of poi: Poi) {
    self.source = poi
    text = poi.name
    width = text.size(attributes: [NSFontAttributeName: Label.font]).width + 2 * Label.padding
    image = createImage()
  }
  
  /// POIグループから生成するコンストラクタ
  ///
  /// - Parameter group: 対象のPOIグループからグループ
  init(of group: PoiGroup) {
    self.source = group
    text = group.name + " ▶"
    width = text.size(attributes: [NSFontAttributeName: Label.font]).width + 2 * Label.padding
    image = createImage()
  }
  
  /// ラベルのイメージを作成する
  ///
  /// - Returns: 作成されたイメージ画像
  private func createImage() -> UIImage {
    // ビットマップコンテキストを作成
    let rect = CGRect(x: 0, y: 0, width: width, height: Label.height)
    UIGraphicsBeginImageContext(rect.size)
    let context = UIGraphicsGetCurrentContext()!
    context.translateBy(x: 0.0, y: Label.height)
    context.scaleBy(x: 1.0, y: -1.0)
    
    // 塗りつぶし
    context.setFillColor(color)
    context.fill(rect)
    
    // 文字の記入
    UIGraphicsPushContext(context)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    let attrs = [NSFontAttributeName: Label.font,
                         NSParagraphStyleAttributeName: paragraphStyle,
                         NSForegroundColorAttributeName: fontColor]
    text.draw(with: CGRect(x: 0, y: Label.padding,
                                 width: width, height: Label.height),
                    options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    UIGraphicsPopContext()

    let image = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    return image
  }
}

/// 画面に表示する1行のラベル群
class LabelRow {
  
  // 画面の幅
  let length: CGFloat
  
  /// 自分の下端から引出線の折れ曲がり点までの高さ
  let depth: CGFloat
  
  /// 許容傾き（高さに対する水平方向の最大離れの比）
  let coef: CGFloat = 1.5

  // ラベルそのもの
  var labels: [Label] = []
  

  /// コンストラクタ
  ///
  /// - Parameters:
  ///   - length: 画面横のピクセル数
  ///   - depth: 行下端から引出線の折れ曲がり点までの高さ
  init(length: CGFloat, depth: CGFloat) {
    self.length = length
    self.depth = depth
  }
  
  /// 指定のラベルを行の中に挿入する
  ///
  /// - Parameter label: 対象のラベル
  /// - Returns: 挿入できた場合にtrue、挿入する余地が無かった場合にfalse
  func insert(label: Label) -> Bool {
    // 挿入位置の確定
    var index = 0
    for lb in labels {
      if lb.point > label.point {
        break
      }
      index += 1
    }
    
    // 片側で使用する可能性のある最大スペース（それ以上確保しても使えない）
    let maxSpace: CGFloat = depth * coef + label.width

    // 左側の最大スペースの確認
    var leftSpace: CGFloat = 0    // 現在ラベルの中心より左に空いているスペース
    var leftMargin: CGFloat = 0   // 左のラベルを移動することで確保可能なスペース
    if index > 0 {
      leftSpace = label.point - (labels[index - 1].right + Label.spacing)
      if leftSpace > maxSpace {
        leftSpace = maxSpace
      } else {
        leftMargin = estimateLeftShift(index: index - 1)
        if leftSpace + leftMargin < -depth * coef {
          // 左に最小限の余裕がない
          return false
        } else if leftSpace + leftMargin > maxSpace {
          leftMargin = maxSpace - leftSpace
        }
      }
    } else {
      leftSpace = label.point - Label.spacing
      if leftSpace > maxSpace {
        leftSpace = maxSpace
      }
    }
    
    // 右側の最大スペースの確認
    var rightSpace: CGFloat = 0   // 現在ラベルの中心より右に空いているスペース
    var rightMargin: CGFloat = 0  // 右のラベルを移動することで確保可能なスペース
    if index < labels.count {
      rightSpace = (labels[index].left - Label.spacing) - label.point
      if rightSpace > maxSpace {
        rightSpace = maxSpace
      } else {
        rightMargin = estimateRightShift(index: index)
        if rightSpace + rightMargin < -depth * coef {
          // 右に最小限の余裕がない
          return false
        } else if rightSpace + rightMargin > maxSpace {
          rightMargin = maxSpace - rightSpace
        }
      }
    } else {
      rightSpace = length - Label.spacing - label.point
      if rightSpace > maxSpace {
        rightSpace = maxSpace
      }
    }
    
    if leftSpace + leftMargin + rightSpace + rightMargin < label.width {
      // 両側の最大スペースを合わせても足りない
      return false
    }
    
    var leftShift: CGFloat = 0    // 左のラベルを移動する量
    var rightShift: CGFloat = 0   // 右のラベルを移動する量
    
    let leftAvail = leftSpace + leftMargin
    let rightAvail = rightSpace + rightMargin
    let w_2 = label.width / 2.0
    
    // 中心振り分けでおけるのであれば中心振り分け
    if leftAvail > w_2 && rightAvail > w_2 {
      if leftSpace < w_2 {
        leftShift = w_2 - leftSpace
      }
      if rightSpace < w_2 {
        rightShift = w_2 - rightSpace
      }
      label.left = label.point - w_2
    // そうでなければ、中心に近い側に寄せる
    } else if leftAvail < rightAvail {
      leftShift = leftMargin
      let rightW = label.width - leftAvail
      if rightSpace < rightW {
        rightShift = rightW - rightSpace
      }
      label.left = label.point - leftAvail
    } else {
      rightShift = rightMargin
      let leftW = label.width - rightAvail
      if leftSpace < leftW {
        leftShift = leftW - leftSpace
      }
      label.left = label.point - leftW
    }
    
    // 実際に移動させる
    if leftShift > 0.1 {
      shiftLeft(index: index - 1, distance: leftShift)
    }
    if rightShift > 0.1 {
      shiftRight(index: index, distance: rightShift)
    }
    labels.insert(label, at: index)
    return true
  }
  
  /// 指定のラベルが左にずれることの可能な最大の長さを求める
  ///
  /// - Parameter index: 対象のラベルの行内インデックス
  /// - Returns: 対象のラベルが現在の位置から左にずれることのできる最大値
  private func estimateLeftShift(index: Int) -> CGFloat {
    let label = labels[index]
    let maxSift: CGFloat = depth * coef + label.width - (label.point - label.left)
    if index == 0 {
      return min(label.left - Label.spacing, maxSift)
    } else {
      return min(estimateLeftShift(index: index - 1) +
        label.left - (labels[index - 1].right + Label.spacing), maxSift)
    }
  }
  
  /// 指定のラベルが右にずれることの可能な最大の長さを求める
  ///
  /// - Parameter index: 対象のラベルの行内インデックス
  /// - Returns: 対象のラベルが現在の位置から右にずれることのできる最大値
  private func estimateRightShift(index: Int) -> CGFloat {
    let label = labels[index]
    let maxSift: CGFloat = (label.point - label.left) + depth * coef
    if index == labels.count - 1 {
      return min(length - Label.spacing - label.right, maxSift)
    } else {
      return min(estimateRightShift(index: index + 1) +
        (labels[index + 1].left - Label.spacing) - label.right, maxSift)
    }
  }
  
  /// 指定のラベルを指定の距離分左にずらす
  ///
  /// - Parameters:
  ///   - index: 対象のラベルの行内インデックス
  ///   - distance: 左にずらす距離
  private func shiftLeft(index: Int, distance: CGFloat) {
    labels[index].left -= distance
    if index > 0 {
      let space = labels[index].left - (labels[index - 1].right + Label.spacing)
      if space < 0 {
        shiftLeft(index: index - 1, distance: -space)
      }
    }
  }
  
  /// 指定のラベルを指定の距離分右にずらす
  ///
  /// - Parameters:
  ///   - index: 対象のラベルの行内インデックス
  ///   - distance: 右にずらす距離
  private func shiftRight(index: Int, distance: CGFloat) {
    labels[index].left += distance
    if index < labels.count - 1 {
      let space = (labels[index + 1].left - Label.spacing) - labels[index].right
      if space < 0 {
        shiftRight(index: index + 1, distance: -space)
      }
    }
  }
}

