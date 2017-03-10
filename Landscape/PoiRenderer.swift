//
//  LabelRenderer.swift
//  Landscape
//
//  Created by KO on 2017/02/14.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit

/**
 * POIの描画を担当するクラス
 */
class PoiRenderer {
  
  // 対象POI選定時の画面端部の余裕角度
  private let angleMargin = 3.0
  
  // POIの管理を担当するオブジェクト
  private var poiManager: PoiManager
  
  // その時点で選択されているグループ名
  private var selectedGroup: PoiGroup?
  
  // その時点で選択されているPOI
  private var selectedPoi: Poi?
  
  // ラベルの最大行数
  private var rowCountMax = 0
  
  // ラベルの縦向き時の最大行数
  private let rowCountV = 7
  
  // ラベルの横向き時の最大行数
  private let rowCountH = 5
  
  // ラベルの行
  private var rows: [LabelRow] = []
  
  // 一番上の行の高さ
  private let rowTopHeight: CGFloat = Label.spacing
  
  // 引出し線の太さ
  private let leadLineWidth: CGFloat = 2.0
  
  // 引出し線のPOI部の折れ曲り点の高さ
  private var leadLinePointHeight: CGFloat = 0.0
  
  // 引出し線のPOI部鉛直線の長さ
  private let leadLinePointLength: CGFloat = 10.0
  
  
  private let infoBoxRenderer = InfoBoxRenderer()

  
  init(poiManager: PoiManager) {
    self.poiManager = poiManager
  }
  
  func setViewParameter(_ params: RenderingParams) {
    rowCountMax = params.isPortrait ? rowCountV : rowCountH
    leadLinePointHeight = params.height * 0.45
  }
  
  func tapped(at point: CGPoint) {
    if let label = findLabel(at: point) {
      if let group = label.source as? PoiGroup {
        selectedGroup = group
        selectedPoi = nil
      } else {
        selectedPoi = label.source as? Poi
      }
    } else {
      if selectedPoi != nil {
        selectedPoi = nil
      } else {
        selectedGroup = nil
      }
    }
  }

  func draw(params: RenderingParams) {
    let startAzimuth = angleAdd(to: params.startAngle, delta: angleMargin)
    let endAzimuth = angleAdd(to: params.endAngle, delta: -angleMargin)
    let pois = poiManager.getVisiblePois(startAzimuth: startAzimuth, endAzimuth: endAzimuth)
        
    createLabels(pois: pois, params: params)
    drawLabels(params: params)
    
    // デバッグ出力
    if let poi = selectedPoi {
      infoBoxRenderer.drawInfoBox(of: poi, params: params)
    }
  }
  
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
      // print("label: \(label.text) \(poi.azimuth) c:\(label.point) w:\(label.width)")
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
  
  private func drawLabels(params: RenderingParams) {
    let ctx = params.context!
    var lineSpacing = Label.spacing
    if rows.count < rowCountMax {
      lineSpacing += (Label.spacing + Label.height) / CGFloat(rows.count)
    }
    
    var leftLabel: Label?
    var rightLabel: Label?
    let debugFieldAngle = false
    
    for (index, row) in rows.enumerated() {
      if row.labels.count == 0 {
        continue
      }
      
      if debugFieldAngle {
        if let left = leftLabel, row.labels.first!.point > left.point {
        } else {
          leftLabel = row.labels.first!
        }
        
        if let right = rightLabel, row.labels.last!.point < right.point {
        } else {
          rightLabel = row.labels.last!
        }
      }

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
    
    if debugFieldAngle, let left = leftLabel, let right = rightLabel {
      print("> left :\(left.text) \(left.point) = \(left.source.azimuth)")
      print("> right:\(right.text) \(right.point) = \(right.source.azimuth)")
    }
  }
  
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
  
  class InfoBoxRenderer {
    private let boxColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1).cgColor
    private let fontColor = UIColor.black
    private let titleFont = UIFont.systemFont(ofSize: 16)
    private let sentenceFont = UIFont.systemFont(ofSize: 14)
    
    func drawInfoBox(of poi: Poi, params: RenderingParams) {
      let ctx = params.context!
      
      let y: CGFloat
      let x: CGFloat
      let height: CGFloat
      let width: CGFloat
      let itemSeparator: String
      
      if params.isPortrait {
        y = params.height - 315
        x = 20
        height = 155
        width = params.width - 40
        itemSeparator = "\n　　　　　"
      } else {
        y = params.height - 170
        x = 20
        height = 120
        width = params.width - 238
        itemSeparator = "　"
      }
      
      let rect = CGRect(x: x, y: y, width: width, height: height)
      ctx.setFillColor(boxColor)
      ctx.fill(rect)
      
      let details = poi.detail!.components(separatedBy: ",")
      var attrs = [NSFontAttributeName: titleFont,
                   NSForegroundColorAttributeName: fontColor]
      var string = "\(poi.name)　\(details[0])"
      string.draw(with: CGRect(x: x + 5, y: y + 5, width: width - 10, height: 20),
                  options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
      
      attrs[NSFontAttributeName] = sentenceFont
      string = ""
      if !details[1].isEmpty {
        string += "別名　　：\(details[1])　\(details[2])\n"
      }
      string += "標高　　：\(String(format: "%.0f", poi.height)) m\n"
      string += "緯度経度：北緯 \(String(format: "%.5f", poi.location.latitude)) 度" + itemSeparator
      string += "東経 \(String(format: "%.5f", poi.location.longitude)) 度\n"
      string += "山域　　：\(details[4])" + itemSeparator
      string += "（\(details[3])）\n"
      if !details[5].isEmpty {
        string += "その他　：\(details[5])\n"
      }
      string.draw(with: CGRect(x: x + 10, y: y + 30, width: width - 15, height: height - 25),
                  options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    }
  }
}
