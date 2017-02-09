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
class MainViewController: UIViewController {

  // カメラの映像を表示するビュー
  @IBOutlet weak var cameraView: CameraView!
  
  // アプリ名称
  private let appName = "風景ガイド"
  
  // カメラのセッションを管理するオブジェクト
  private var cameraManager: CameraManager?
  
  // 風景のラベルを描画するオブジェクト
  private var renderer: SceneRenderer?
  
  // 位置情報を管理するオブジェクト
  private var locationManager: LocationManager?
  
  // ビューのロード時に呼び出される
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // 各種オブジェクトの初期化
    cameraManager = CameraManager(cameraView: cameraView!)
    let layer = cameraView.addDecorationLayer()
    renderer = SceneRenderer(layer: layer)
    
    locationManager = LocationManager(renderer: renderer!)
  }

  // ビューが画面に表示される直前に呼び出される
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    // カメラセッションの状態を確認
    switch cameraManager!.setupResult {
    case .success:
      cameraManager!.startSession()
      
    case .notAuthorized:
      let message = "\(self.appName)はカメラを使用する許可を与えられていません。\n" + "設定＞プライバシーで許可を与えてください。"
      showWarning(message: message, requireAuthorization: true)
      
    case .configurationFailed:
      showWarning(message: "カメラ画像を取得できません。")
    }
    
    // 位置情報関係の状態を確認
    if !locationManager!.supportsLocation {
      showWarning(message: "この端末では位置情報を利用できません。")
    } else if !(locationManager!.authorizationStatus == .authorizedWhenInUse ||
        locationManager!.authorizationStatus == .authorizedAlways) {
      let message = "\(self.appName)は位置情報を使用する許可を与えられていません。\n" + "設定＞プライバシーで許可を与えてください。"
      showWarning(message: message, requireAuthorization: true)
    }
    print("frame: \(view.frame.size), bounds: \(view.bounds.size)")
    
    if UIDevice.current.orientation == UIDeviceOrientation.portrait {
      // 他の向きの場合はTransitイベントが発生するが、Portraitだけは発生しない
      cameraManager!.viewWillTransition(to: view.bounds.size)
      locationManager!.viewWillTransition(to: view.bounds.size)
    }
  }
  
  // ビューが画面から隠される直前に呼び出される
  override func viewWillDisappear(_ animated: Bool) {
    cameraManager!.stopSession()
    
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
    
    print("trasit to: \(size)")
    cameraManager!.viewWillTransition(to: size)
    locationManager!.viewWillTransition(to: size)
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
  
}
