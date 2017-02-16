//
//  LabelRenderer.swift
//  Landscape
//
//  Created by KO on 2017/02/14.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit

class LabelRenderer: NSObject {
  // ラベルの行数
  private var rowCount = 0
  
  // ラベルの行数
  private var rowStartHeight: CGFloat = 0.0
  
  // ラベルの高さ
  private var labelHeight: CGFloat = 0.0
  
  // ラベルの高さ
  private let labelFontColor = UIColor.white.cgColor
  
  //
  private let labelLineWidth: CGFloat = 2.0
  
  private var labelLineEndHeight: CGFloat = 0.0
  
  private var portrait = true
  
  private let angleMargin = 3.0
  
  private var rows: [LabelRow] = []
  
  var selectedGroup: String?
  
  var selectedPoi: Poi?
  
  private var poiManager: PoiManager
  
  init(poiManager: PoiManager) {
    self.poiManager = poiManager
    labelHeight = "国".size(attributes:
      [NSFontAttributeName: UIFont.systemFont(ofSize: Label.fontSize)]).height + 2 * Label.padding
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

  func drawLabels(params: RenderingParams) {
    
    let ctx = params.context!
    
    if params.portrait {
      rowCount = 7
      rowStartHeight = 20.0 + Label.spacing
    } else {
      rowCount = 5
      rowStartHeight = Label.spacing
    }
    labelLineEndHeight = params.height * 0.45
    
    var startAzimuth = params.startAngle + angleMargin
    if startAzimuth > 360.0 {
      startAzimuth -= 360.0
    }
    var endAzimuth = params.endAngle - angleMargin
    if endAzimuth < 0 {
      endAzimuth += 360.0
    }
    let pois = poiManager.getVisiblePois(startAzimuth: startAzimuth, endAzimuth: endAzimuth)
        
    rows = self.createRows(pois: pois, params: params)
    drawPois(params: params)
    
    
    // デバッグ出力
    if let poi = selectedPoi {
      var y = params.height - (portrait ? 200 : 165)
      let rect = CGRect(x: 40, y: y, width: params.width - 80, height: portrait ? 150 : 115)
      ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 0.5)
      ctx.fill(rect)
      
      let details = poi.detail!.components(separatedBy: ",")
      
      var attrs = [NSFontAttributeName: UIFont.systemFont(ofSize: 16),
                   NSForegroundColorAttributeName: UIColor.black]
      var string = "\(poi.name)　\(details[0])"
      y += 5;
      string.draw(with: CGRect(x: 45, y: y, width: params.width - 90, height: 20), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
      
      attrs[NSFontAttributeName] = UIFont.systemFont(ofSize: 14)
      string = ""
      if !details[1].isEmpty {
        string += "別名　　：\(details[1])　\(details[2])\n"
      }
      string += "標高　　：\(String(format: "%.0f", poi.height)) m\n"
      string += "緯度経度：北緯 \(String(format: "%.2f", poi.location.latitude)) 度"
      string += portrait ? "\n　　　　　" : "　"
      string += "東経 \(String(format: "%.2f", poi.location.longitude)) 度\n"
      string += "山域　　：\(details[4])"
      string += portrait ? "\n　　　　　" : "　"
      string += "（\(details[3])）\n"
      if !details[5].isEmpty {
        string += "その他　：\(details[5])\n"
      }
      y += 20;
      string.draw(with: CGRect(x: 60, y: y, width: params.width - 90, height: portrait ? 125 : 90), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    }
    
  }
  
  private func getColor(of label: Label) -> CGColor {
    switch label.height {
    case 0 ..< 1000:
      return UIColor(red: 0, green: 0.8, blue:1, alpha: 1).cgColor
    case 1000 ..< 1500:
      return UIColor(red: 0.5, green: 1, blue:0.8, alpha: 1).cgColor
    case 1500 ..< 2000:
      return UIColor(red: 0.7, green: 1, blue:0.1, alpha: 1).cgColor
    case 2000 ..< 2500:
      return UIColor.yellow.cgColor
    case 2500 ..< 3000:
      return UIColor.orange.cgColor
    default:
      return UIColor.red.cgColor
    }
  }
  
  private func createRows(pois: [Poi], params: RenderingParams) -> [LabelRow] {
    print("■view: w \(params.width)")
    var rows: [LabelRow] = []
    let depth = labelLineEndHeight - (labelHeight + Label.spacing) * CGFloat(rowCount)
    for i in 0 ..< rowCount {
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
        label = Label(poi: poi, group: false, groupHeight: nil, params: params)
      } else if let group = poi.group {
        if groups.contains(group) {
          continue
        }
        label = Label(poi: poi, group: true,
                      groupHeight: poiManager.getHeight(of: group), params: params)
        groups.insert(group)
      } else {
        label = Label(poi: poi, group: false, groupHeight: nil, params: params)
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
      print("missed label: \(label.text) (\(label.height))")
    }
    if startRow < rows.count - 1 {
      rows.removeLast()
    }
    rows.reverse()
    return rows
  }
  
  private func drawPois(params: RenderingParams) {
    let ctx = params.context!
    ctx.setStrokeColor(labelFontColor)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    var attrs = [NSFontAttributeName: UIFont.systemFont(ofSize: Label.fontSize),
                 NSParagraphStyleAttributeName: paragraphStyle,
                 NSForegroundColorAttributeName: UIColor.black]
    
    var lineSpacing = Label.spacing
    if rows.count < rowCount {
      lineSpacing += (Label.spacing + labelHeight) / CGFloat(rows.count)
    }
    
    for (index, row) in rows.enumerated() {
      if row.labels.count == 0 {
        continue
      }
      // print("ROW-\(index)")
      let y = rowStartHeight + (labelHeight + lineSpacing) * CGFloat(index)
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
        ctx.setLineWidth(labelLineWidth)
        ctx.move(to: CGPoint(x: x, y: y + labelHeight))
        ctx.addLine(to: CGPoint(x: label.point, y: labelLineEndHeight))
        ctx.addLine(to: CGPoint(x: label.point, y: labelLineEndHeight + 10))
        ctx.strokePath()
        
        attrs[NSFontAttributeName] = UIFont.systemFont(ofSize: Label.fontSize)
        label.text.draw(with: CGRect(x: label.left, y: y + Label.padding,
                                     width: label.width, height: labelHeight),
                        options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
        // print("\(label.text): L \(label.left) W \(label.width) C \(label.point) E \(label.poi.elevation)")
      }
    }
  }
  
  private func findLabel(at point: CGPoint) -> Label? {
    var lineSpacing = Label.spacing
    if rows.count < rowCount {
      lineSpacing += (Label.spacing + labelHeight) / CGFloat(rows.count)
    }
    
    for (index, row) in rows.enumerated() {
      let y = rowStartHeight + (labelHeight + lineSpacing) * CGFloat(index)
      if point.y < y || point.y > y + labelHeight {
        continue
      }
      
      for label in row.labels {
        if point.x < label.left || point.x > label.right {
          continue
        }
        return label
      }
    }
    return nil
  }
}
