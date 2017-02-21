//
//  SceneManager.swift
//  Landscape
//
//  Created by KO on 2017/01/04.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit
import CoreLocation

/**
 * 描画全般で使用するパラメータを保持する構造体
 */
struct RenderingParams {
  
  // 画角の1/2のタンジェント
  private var tanFA_2Base: Double = 0.0
  private var tanFA_2: Double = 0.0
  
  // 画面の幅の1/2（ピクセル値）
  private var w_2: CGFloat = 0.0
  
  // 長辺方向の画角
  private var fieldAngleH = 0.0
  
  // 短辺方向の画角
  private var fieldAngleV = 0.0
  
  // デバイスの背面の向き
  var heading: Double? {
    didSet {
      updateAngleRange()
    }
  }
  
  var zoom: Double = 1.0 {
    didSet {
      updateFieldAngle()
      updateAngleRange()
    }
  }
  
  // 画面左端の方位角度
  private var _startAngle = 0.0
  var startAngle: Double {
    return _startAngle
  }
  
  // 画面右端の方位角度
  private var _endAngle = 0.0
  var endAngle: Double {
    return _endAngle
  }
  
  // 水平方向の画角
  private var fieldAngleBase = 0.0
  private var fieldAngle_2 = 0.0
  
  // 画面のサイズ
  private var size = CGSize.zero
  var width: CGFloat {
    return size.width
  }
  var height: CGFloat {
    return size.height
  }
  
  // 画面の向きが縦向きかどうか
  var isPortrait: Bool {
    return size.height > size.width
  }
  
  // 描画コンテキスト
  var context: CGContext?

  /**
   * コンストラクタ
   *
   * - parameter size 画面のサイズ（向きはどちらでも良い）
   */
  init(size: CGSize) {
    self.size = size
    let h = Double(max(size.width, size.height))
    let v = Double(min(size.width, size.height))
    fieldAngleH = getFieldAngle()
    fieldAngleV = toDegree(atan(v / h * tan(toRadian(fieldAngleH / 2.0)))) * 2.0
  }
  
  /**
   * 画面のサイズに影響を受けるパラメータを設定する
   * 画面の向きが変わった際に呼び出される
   *
   * -parameter size 画面のサイズ
   */
  mutating func setViewParameter(size: CGSize) {
    self.size = size
    let fieldAngle = size.width > size.height ? fieldAngleH : fieldAngleV
    tanFA_2Base = tan(toRadian(fieldAngle / 2.0))
    
    w_2 = size.width / 2
    updateFieldAngle()
  }
  
  /**
   * 与えられた方位の画面上のX座標を返す
   *
   * -parameter azumith 方位
   * -returns 画面上のX座標
   */
  func calcX(of azimuth: Double) -> CGFloat {
    var angle = azimuth - heading!
    if angle < -180 {
      angle += 360
    } else if angle > 180 {
      angle -= 360
    }
    return w_2 * CGFloat(1 + tan(toRadian(angle)) / tanFA_2)
  }
  
  private mutating func updateFieldAngle() {
    tanFA_2 = tanFA_2Base / zoom
    fieldAngle_2 = toDegree(atan(tanFA_2))
  }
  
  private mutating func updateAngleRange() {
    _startAngle = heading! - fieldAngle_2
    if _startAngle < 0 {
      _startAngle += 360
    }
    _endAngle = heading! + fieldAngle_2
    if _endAngle > 360 {
      _endAngle -= 360
    }
  }
  
  /**
   * 添付のカメラの（横長画像時の）画角を得る
   *
   * -returns 横長画像時の画角
   */
  private func getFieldAngle() -> Double {
    return 62.0
  }
}

/**
 * 風景に関する情報の画面への描画を司るクラス
 */
class SceneRenderer: NSObject, CALayerDelegate {
  
  // POIの管理オブジェクト
  private let poiManager: PoiManager
  
  // 方位バーの描画を担当するオブジェクト
  private let directionRenderer: DirectionRenderer
  
  // 各種POIに関する情報の描画を担当するプロジェクト
  private let poiRenderer: PoiRenderer
  
  // 描画全般で使用するパラメータ
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
    poiRenderer = PoiRenderer(poiManager: poiManager)
    super.init()
    
    self.layer = layer
    layer.delegate = self
    
    params.setViewParameter(size: layer.frame.size)
  }
  
  /**
   * 位置の大幅変更時に呼び出される
   * （角度次第で）描画対象となるPOIを選定する
   *
   * - parameter location 自分の位置
   */
  func updateLocation(location: CLLocationCoordinate2D) {
    // 対象POIの再計算
    poiManager.setCurrentPosition(position: location)
    layer!.setNeedsDisplay()
  }
  
  /**
   * 向きの変更時に呼び出される
   *
   * - parameter heading 機器の（背面の）方位
   */
  func updateHeading(heading: Double) {
    params.heading = heading
    layer!.setNeedsDisplay()
  }
  
  /**
   * 機器の縦横の変更時に呼び出される
   *
   * - parameter to 機器の画面の（機器の向きに準じた）サイズ
   */
  func changeOrientation(to size: CGSize) {
//    layer!.bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)
//    adjustLayerPosition()
    params.setViewParameter(size: size)
    poiRenderer.setViewParameter(params)
    layer!.setNeedsDisplay()
  }
  
  func zoom(_ zoom: Double) {
//    adjustLayerPosition()
    params.zoom = zoom
    layer!.setNeedsDisplay()
  }
  
//  private func adjustLayerPosition() {
//    let parentSize = layer!.superlayer!.bounds.size
//    layer!.position = CGPoint(x: parentSize.width * 0.5, y: parentSize.height * 0.5)
//  }
  
  /**
   * 機器の縦横の変更時に呼び出される
   *
   * - parameter to 機器の画面の（機器の向きに準じた）サイズ
   */
  func tapped(at point: CGPoint) {
    poiRenderer.tapped(at: point)
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
    directionRenderer.draw(params: params)

    // POIの描画
    poiRenderer.draw(params: params)
    
    UIGraphicsPopContext()
    ctx.restoreGState()
  }
  
}

