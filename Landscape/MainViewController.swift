//
//  MainViewController.swift
//  Landscape
//
//  Created by KO on 2017/01/04.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit

/**
 * メイン画面のコントローラ
 */
class MainViewController: UIViewController, UIGestureRecognizerDelegate {
  /**
   * ズームボタン押下時の処理
   */
  enum TargetActionType {
    case imageZoom          // ズーム
    case fieldAngleAdjust   // 画角の調整
  }

  // ズームボタン押下時の処理
  private var targetActionType: TargetActionType = .imageZoom
  
  // 画角調整時にボタン1タップで変更する画角
  private let fieldAngleDelta = 1.0
  
  // カメラの映像を表示するビュー
  @IBOutlet weak var cameraView: CameraView!
  
  // POIの情報を表示するビュー
  @IBOutlet weak var annotationView: UIView!
  
  // 各種ボタン
  @IBOutlet weak var zoominButton: UIButton!
  @IBOutlet weak var zoomoutButton: UIButton!
  @IBOutlet weak var targetButton: UIButton!
  
  // ズーム値
  private var zoom: Int {
    get {
      return Int(renderer.zoom)
    }
    set {
      cameraManager.zoom = CGFloat(newValue)
      renderer.zoom = Double(newValue)
    }
  }
  
  // 画角
  private var fieldAngle: Double {
    get {
      return renderer.fieldAngle
    }
    set {
      renderer.fieldAngle = newValue
    }
  }
  
  // アプリ名称
  private let appName = "風景ガイド"
  
  // カメラのセッションを管理するオブジェクト
  private var cameraManager: CameraManager!
  
  // 風景のラベルを描画するオブジェクト
  private var renderer: SceneRenderer!
  
  // 位置情報を管理するオブジェクト
  private var locationManager: LocationManager!
  
  // ビューのロード時に呼び出される
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // 各種オブジェクトの初期化
    cameraManager = CameraManager(cameraView: cameraView)
    renderer = SceneRenderer(layer: annotationView.layer)
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
    
    // カメラセッションの状態を確認
    if checkCameraService() {
      cameraManager.startSession()
    }
    
    // 位置情報関係の状態を確認
    checkLocationService()
    
    print("frame: \(view.frame.size), bounds: \(view.bounds.size)")
    if UIDevice.current.orientation == UIDeviceOrientation.portrait {
      // 他の向きの場合はTransitイベントが発生するが、Portraitの場合は発生しない
      viewWillTransition(to: view.bounds.size)
    }

    updateButtonStatus()
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
  
  /**
   * 画面回転時に、各オブジェクトにそれを通知する
   */
  private func viewWillTransition(to size: CGSize) {
    print("transit to: \(size)")
    cameraManager.viewWillTransition(to: size)
    locationManager.viewWillTransition(to: size)
  }
  
  // ステータスバーは表示しない
  override var prefersStatusBarHidden: Bool {
    return true
  }
  
  // 処理切り替えボタンタップ時
  @IBAction func targetTapped(_ sender: Any) {
    targetActionType = targetActionType == .imageZoom ? .fieldAngleAdjust : .imageZoom
    updateButtonStatus()
  }
  
  // プラスボタンタップ時
  @IBAction func zoominTapped(_ sender: Any) {
    if targetActionType == .imageZoom {
      UIView.animate(withDuration: 0.5, animations: { self.zoom *= 2 })
    } else {
      fieldAngle += fieldAngleDelta
    }
    updateButtonStatus()
  }

  // マイナスボタンタップ時
  @IBAction func zoomoutTapped(_ sender: Any) {
    if targetActionType == .imageZoom {
      UIView.animate(withDuration: 0.5, animations: { self.zoom /= 2 })
    } else {
      fieldAngle -= fieldAngleDelta
    }
    updateButtonStatus()
  }
  
  // 各種ボタンの状態の更新
  private func updateButtonStatus() {
    if targetActionType == .imageZoom {
      let maxZoom = Int(NSDecimalNumber(decimal: pow(2, Int(log2(cameraManager.getMaxZoom()!)))))
      zoomoutButton.isEnabled = zoom > 1
      zoominButton.isEnabled = zoom < maxZoom
      targetButton.setTitle("ズーム：\(zoom) 倍", for: .normal)
    } else {
      zoomoutButton.isEnabled = true
      zoominButton.isEnabled = true
      targetButton.setTitle(String(format: "水平画角：%.1f°", fieldAngle), for: .normal)
    }
  }
  
  /**
   * 警告ダイアログを表示する
   *
   * - parameter message: 表示するメッセージ
   * - parameter requireAuthrization: 設定画面の表示ボタンを表示するかどうか
   */
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
  
  // 画面タップ時
  func tapped(sender: UITapGestureRecognizer) {
    renderer.tapped(at: sender.location(in: self.view))
  }
  
  /**
   * カメラの状態をチェックする
   *
   * - returns true: 正常に終了、false: 何らか失敗している
   */
  private func checkCameraService() -> Bool {
    // カメラセッションの状態を確認
    switch cameraManager.setupResult {
    case .success:
      return true
      
    case .notAuthorized:
      let message = "\(self.appName)はカメラを使用する許可を与えられていません。\n" + "設定＞プライバシーで許可を与えてください。"
      showWarning(message: message, requireAuthorization: true)
      
    case .configurationFailed:
      showWarning(message: "カメラ画像を取得できません。")
    }
    return false
  }
  
  /**
   * 位置情報サービスの状態をチェックする
   */
  private func checkLocationService() {
    // 位置情報関係の状態を確認
    if !locationManager.supportsLocation {
      showWarning(message: "この端末では位置情報を利用できません。")
    } else if !(locationManager.authorizationStatus == .authorizedWhenInUse ||
      locationManager.authorizationStatus == .authorizedAlways) {
      let message = "\(self.appName)は位置情報を使用する許可を与えられていません。\n" + "設定＞プライバシーで許可を与えてください。"
      showWarning(message: message, requireAuthorization: true)
    }
  }
}
