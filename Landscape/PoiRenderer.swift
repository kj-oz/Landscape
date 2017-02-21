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
class PoiRenderer: NSObject {
  
  // 対象POI選定時の画面端部の余裕角度
  private let angleMargin = 3.0
  
  // POIの管理を担当するオブジェクト
  private var poiManager: PoiManager
  
  // その時点で選択されているグループ名
  private var selectedGroup: String?
  
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
  
  // ラベルの高さ
  private let labelHeight: CGFloat
  
  // ラベルの色
  private let labelColor0_1000 = UIColor(red: 0, green: 0.8, blue:1, alpha: 1).cgColor
  private let labelColor1000_1500 = UIColor(red: 0.5, green: 1, blue:0.8, alpha: 1).cgColor
  private let labelColor1500_2000 = UIColor(red: 0.7, green: 1, blue:0.1, alpha: 1).cgColor
  private let labelColor2000_2500 = UIColor.yellow.cgColor
  private let labelColor2500_3000 = UIColor.orange.cgColor
  private let labelColor3000_ = UIColor.red.cgColor
  
  // ラベルの文字色
  private let labelFontColor = UIColor.black
  
  // 引出し線の太さ
  private let leadLineWidth: CGFloat = 2.0
  
  // 引出し線のPOI部の折れ曲り点の高さ
  private var leadLinePointHeight: CGFloat = 0.0
  
  // 引出し線のPOI部鉛直線の長さ
  private let leadLinePointLength: CGFloat = 10.0
  
  private let infoBoxRenderer = InfoBoxRenderer()

  
  init(poiManager: PoiManager) {
    self.poiManager = poiManager
    labelHeight = "国".size(attributes:
      [NSFontAttributeName: Label.font]).height + 2 * Label.padding
  }
  
  func setViewParameter(_ params: RenderingParams) {
    rowCountMax = params.isPortrait ? rowCountV : rowCountH
    leadLinePointHeight = params.height * 0.45
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
  }

  func draw(params: RenderingParams) {
    var startAzimuth = params.startAngle + angleMargin
    if startAzimuth > 360.0 {
      startAzimuth -= 360.0
    }
    var endAzimuth = params.endAngle - angleMargin
    if endAzimuth < 0 {
      endAzimuth += 360.0
    }
    let pois = poiManager.getVisiblePois(startAzimuth: startAzimuth, endAzimuth: endAzimuth)
        
    createLabels(pois: pois, params: params)
    drawLabels(params: params)
    
    // デバッグ出力
    if let poi = selectedPoi {
      infoBoxRenderer.drawInfoBox(of: poi, params: params)
    }
  }
  
  private func createLabels(pois: [Poi], params: RenderingParams) {
    print("■view: w \(params.width)")
    var rows: [LabelRow] = []
    let depth = leadLinePointHeight - (labelHeight + Label.spacing) * CGFloat(rowCountMax)
    for i in 0 ..< rowCountMax {
      rows.append(LabelRow(length: params.width,
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
        label = Label(poi: poi, group: false, params: params)
      } else if let group = poi.group {
        if groups.contains(group) {
          continue
        }
        label = Label(poi: poi, group: true, params: params)
        groups.insert(group)
      } else {
        label = Label(poi: poi, group: false, params: params)
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
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    var attrs = [NSFontAttributeName: Label.font,
                 NSParagraphStyleAttributeName: paragraphStyle,
                 NSForegroundColorAttributeName: labelFontColor]
    
    var lineSpacing = Label.spacing
    if rows.count < rowCountMax {
      lineSpacing += (Label.spacing + labelHeight) / CGFloat(rows.count)
    }
    
    for (index, row) in rows.enumerated() {
      if row.labels.count == 0 {
        continue
      }
      // print("ROW-\(index)")
      let y = rowTopHeight + (labelHeight + lineSpacing) * CGFloat(index)
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
        ctx.setLineWidth(leadLineWidth)
        ctx.move(to: CGPoint(x: x, y: y + labelHeight))
        ctx.addLine(to: CGPoint(x: label.point, y: leadLinePointHeight))
        ctx.addLine(to: CGPoint(x: label.point, y: leadLinePointHeight + leadLinePointLength))
        ctx.strokePath()
        
        attrs[NSFontAttributeName] = Label.font
        label.text.draw(with: CGRect(x: label.left, y: y + Label.padding,
                                     width: label.width, height: labelHeight),
                        options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
        // print("\(label.text): L \(label.left) W \(label.width) C \(label.point) E \(label.poi.elevation)")
      }
    }
  }
  
  private func getColor(of label: Label) -> CGColor {
    let height = label.group ? poiManager.getHeight(of: label.poi.group!)! : label.poi.height
    switch height {
    case 0 ..< 1000:
      return labelColor0_1000
    case 1000 ..< 1500:
      return labelColor1000_1500
    case 1500 ..< 2000:
      return labelColor1500_2000
    case 2000 ..< 2500:
      return labelColor2000_2500
    case 2500 ..< 3000:
      return labelColor2500_3000
    default:
      return labelColor3000_
    }
  }
  
  private func findLabel(at point: CGPoint) -> Label? {
    var lineSpacing = Label.spacing
    if rows.count < rowCountMax {
      lineSpacing += (Label.spacing + labelHeight) / CGFloat(rows.count)
    }
    let vMargin = lineSpacing / 2
    let hMargin = Label.spacing / 2
    
    for (index, row) in rows.enumerated() {
      let y = rowTopHeight + (labelHeight + lineSpacing) * CGFloat(index)
      if point.y < y - vMargin || point.y > y + labelHeight + vMargin {
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
    private let boxColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.5).cgColor
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
        y = params.height - 260
        x = 20
        height = 155
        width = params.width - 40
        itemSeparator = "\n　　　　　"
      } else {
        y = params.height - 170
        x = 20
        height = 120
        width = params.width - 160
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