//
//  MainViewController.swift
//  Landscape
//
//  Created by KO on 2017/01/04.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit
import AVFoundation
import CoreGraphics
import CoreLocation

class MainViewController: UIViewController {

  // カメラの映像を表示するビュー
  @IBOutlet weak var cameraView: CameraView!
  
  // アプリ名称
  private let appName = "風景ガイド"
  
  private var cameraManager: CameraManager?
  
//  // カメラビュー上の各種情報表示レイヤ
//  private var decorationLayer: CALayer?
  
  // 周囲の風景を管理するオブジェクト
  private var sceneManager: SceneManager?
  
  // ビューのロード時に呼び出される
  override func viewDidLoad() {
    super.viewDidLoad()
    
    cameraManager = CameraManager(cameraView: cameraView!)
    sceneManager = SceneManager(cameraView: cameraView)
    let layer = cameraView.addDdecoration(sceneManager!)
    layer.masksToBounds = false
    sceneManager!.layer = layer
  }

  // ビューが画面に表示される直前に呼び出される
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    switch cameraManager!.setupResult {
    case .success:
      cameraManager!.startSession()
      
    case .notAuthorized:
      let message = "\(self.appName)はカメラを使用する許可を与えられていません。\n" + "設定＞プライバシーで許可を与えてください。"
      showWarning(message: message, requireAuthorization: true)
      
    case .configurationFailed:
      showWarning(message: "カメラ画像を取得できません。")
    }
    
    if !sceneManager!.supportsLocation {
      showWarning(message: "この端末では位置情報を利用できません。")
    } else if !(sceneManager!.authorizationStatus == .authorizedWhenInUse ||
        sceneManager!.authorizationStatus == .authorizedAlways) {
      let message = "\(self.appName)は位置情報を使用する許可を与えられていません。\n" + "設定＞プライバシーで許可を与えてください。"
      showWarning(message: message, requireAuthorization: true)
    }
    
//    decorationLayer!.setNeedsDisplay()
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
    
    cameraManager!.viewWillTransition(to: size, with: coordinator)
    sceneManager!.viewWillTransition(to: size, with: coordinator)
  }
  
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

/**
 * UIDeviceOrientationに、対応するビデオの向き、方位基準の向きを返すプロパティを追加
 */
extension UIDeviceOrientation {
  var videoOrientation: AVCaptureVideoOrientation? {
    switch self {
    case .portrait: return .portrait
    case .portraitUpsideDown: return .portraitUpsideDown
    case .landscapeLeft: return .landscapeRight
    case .landscapeRight: return .landscapeLeft
    default: return nil
    }
  }
  var headingOrientation: CLDeviceOrientation {
    switch self {
    case .portrait: return .portrait
    case .portraitUpsideDown: return .portraitUpsideDown
    case .landscapeLeft: return .landscapeLeft
    case .landscapeRight: return .landscapeRight
    default: return .unknown
    }
  }
}

/**
 * UIInterfaceOrientationに、対応するビデオの向きを返すプロパティを追加
 */
extension UIInterfaceOrientation {
  var videoOrientation: AVCaptureVideoOrientation? {
    switch self {
    case .portrait: return .portrait
    case .portraitUpsideDown: return .portraitUpsideDown
    case .landscapeLeft: return .landscapeLeft
    case .landscapeRight: return .landscapeRight
    default: return nil
    }
  }
}

