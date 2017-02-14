//
//  Label.swift
//  Landscape
//
//  Created by KO on 2017/01/28.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit
import CoreLocation

/**
 * 画面上の地物の名称の表示
 */
class Label {
  // ラベルに表示する文字サイズ
  static let fontSize: CGFloat = 12.0
  
  // ラベルの文字と枠間のパディング
  static let padding: CGFloat = 3.0
  
  // ラベルの間隔
  static let spacing: CGFloat = 9.0
  
  // 対象の地物
  let poi: Poi
  
  let text: String
  
  let height: Double
  
  //
  let group: Bool
  
  // 対象地物の位置の画面への投影のx座標
  let point: CGFloat
  
  // ラベルの枠長方形の幅
  let width: CGFloat
  
  // ラベルの左端のx座標
  var left: CGFloat = 0.0
  
  // ラベルの右端のx座標
  var right: CGFloat {
    return left + width
  }
  
  // コンストラクタ
  init(poi: Poi, group: Bool, groupHeight: Double?, heading: Double) {
    self.poi = poi
    self.group = group
    self.height = group ? groupHeight! : poi.height
    let angle = poi.angle(from: heading)
    point = SceneRenderer.w_2 * CGFloat(1 + tan(toRadian(angle)) / SceneRenderer.tanFA_2)
    text = group ? poi.group! + " ▶" : poi.name
    width = text.size(attributes: [NSFontAttributeName: UIFont.systemFont(ofSize: Label.fontSize)]).width + 2 * Label.padding
  }
}

/**
 * 画面に表示する1行のラベル群
 */
class LabelRow {
  // 画面の幅
  let length: CGFloat
  
  let depth: CGFloat
  
  let coef: CGFloat = 1.5

  // ラベルそのもの
  var labels: [Label] = []
  
  /**
   * コンストラクタ
   *
   * - parameter length 画面横のピクセル数
   */
  init(length: CGFloat, depth: CGFloat) {
    self.length = length
    self.depth = depth
  }
  
  /**
   * 指定のラベルを行の中に吸収する
   *
   * - parameter label: 吸収対応のラベル文字列
   * - returns 吸収することが出来たらばtrue、何らかの理由で出来なければfalse
   */
  func insert(label: Label) -> Bool {
//    var totalWidth = labels.reduce(CGFloat(0.0), { $0 + $1.width })
//    let spaceCount = labels.count + 2
//    totalWidth += label.width
//    if totalWidth + Label.spacing * CGFloat(spaceCount) > length {
//      return false
//    }
    
    // 挿入位置の確定
    var index = 0
    for lb in labels {
      if lb.point > label.point {
        break
      }
      index += 1
    }
    
//    let space = (length - totalWidth) / CGFloat(spaceCount)
//    labels.insert(label, at: index)
//    var next = space
//    for lb in labels {
//      lb.left = next
//      next += lb.width + space
//    }
    
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
    
    // まず、左右とも最小限のスペースを確保する（スペースがあることは上で確認済み）
//    if leftSpace < Label.padding {
//      leftShift = Label.padding - leftSpace
//      leftSpace = Label.padding
//      leftMargin -= leftShift
//    }
//    if rightSpace < Label.padding {
//      rightShift = Label.padding - rightSpace
//      rightSpace = Label.padding
//      rightMargin -= rightShift
//    }
    
    let space = leftSpace + rightSpace
    let margin = leftMargin + rightMargin
    if space < label.width {
      // 現状のスペースでは不足の場合、足りない分の移動量を左右の確保可能量の比から算定
      let delta = label.width - space
      let leftdelta = delta * leftMargin / margin
      let rightdelta = delta - leftdelta
      leftShift += leftdelta
      rightShift += rightdelta
      label.left = label.point - (leftdelta + leftSpace)
    } else {
      // 現状のスペースで足りている場合、左右の割り振りをスペースの比から算定
      let delta = space - label.width
      label.left = label.point - leftSpace + delta / 2
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
  
  /**
   * 指定のラベルが左にずれることの可能な最大の長さを求める
   *
   * - parameter index: 対象のラベルのインデックス
   * - return 対象のラベルが現在の位置から左にずれることのできる最大値を求める
   */
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
  
  /**
   * 指定のラベルが右にずれることの可能な最大の長さを求める
   *
   * - parameter index: 対象のラベルのインデックス
   * - return 対象のラベルが現在の位置から右にずれることのできる最大値を求める
   */
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
  
  /**
   * 指定のラベルを指定の距離分左にずらす
   *
   * - parameter index: 対象のラベルのインデックス
   * - parameter distance: 対象のラベル左にずらす長さ
   */
  private func shiftLeft(index: Int, distance: CGFloat) {
    labels[index].left -= distance
    if index > 0 {
      let space = labels[index].left - (labels[index - 1].right + Label.spacing)
      if space < 0 {
        shiftLeft(index: index - 1, distance: -space)
      }
    }
  }
  
  /**
   * 指定のラベルを指定の距離分右にずらす
   *
   * - parameter index: 対象のラベルのインデックス
   * - parameter distance: 対象のラベル右にずらす長さ
   */
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

