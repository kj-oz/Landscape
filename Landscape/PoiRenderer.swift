//
//  LabelRenderer.swift
//  Landscape
//
//  Created by KO on 2017/02/14.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit
import CoreLocation

/// POIの描画を担当するクラス
class PoiRenderer {
  
  /// 対象POI選定時の画面端部の余裕角度
  private let angleMargin = 3.0
  
  /// POIの管理を担当するオブジェクト
  private var poiManager: PoiManager
  
  /// その時点で選択されているグループ名
  private var selectedGroup: PoiGroup?
  
  /// その時点で選択されているPOI
  private var selectedPoi: Poi?
  
  /// 現在地の情報を表示するかどうか
  private var showLocation = false
  
  /// ラベルの最大行数
  private var rowCountMax = 0
  
  /// ラベルの縦向き時の最大行数
  private let rowCountV = 6
  
  /// ラベルの横向き時の最大行数
  private let rowCountH = 4
  
  /// ラベルの行
  private var rows: [LabelRow] = []
  
  /// 一番上の行の高さ
  private let rowTopHeight: CGFloat = Label.spacing
  
  /// 引出し線の太さ
  private let leadLineWidth: CGFloat = 1.5
  
  /// 引出し線のPOI部の折れ曲り点の高さ
  private var leadLinePointHeight: CGFloat = 0.0
  
  /// 引出し線のPOI部鉛直線の長さ
  private let leadLinePointLength: CGFloat = 10.0
  
  /// 情報ボックスの描画を担当するオブジェクト
  private let infoBoxRenderer = InfoBoxRenderer()
  

  /// コンストラクタ
  ///
  /// - Parameter poiManager: POIの管理を担当するオブジェクト
  init(poiManager: PoiManager) {
    self.poiManager = poiManager
  }
  
  /// 画面の向き（縦横）に応じて描画用の変数の値を更新する
  ///
  /// - Parameter params: 描画用パラメータ
  func setViewParameter(_ params: RenderingParams) {
    rowCountMax = params.isPortrait ? rowCountV : rowCountH
    leadLinePointHeight = params.height * 0.40
  }
  
  /// 画面がタップされた際に呼び出される
  ///
  /// - Parameter point: タップ座標
  func tapped(at point: CGPoint) {
    if let label = findLabel(at: point) {
      if let group = label.source as? PoiGroup {
        selectedGroup = group
        selectedPoi = nil
      } else {
        selectedPoi = label.source as? Poi
      }
      showLocation = false
    } else {
      if selectedPoi != nil {
        selectedPoi = nil
      } else if selectedGroup != nil {
        selectedGroup = nil
      } else {
        showLocation = !showLocation
      }
    }
  }

  /// 画面描画時に呼び出される
  ///
  /// - Parameter params: 描画用パラメータ
  func draw(params: RenderingParams) {
    let startAzimuth = angleAdd(to: params.startAngle, delta: angleMargin)
    let endAzimuth = angleAdd(to: params.endAngle, delta: -angleMargin)
    let pois = poiManager.getVisiblePois(startAzimuth: startAzimuth, endAzimuth: endAzimuth)
        
    createLabels(pois: pois, params: params)
    drawLabels(params: params)
    
    if let poi = selectedPoi {
      infoBoxRenderer.drawInfoBox(of: poi, params: params)
    } else if showLocation {
      infoBoxRenderer.drawLocation(poiManager.currentPosition, params: params)
    }
  }
  
  /// POIのラベルを、現在の画面の向きに応じて準備する
  ///
  /// - Parameters:
  ///   - pois: 距離的に見える可能性のある全てのPOI
  ///   - params: 描画パラメータ
  private func createLabels(pois: [Poi], params: RenderingParams) {
    var rows: [LabelRow] = []
    let depth = leadLinePointHeight - (Label.height + Label.spacing) * CGFloat(rowCountMax)
    for i in 0 ..< rowCountMax {
      rows.append(LabelRow(length: params.width,
                           depth: depth + CGFloat(i) * (Label.height + Label.spacing)))
    }
    var groups = Set<PoiGroup>()
    var labels: [Label] = []
    for poi in pois {
      let label: Label
      if let selectedGroup = selectedGroup {
        if let group = poi.group, group === selectedGroup {
          label = poi.label
        } else {
          continue
        }
      } else if let group = poi.group {
        if groups.contains(group) {
          continue
        }
        group.poi = poi
        groups.insert(group)
        label = group.label
      } else {
        label = poi.label
      }
      label.point = params.calcX(of: poi.azimuth)
      labels.append(label)
      //print("label: \(label.text) \(poi.azimuth) c:\(label.point) w:\(label.width)")
    }
    labels.sort(by: { $0.source.distance < $1.source.distance})
    
    var startRow = 0
    labels: for label in labels {
      for i in startRow ..< rows.count {
        if rows[i].insert(label: label) {
          startRow = i
          continue labels
        }
      }
      print("missed label: \(label.text)")
    }
    if startRow < rows.count - 1 {
      rows.removeLast()
    }
    rows.reverse()
    self.rows = rows
  }
  
  /// POIのラベルを描画する
  ///
  /// - Parameter params: 描画用パラメータ
  private func drawLabels(params: RenderingParams) {
    let ctx = params.context!
    var lineSpacing = Label.spacing
    if rows.count < rowCountMax {
      lineSpacing += (Label.spacing + Label.height) / CGFloat(rows.count)
    }
    
    //var leftLabel: Label?
    //var rightLabel: Label?
    
    for (index, row) in rows.enumerated() {
      if row.labels.count == 0 {
        continue
      }
      
      //if let left = leftLabel, row.labels.first!.point > left.point {
      //} else {
      //  leftLabel = row.labels.first!
      //}
      //
      //if let right = rightLabel, row.labels.last!.point < right.point {
      //} else {
      //  rightLabel = row.labels.last!
      //}

      // print("ROW-\(index)")
      let y = rowTopHeight + (Label.height + lineSpacing) * CGFloat(index)
      for label in row.labels {
        ctx.draw(label.image.cgImage!, in:
            CGRect(x: label.left, y: y, width: label.width, height: Label.height))
        
        ctx.setStrokeColor(label.color)
        let x: CGFloat
        if label.point > label.right {
          x = label.right - 1
        } else if label.point < label.left {
          x = label.left + 1
        } else {
          x = label.point
        }
        ctx.setLineWidth(leadLineWidth)
        ctx.move(to: CGPoint(x: x, y: y + Label.height))
        ctx.addLine(to: CGPoint(x: label.point, y: leadLinePointHeight))
        ctx.addLine(to: CGPoint(x: label.point, y: leadLinePointHeight + leadLinePointLength))
        ctx.strokePath()
      }
    }
    
    //print("> left :\(left.text) \(left.point) = \(left.source.azimuth)")
    //print("> right:\(right.text) \(right.point) = \(right.source.azimuth)")
  }
  
  /// 指定の位置にPOIのラベルが存在するかどうか調べる
  ///
  /// - Parameter point: 座標
  /// - Returns: POIのラベル、そんざいしなければnil
  private func findLabel(at point: CGPoint) -> Label? {
    var lineSpacing = Label.spacing
    if rows.count < rowCountMax {
      lineSpacing += (Label.spacing + Label.height) / CGFloat(rows.count)
    }
    let vMargin = lineSpacing / 2
    let hMargin = Label.spacing / 2
    
    for (index, row) in rows.enumerated() {
      let y = rowTopHeight + (Label.height + lineSpacing) * CGFloat(index)
      if point.y < y - vMargin || point.y > y + Label.height + vMargin {
        continue
      }
      
      for label in row.labels {
        if point.x < label.left - hMargin || point.x > label.right + hMargin {
          continue
        }
        return label
      }
    }
    return nil
  }
  
  /// 情報ボックスの内容の描画を担当するクラス
  class InfoBoxRenderer {
    
    /// 背景色
    private let boxColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1).cgColor
    
    /// フォントの色
    private let fontColor = UIColor.black
    
    /// 表題のフォント
    private let titleFont = UIFont.systemFont(ofSize: 16)
    
    /// 本文のフォント
    private let sentenceFont = UIFont.systemFont(ofSize: 14)
    
    /// POIの情報ボックスの高さ（縦向き時）
    private let poiHeightP: CGFloat = 135
    
    /// 現在地の情報ボックスの高さ（縦向き時）
    private let locationHeightP: CGFloat = 70
    
    /// 情報ボックスの底部の画面下端からの距離（縦向き時）
    private let boxBottomP: CGFloat = 151
    
    /// POIの情報ボックスの高さ（横向き時）
    private let poiHeightL: CGFloat = 120
    
    /// 現在地の情報ボックスの高さ（横向き時）
    private let locationHeightL: CGFloat = 70

    /// 情報ボックスの底部の画面下端からの距離（横向き時）
    private let boxBottomL: CGFloat = 41
    
    /// 情報ボックスと画面左右端との距離
    private let boxMargin: CGFloat = 11
    
    /// 情報ボックスの右端から画面右端までの距離（横向き時）
    private let boxRightMarginL: CGFloat = 143
    
    /// 情報ボックスの左端から画面左端までの距離（横向き時）
    private let boxLefttMarginL: CGFloat = 55
    
    /// ボックスと中のフォントとの距離
    private let boxSpacing: CGFloat = 5
    
    /// タイトル文字列の高さ
    private let titleHeight: CGFloat = 20
    
    /// 本文のインデント
    private let sentenceIndent: CGFloat = 5
    
    /// 指定のPOIの情報ボックスを描画する
    ///
    /// - Parameters:
    ///   - poi: POI
    ///   - params: 描画パラメータ
    func drawInfoBox(of poi: Poi, params: RenderingParams) {
      let ctx = params.context!
      
      let y: CGFloat
      let x: CGFloat
      let height: CGFloat
      let width: CGFloat
      let itemSeparator: String
      
      if params.isPortrait {
        y = params.height - (boxBottomP + poiHeightP)
        x = boxMargin
        height = poiHeightP
        width = params.width - boxMargin * 2
        itemSeparator = "\n　　　　　"
      } else {
        y = params.height - (boxBottomL + poiHeightL)
        x = boxLefttMarginL
        height = poiHeightL
        width = params.width - (x + boxRightMarginL)
        itemSeparator = "　"
      }
      
      let rect = CGRect(x: x, y: y, width: width, height: height)
      ctx.setFillColor(boxColor)
      ctx.fill(rect)
      
      let details = poi.detail!.components(separatedBy: ",")
      var attrs = [NSFontAttributeName: titleFont,
                   NSForegroundColorAttributeName: fontColor]
      var string = "\(poi.name)　\(details[0])"
      string.draw(with: CGRect(x: x + boxSpacing, y: y + boxSpacing,
                               width: width - boxSpacing * 2, height: titleHeight),
                  options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
      
      attrs[NSFontAttributeName] = sentenceFont
      string = ""
      if !details[1].isEmpty {
        string += "別名　　：\(details[1])　\(details[2])\n"
      }
      
      switch poi.type {
      case .building:
        string += "高さ　　：\(String(format: "%.0f", poi.height)) m\n"
        string += "緯度経度：N \(String(format: "%.5f", poi.location.latitude))° "
        string += "E \(String(format: "%.5f", poi.location.longitude))°\n"
        string += "所在地　　：\(details[3])\(details[4])\n"
      case .city:
        string += "緯度経度：N \(String(format: "%.5f", poi.location.latitude))° "
        string += "E \(String(format: "%.5f", poi.location.longitude))°\n"
        string += "都道府県　　：\(details[3])）\n"
      default:
        string += "標高　　：\(String(format: "%.0f", poi.height)) m\n"
        string += "緯度経度：N \(String(format: "%.5f", poi.location.latitude))° "
        string += "E \(String(format: "%.5f", poi.location.longitude))°\n"
        string += "山域　　：\(details[4])" + itemSeparator
        string += "（\(details[3])）\n"
      }
      if !details[5].isEmpty {
        string += "その他　：\(details[5])\n"
      }
      string.draw(with: CGRect(x: x + boxSpacing + sentenceIndent,
                               y: y + titleHeight + boxSpacing * 2,
                               width: width - boxSpacing * 2 - sentenceIndent,
                               height: height - titleHeight + boxSpacing * 2),
                  options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    }

    /// 現在地の情報ボックスを描画する
    ///
    /// - Parameters:
    ///   - location: 現在地
    ///   - params: 描画パラメータ
    func drawLocation(_ location: CLLocation?, params: RenderingParams) {
      if location == nil {
        return
      }
      
      let ctx = params.context!
      
      let y: CGFloat
      let x: CGFloat
      let height: CGFloat
      let width: CGFloat
      
      if params.isPortrait {
        y = params.height - (boxBottomP + locationHeightP)
        x = boxMargin
        height = locationHeightP
        width = params.width - boxMargin * 2
      } else {
        y = params.height - (boxBottomL + locationHeightL)
        x = boxLefttMarginL
        height = locationHeightL
        width = params.width - (x + boxRightMarginL)
      }
      
      let rect = CGRect(x: x, y: y, width: width, height: height)
      ctx.setFillColor(boxColor)
      ctx.fill(rect)
      
      var attrs = [NSFontAttributeName: titleFont,
                   NSForegroundColorAttributeName: fontColor]
      var string = "現在地"
      string.draw(with: CGRect(x: x + boxSpacing, y: y + boxSpacing,
                               width: width - boxSpacing * 2, height: titleHeight),
                  options: .usesLineFragmentOrigin, attributes: attrs, context: nil)

      attrs[NSFontAttributeName] = sentenceFont
      string = ""
      string += "標高　　：\(String(format: "%.0f", Double(location!.altitude))) m\n"
      string += "緯度経度：N \(String(format: "%.5f", location!.coordinate.latitude))° "
      string += "E \(String(format: "%.5f", location!.coordinate.longitude))°\n"
      string.draw(with: CGRect(x: x + boxSpacing + sentenceIndent,
                               y: y + titleHeight + boxSpacing * 2,
                               width: width - boxSpacing * 2 - sentenceIndent,
                               height: height - titleHeight + boxSpacing * 2),
                  options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    }
  }
}
