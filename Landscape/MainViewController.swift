//
//  MainViewController.swift
//  Landscape
//
//  Created by KO on 2017/01/04.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit

/// メイン画面のコントローラ
class MainViewController: UIViewController, UIGestureRecognizerDelegate {
  
  // カメラの映像を表示するビュー
  @IBOutlet weak var cameraView: CameraView!
  
  // POIの情報を表示するビュー
  @IBOutlet weak var annotationView: UIView!
  
  // 各種ボタン
  @IBOutlet weak var plusButton: UIButton!
  @IBOutlet weak var minusButton: UIButton!
  @IBOutlet weak var targetButton: UIButton!
  
  /// ズームボタン押下時の処理
  ///
  /// - zoom: 画面のズーム
  /// - fieldAngle: 画角の調整
  /// - minimumElevation: 最低仰角の調整
  enum TargetActionType {
    case zoom
    case fieldAngle
    case minimumElevation
  }
  
  /// ズームボタン押下時の処理
  private var targetActionType: TargetActionType = .zoom
  
  /// 画角調整時にボタン1タップで変更する画角
  private let fieldAngleDelta = 0.1
  
  /// 最低見上げ角調整時にボタン1タップで変更する角度（tangent）
  private let elevationDelta = 0.0001
  
  /// ズーム値
  private var zoom: Int {
    get {
      return Int(renderer.zoom)
    }
    set {
      cameraManager.zoom = CGFloat(newValue)
      renderer.zoom = Double(newValue)
    }
  }
  
  /// 画角
  private var fieldAngle: Double {
    get {
      return renderer.fieldAngle
    }
    set {
      renderer.fieldAngle = newValue
    }
  }
  
  /// 最低見上げ角
  var minimumElevation: Double {
    get {
      return renderer.minimumElevation
    }
    set {
      renderer.minimumElevation = newValue
    }
  }
  
  /// アプリ名称
  private let appName = "風景ナビ"
  
  /// カメラのセッションを管理するオブジェクト
  private var cameraManager: CameraManager!
  
  /// 風景のラベルを描画するオブジェクト
  private var renderer: SceneRenderer!
  
  /// 位置情報を管理するオブジェクト
  private var locationManager: LocationManager!
  
  /// 各種のチェックを実行済みかどうか
  private var checked = false;
  
  /// ビューが非表示になる直前のサイズ
  private var prevViewSize: CGSize?
  
  // ビューのロード時に呼び出される
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let documentDir = FileUtil.documentDir
    print(documentDir)

    //ログをファイルに出力したい場合にコメントアウト
    //let formatter = DateFormatter()
    //formatter.dateFormat = "yyyyMMddHHmmss"
    //let log = String(format: "%@/%@.log", documentDir, formatter.string(from: Date()))
    //freopen(log.cString(using: String.Encoding.ascii)!, "a+", stdout)
    
    // 各種オブジェクトの初期化
    cameraManager = CameraManager(cameraView: cameraView)
    cameraManager.snapshotHandler = self.handleSnapshot
    
    renderer = SceneRenderer(layer: annotationView.layer, size: view.bounds.size)
    locationManager = LocationManager(renderer: renderer)
    
    fieldAngle = renderer.fieldAngle
    
    // 画面タップ
    let tapGesture = UITapGestureRecognizer(target: self,
                                            action: #selector(MainViewController.tapped(sender:)))
    tapGesture.delegate = self;
    
    // Viewに追加.
    self.view.addGestureRecognizer(tapGesture)
  }

  // ビューが画面に表示される直前に呼び出される
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    print("frame: \(view.frame.size), bounds: \(view.bounds.size)")
    if let prevSize = prevViewSize {
      if prevSize != view.bounds.size {
        viewWillTransition(to: view.bounds.size)
      }
    } else if UIDevice.current.orientation == UIDeviceOrientation.portrait {
      // 他の向きの場合はTransitイベントが発生するが、Portraitの場合は発生しない
      viewWillTransition(to: view.bounds.size)
    }

    updateButtonStatus()
  }
  
  // ビューが画面に表示された直後に呼び出される
  // アラートはこちらでないと出せない
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    // カメラセッションの状態を確認
    if checkCameraService() {
      cameraManager.startSession()
    }
    
    // 位置情報関係の状態を確認
    checkLocationService()
    
    checked = true
  }
  
  // ビューが画面から隠される直前に呼び出される
  override func viewWillDisappear(_ animated: Bool) {
    cameraManager.stopSession()
    
    super.viewWillDisappear(animated)
  }
  
  // 画面が自動的に回転すべきかどうか
  override var shouldAutorotate: Bool {
    return true
  }
  
  // 画面の回転を許容する方向
  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    return .all
  }
  
  // 画面が回転する直前に呼び出される
  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    
    viewWillTransition(to: size)
  }
  
  /// 画面の縦横の回転を各オブジェクトに通知する
  ///
  /// - Parameter size: 新しい画面サイズ
  private func viewWillTransition(to size: CGSize) {
    print("transit to: \(size)")
    cameraManager.changeOrientation(to: size)
    locationManager.changeOrientation(to: size)
  }
  
  // ステータスバーは表示しない
  override var prefersStatusBarHidden: Bool {
    return true
  }
  
  // 処理切り替えボタンタップ時
  @IBAction func targetTapped(_ sender: Any) {
    Logger.log("MainViewController.targetTapped \(view.bounds.size)")
    switch targetActionType {
    case .zoom:
      targetActionType = .fieldAngle
    case .fieldAngle:
      targetActionType = .minimumElevation
    case .minimumElevation:
      targetActionType = .zoom
    }
    updateButtonStatus()
    print("○ Target Button tapped: \(String(describing: targetButton.title(for: .normal)))")
  }
  
  // プラスボタンタップ時
  @IBAction func plusTapped(_ sender: Any) {
    switch targetActionType {
    case .zoom:
      UIView.animate(withDuration: 0.5, animations: { self.zoom *= 2 })
    case .fieldAngle:
      fieldAngle += fieldAngleDelta
    case .minimumElevation:
      minimumElevation += elevationDelta
    }
    updateButtonStatus()
    print("○ Plus Button tapped")
  }

  // マイナスボタンタップ時
  @IBAction func minusTapped(_ sender: Any) {
    switch targetActionType {
    case .zoom:
      UIView.animate(withDuration: 0.5, animations: { self.zoom /= 2 })
    case .fieldAngle:
      fieldAngle -= fieldAngleDelta
    case .minimumElevation:
      minimumElevation -= elevationDelta
    }
    updateButtonStatus()
    print("○ Minus Button tapped")
  }
  
  // 各種ボタンの状態の更新
  private func updateButtonStatus() {
    switch targetActionType {
    case .zoom:
      let maxZoom = Int(truncating: NSDecimalNumber(decimal: pow(2, Int(log2(cameraManager.maxZoom)))))
      minusButton.isEnabled = zoom > 1
      plusButton.isEnabled = zoom < maxZoom
      targetButton.setTitle("ズーム：\(zoom) 倍", for: .normal)
    case .fieldAngle:
      minusButton.isEnabled = true
      plusButton.isEnabled = true
      targetButton.setTitle(String(format: "水平画角：%.1f°", fieldAngle), for: .normal)
    case .minimumElevation:
      minusButton.isEnabled = true
      plusButton.isEnabled = true
      targetButton.setTitle(String(format: "最小仰角：%.2f%%", minimumElevation * 100.0), for: .normal)
    }
  }
  
  // カメラボタンタップ時
  @IBAction func cameraTapped(_ sender: Any) {
    cameraManager.takeSnapshot()
  }
  
  /// スナップショット取得時の処理
  ///
  /// - Parameter image: カメラ画像
  private func handleSnapshot(image: CGImage) {
    let rect = self.view.bounds
    let cropped = self.croppedImage(from: image, rect: rect)
    
    // 疑似スクリーンショットの保存
    UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
    let context = UIGraphicsGetCurrentContext()
    context?.draw(cropped, in: rect)
    self.renderer.drawScene(with: context!)
    if let capturedImage = UIGraphicsGetImageFromCurrentImageContext() {
      UIImageWriteToSavedPhotosAlbum(capturedImage, nil, nil, nil)
      print("save image")
    }
    UIGraphicsEndImageContext()
  }
  
  /// カメラ画像を与えられたrectに収まるように切り出す
  ///
  /// - Parameters:
  ///   - image: カメラ画像
  ///   - rect: 長方形
  /// - Returns: 切り出された画像
  private func croppedImage(from image: CGImage, rect: CGRect) -> CGImage {
    let iw = Double(image.width)
    let ih = Double(image.height)
    let vw = Double(rect.size.width)
    let vh = Double(rect.size.height)
    
    let sw = iw / vw
    let sh = ih / vh
    
    var ox = 0.0
    var oy = 0.0
    var w = iw
    var h = ih
    var s = 1.0
    if sw  > sh {
      s = sh
      w = vw * s
      ox = (iw - w) * 0.5
    } else {
      s = sw
      h = vh * s
      oy = (ih - h) * 0.5
    }
    
    if renderer.zoom > 1 {
      let factor = 1 / Double(zoom)
      ox += 0.5 * w * (1 - factor)
      w *= factor
      oy += 0.5 * h * (1 - factor)
      h *= factor
    }
    
    let cropRect = CGRect(x:ox, y:oy, width:w, height:h)
    let croppedImage = image.cropping(to: cropRect)
    return croppedImage!
  }
  
  // 画面タップ時
  @objc func tapped(sender: UITapGestureRecognizer) {
    renderer.tapped(at: sender.location(in: self.view))
  }
  
  /// 警告ダイアログを表示する
  ///
  /// - Parameters:
  ///   - message: 表示するメッセージ
  ///   - requireAuthorization: 設定画面の表示ボタンを表示するかどうか
  private func showWarning(message: String, requireAuthorization: Bool = false) {
    let alertController = UIAlertController(title: self.appName, message: message, preferredStyle: .alert)
    alertController.addAction(UIAlertAction(title: "了解", style: .cancel, handler: nil))
    if (requireAuthorization) {
      alertController.addAction(UIAlertAction(title: "設定", style: .`default`, handler: { action in
        UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!, options: [:], completionHandler: nil)
      }))
    }
    self.present(alertController, animated: true, completion: nil)
  }
  
  /// カメラの状態をチェックする
  ///
  /// - Returns: true: 正常に終了、false: 何らか失敗している
  private func checkCameraService() -> Bool {
    switch cameraManager.setupResult {
    case .success:
      return true
      
    case .notAuthorized:
      if !checked {
        let message = "\(self.appName)はカメラを使用する許可を与えられていません。\n" + "設定＞風景ナビで許可を与えてください。"
        showWarning(message: message, requireAuthorization: true)
      }
      
    case .configurationFailed:
      if !checked {
        showWarning(message: "カメラ画像を取得できません。")
      }
    }
    return false
  }
  
  /// 位置情報サービスの状態をチェックする
  private func checkLocationService() {
    // 位置情報関係の状態を確認
    if !locationManager.supportsLocation {
      if !checked {
        showWarning(message: "この端末では位置情報を利用できません。")
      }
    } else if !(locationManager.authorizationStatus == .authorizedWhenInUse ||
          locationManager.authorizationStatus == .authorizedAlways ||
          locationManager.authorizationStatus == .notDetermined) {
      if !checked {
        let message = "\(self.appName)は位置情報を使用する許可を与えられていません。\n" + "設定＞風景ナビで許可を与えてください。"
        showWarning(message: message, requireAuthorization: true)
      }
    }
  }
  
  @IBAction func exitFromHelp(_ segue: UIStoryboardSegue) {
    // 何もしない
  }
}
