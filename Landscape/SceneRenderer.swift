//
//  SceneManager.swift
//  Landscape
//
//  Created by KO on 2017/01/04.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit
import CoreLocation

struct RenderingParams {
  // 画角の1/2のタンジェント
  private var tanFA_2: Double = 0.0
  
  private var w_2: CGFloat = 0.0
  
  // 長辺方向の画角
  private var fieldAngleH = 0.0
  
  // 短辺方向の画角
  private var fieldAngleV = 0.0
  
  // デバイスの背面の向き
  var _heading: Double?
  var heading: Double? {
    get {
      return _heading
    }
    set {
      _heading = newValue
      startAngle = _heading! - fieldAngle * 0.5
      if startAngle < 0 {
        startAngle += 360
      }
      endAngle = _heading! + fieldAngle * 0.5
      if endAngle > 360 {
        endAngle -= 360
      }
    }
  }
  
  var startAngle = 0.0
  
  var endAngle = 0.0
  
  
  // 水平方向の画角
  var fieldAngle = 0.0
  
  private var size = CGSize.zero
  
  // 画面のサイズ
  var width: CGFloat {
    return size.width
  }
  
  var height: CGFloat {
    return size.height
  }
  
  var portrait: Bool {
    return size.height > size.width
  }
  
  // 描画コンテキスト
  var context: CGContext?

  init(size: CGSize) {
    self.size = size
    let h = Double(max(size.width, size.height))
    let v = Double(min(size.width, size.height))
    fieldAngleH = getFieldAngle()
    fieldAngleV = toDegree(atan(v / h * tan(toRadian(fieldAngleH / 2.0)))) * 2.0
  }
  
  mutating func setViewParameter(size: CGSize) {
    self.size = size
    if size.width > size.height {
      fieldAngle = fieldAngleH
    } else {
      fieldAngle = fieldAngleV
    }
    tanFA_2 = tan(toRadian(fieldAngle / 2.0))
    w_2 = size.width / 2
  }
  
  func calcX(of azimuth: Double) -> CGFloat {
    var angle = azimuth - heading!
    if angle < -180 {
      angle += 360
    } else if angle > 180 {
      angle -= 360
    }
    return w_2 * CGFloat(1 + tan(toRadian(angle)) / tanFA_2)
  }
  
  private func getFieldAngle() -> Double {
    return 62.0
  }
}

class SceneRenderer: NSObject, CALayerDelegate {
  
  // POIの管理オブジェクト
  private let poiManager: PoiManager
  
  private let directionRenderer: DirectionRenderer
  
  private let labelRenderer: LabelRenderer
  
  private var params: RenderingParams
  
  // 描画対象のレイヤ
  private var layer: CALayer?
  
  /**
   * コンストラクタ
   *
   * - parameter layer: 描画対象レイヤ
   */
  init(layer: CALayer) {
    params = RenderingParams(size: layer.frame.size)
    poiManager = PoiManager()
    directionRenderer = DirectionRenderer()
    labelRenderer = LabelRenderer(poiManager: poiManager)
    super.init()
    
    self.layer = layer
    layer.delegate = self
    
    params.setViewParameter(size: layer.frame.size)
  }
  
  func updateLocation(location: CLLocationCoordinate2D) {
    // 対象POIの再計算
    poiManager.setCurrentPosition(position: location)
    layer!.setNeedsDisplay()
  }
  
  
  func updateHeading(heading: Double) {
    params.heading = heading
    layer!.setNeedsDisplay()
  }
  
  func changeOrientation(to size: CGSize) {
    self.layer!.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
    params.setViewParameter(size: size)
    layer!.setNeedsDisplay()
  }
  
  func tapped(at point: CGPoint) {
    labelRenderer.tapped(at: point)
    layer!.setNeedsDisplay()
  }
  
  
  func draw(_ layer: CALayer, in ctx: CGContext) {
    if params.heading == nil {
      return
    }
    
    ctx.saveGState()
    UIGraphicsPushContext(ctx)
    params.context = ctx
    
    // 方位の描画
    directionRenderer.drawDirections(params: params)

    // POIの描画
    labelRenderer.drawLabels(params: params)
    
    UIGraphicsPopContext()
    ctx.restoreGState()
  }
  
}

