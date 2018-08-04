//
//  SceneRenderer.swift
//  Landscape
//
//  Created by KO on 2017/01/04.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit
import CoreLocation

/// 描画全般で使用するパラメータを保持する構造体
struct RenderingParams {
  
  /// 画角の1/2のタンジェント（ズームなし）
  private var tanFA_2Base: Double = 0.0
  
  /// 画角の1/2のタンジェント（ズーム考慮）
  private var tanFA_2: Double = 0.0
  
  /// 画面の幅の1/2（ピクセル値）
  private var w_2: CGFloat = 0.0
  
  /// 画面のアスペクト比
  private var aspectRatio = 1.0
  
  /// 長辺方向の画角
  var fieldAngleH = 0.0 {
    didSet {
      fieldAngleV = toDegree(atan(aspectRatio * tan(toRadian(fieldAngleH / 2.0)))) * 2.0
      updateFieldAngleBase()
      UserDefaults.standard.set(fieldAngleH, forKey:"fieldAngleH")
    }
  }
  
  /// 短辺方向の画角
  private var fieldAngleV = 0.0
  
  /// デバイスの背面の向き
  var heading: Double? {
    didSet {
      updateAngleRange()
    }
  }
  
  /// ズーム
  var zoom: Double = 1.0 {
    didSet {
      updateFieldAngle()
    }
  }
  
  /// 画面左端の方位角度
  var startAngle: Double {
    return _startAngle
  }
  private var _startAngle = 0.0
  
  /// 画面右端の方位角度
  var endAngle: Double {
    return _endAngle
  }
  private var _endAngle = 0.0
  
  /// 画面（横方向）の画角の1/2
  private var fieldAngle_2 = 0.0
  
  /// 画面のサイズ
  var size:CGSize {
    didSet {
      print("new size:\(size)")
      w_2 = size.width / 2
      updateFieldAngleBase()
    }
  }
  
  /// 画面の幅
  var width: CGFloat {
    return size.width
  }
  
  /// 画面の高さ
  var height: CGFloat {
    return size.height
  }
  
  /// 画面の向きが縦向きかどうか
  var isPortrait: Bool {
    return size.height > size.width
  }
  
  /// 描画コンテキスト
  var context: CGContext?
  
  /// カメラの（横長画像時の）画角
  private var defaultFieldAngle: Double {
    var systemInfo = utsname()
    uname(&systemInfo)
    
    let mirror = Mirror(reflecting: systemInfo.machine)
    let identifier = mirror.children.reduce("") { identifier, element in
      guard let value = element.value as? Int8, value != 0 else { return identifier }
      return identifier + String(UnicodeScalar(UInt8(value)))
    }
    
    let path = Bundle.main.path(forResource: "device", ofType: "csv", inDirectory: "Data")
    let lines = FileUtil.readLines(path: path!)
    var first = true
    for line in lines {
      if first {
        first = false
      } else {
        var parts = line.components(separatedBy: ",")
        parts[0].remove(at: parts[0].startIndex)
        parts[1].remove(at: parts[1].index(before: parts[1].endIndex))
        let id =  parts[0] + "," + parts[1]
        if id == identifier {
          return Double(parts[2])!
        }
      }
    }
    if identifier.range(of: "iphone") != nil || identifier.range(of: "ipad") != nil {
      return 63.0
    } else {
      return 57.0
    }
  }
  

  /// コンストラクタ
  ///
  /// - Parameter size: 画面のサイズ（向きはどちらでも良い）
  init(size: CGSize) {
    self.size = size

    let h = Double(max(size.width, size.height))
    let v = Double(min(size.width, size.height))
    aspectRatio = v / h
    if let angle = UserDefaults.standard.object(forKey: "fieldAngleH") {
      fieldAngleH = angle as! Double
    } else {
      fieldAngleH = defaultFieldAngle
    }
    
    // initの中の設定ではdidSetは呼び出sれない
    fieldAngleV = toDegree(atan(aspectRatio * tan(toRadian(fieldAngleH / 2.0)))) * 2.0
  }
  
  /// ズーム1.0のときの画角の更新に伴う処理
  /// （画面の回転、画角の調整）
  private mutating func updateFieldAngleBase() {
    let fieldAngleBase = size.width > size.height ? fieldAngleH : fieldAngleV
    tanFA_2Base = tan(toRadian(fieldAngleBase / 2.0))
    updateFieldAngle()
  }
  
  /// ズームを考慮した画角の更新に伴う処理
  /// （ズーム変更時）
  private mutating func updateFieldAngle() {
    tanFA_2 = tanFA_2Base / zoom
    fieldAngle_2 = toDegree(atan(tanFA_2))
    updateAngleRange()
  }
  
  /// 端末の向きの変更時の処理
  private mutating func updateAngleRange() {
    if let heading = heading {
      _startAngle = angleAdd(to: heading, delta: -fieldAngle_2)
      _endAngle = angleAdd(to: heading, delta: fieldAngle_2)
      Logger.log(String(format:"▶ heading: %7.3f", heading))
    }
  }
  
  /// 与えられた方位の画面上のX座標を返す
  ///
  /// - Parameter azimuth: 方位
  /// - Returns: 画面上のX座標
  func calcX(of azimuth: Double) -> CGFloat {
    let a = angle(from: heading!, to: azimuth)
    return w_2 * CGFloat(1 + tan(toRadian(a)) / tanFA_2)
  }
}

/// 風景に関する情報の画面への描画を司るクラス
class SceneRenderer: NSObject, CALayerDelegate {
  
  /// POIの管理オブジェクト
  private let poiManager: PoiManager
  
  /// 方位バーの描画を担当するオブジェクト
  private let directionRenderer: DirectionRenderer
  
  /// 各種POIに関する情報の描画を担当するプロジェクト
  private let poiRenderer: PoiRenderer
  
  /// 描画全般で使用するパラメータ
  private var params: RenderingParams
  
  /// シミュレータ上かどうか
  var isSimulator = false {
    didSet {
      if isSimulator {
        let docDir = FileUtil.documentDir
        let imageH = UIImage(contentsOfFile: docDir.appending("/simu_h.png"))
        if let image = imageH {
          simuImageH = image.cgImage
        }
        let imageV = UIImage(contentsOfFile: docDir.appending("/simu_v.png"))
        if let image = imageV {
          simuImageV = image.cgImage
        }
      }
    }
  }
  
  /// シミュレータ用の背景画像（横）
  var simuImageH: CGImage! = nil
  
  /// シミュレータ用の背景画像（縦）
  var simuImageV: CGImage! = nil
  
  /// 描画対象のレイヤ
  var layer: CALayer
  
  /// ズーム
  var zoom: Double {
    get {
      return params.zoom
    }
    set {
      params.zoom = newValue
      layer.setNeedsDisplay()
    }
  }
  
  /// 画角
  var fieldAngle: Double {
    get {
      return params.fieldAngleH
    }
    set {
      params.fieldAngleH = newValue
      layer.setNeedsDisplay()
    }
  }
  
  /// 方位
  var heading: Double? {
    get {
      return params.heading
    }
    set {
      params.heading = newValue
      layer.setNeedsDisplay()
    }
  }
  
  /// 最低見上げ角
  var minimumElevation: Double {
    get {
      return poiManager.minimumElevation
    }
    set {
      poiManager.minimumElevation = newValue
      layer.setNeedsDisplay()
    }
  }
  
  /// コンストラクタ
  ///
  /// - Parameter layer: 描画対象レイヤ
  init(layer: CALayer, size: CGSize) {
    params = RenderingParams(size: size)
    poiManager = PoiManager()
    directionRenderer = DirectionRenderer()
    poiRenderer = PoiRenderer(poiManager: poiManager)
    self.layer = layer
    super.init()
    
    layer.delegate = self
    params.size = size
    poiRenderer.setViewParameter(params)
  }
  
  /// 位置の大幅変更時に呼び出される
  /// （角度次第で）描画対象となるPOIを選定する
  ///
  /// - Parameter location: 自分の位置
  func updateLocation(location: CLLocation) {
    // 対象POIの再計算
    poiManager.currentPosition = location
    layer.setNeedsDisplay()
  }
  
  /// 機器の縦横の変更時に呼び出される
  ///
  /// - Parameter size: 機器の画面の（機器の向きに準じた）サイズ
  func changeOrientation(to size: CGSize) {
    params.size = size
    poiRenderer.setViewParameter(params)
    layer.setNeedsDisplay()
  }
  
  /// 画面のタップ時に呼び出される
  ///
  /// - Parameter point: タップ位置
  func tapped(at point: CGPoint) {
    poiRenderer.tapped(at: point)
    layer.setNeedsDisplay()
  }
  
  // MARK: - CALayerDelegate
  // 描画時に呼び出される
  func draw(_ layer: CALayer, in ctx: CGContext) {
    if params.heading == nil {
      return
    }
    
    let start = Date()
    drawScene(with: ctx)
    let now = Date()
    Logger.log("> render : \(now.timeIntervalSince(start))s", now: now)
//    ctx.saveGState()
//    UIGraphicsPushContext(ctx)
//    params.context = ctx
//    let start = Date()
//
//    // シミュレータ上の場合、docフォルダーに所定の名称の画像があればそれを背景に表示する
//    if isSimulator {
//      let image = params.isPortrait ? simuImageV : simuImageH
//      if let image = image {
//        ctx.translateBy(x: 0.0, y: params.height)
//        ctx.scaleBy(x: 1.0, y: -1.0)
//        ctx.draw(image, in: CGRect(x:0, y:0, width: params.width, height: params.height))
//        ctx.translateBy(x: 0.0, y: params.height)
//        ctx.scaleBy(x: 1.0, y: -1.0)
//      }
//    }
//
//    // 方位の描画
//    directionRenderer.draw(params: params)
//
//    // POIの描画
//    poiRenderer.draw(params: params)
//
//    let now = Date()
//    Logger.log("> render : \(now.timeIntervalSince(start))s", now: now)
//    UIGraphicsPopContext()
//    ctx.restoreGState()
  }
  
  func drawScene(with ctx: CGContext) {
    ctx.saveGState()
    UIGraphicsPushContext(ctx)
    params.context = ctx
    
    // シミュレータ上の場合、docフォルダーに所定の名称の画像があればそれを背景に表示する
    if isSimulator {
      let image = params.isPortrait ? simuImageV : simuImageH
      if let image = image {
        ctx.translateBy(x: 0.0, y: params.height)
        ctx.scaleBy(x: 1.0, y: -1.0)
        ctx.draw(image, in: CGRect(x:0, y:0, width: params.width, height: params.height))
        ctx.translateBy(x: 0.0, y: params.height)
        ctx.scaleBy(x: 1.0, y: -1.0)
      }
    }
    
    // 方位の描画
    directionRenderer.draw(params: params)

    // POIの描画
    poiRenderer.draw(params: params)
    
    UIGraphicsPopContext()
    ctx.restoreGState()
  }
}

