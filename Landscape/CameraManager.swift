//
//  CameraManager.swift
//  Landscape
//
//  Created by KO on 2017/01/06.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit
import AVFoundation

/// カメラ画像取得のセッションを管理するクラス
class CameraManager: NSObject {

  /// ビデオ・セッションのセットアップの結果のENUM
  enum SessionSetupResult {
    case success
    case notAuthorized
    case configurationFailed
  }
  
  /// 対象のビュー
  private var cameraView: CameraView
  
  /// 対象のカメラ
  private var camera: AVCaptureDevice?

  /// ビデオ・セッション
  private let session = AVCaptureSession()
  
  /// ビデオ・セッションが動作中かどうか
  private var isSessionRunning = false
  
  /// ビデオ・セッションに関する処理を実行する非同期キュー
  private let sessionQueue = DispatchQueue(label: "session queue", attributes: [], target: nil)
  
  /// ビデオ・セッションのセットアップの結果
  var setupResult: SessionSetupResult = .success
  
  /// ビデオ・セッションのKVOのコンテキスト
  private var sessionRunningObserveContext = 0
  
  /// カメラの表示倍率
  var zoom: CGFloat = 1.0 {
    didSet {
      // camera.videoZoomFactorを設定しても、ちょうど指定した倍率にはならないため、Viewのtransformで調整
      // transformによる変形はViewの中心を原点に働く
      let scale = zoom / oldValue
      if zoom == 1.0 {
        cameraView.transform = CGAffineTransform.identity
      } else {
        cameraView.transform = cameraView.transform.scaledBy(x: scale, y: scale)
      }
    }
  }
  
  /// アプリケーション的な最大ズーム
  private let appMaxZoom: CGFloat = 8
  
  /// 最大ズーム
  var maxZoom: CGFloat {
    if let activeFormat = camera?.activeFormat {
      return CGFloat(min(activeFormat.videoMaxZoomFactor, appMaxZoom))
    }
    return appMaxZoom
  }
  
  
  /// コンストラクタ
  ///
  /// - Parameter cameraView: 対象のカメラビュー
  init(cameraView: CameraView) {
    self.cameraView = cameraView
    super.init()
    cameraView.session = session
    cameraView.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
    
    sessionQueue.async { [unowned self] in
      self.configureSession()
    }
  }
  
  /// ビデオ・セッションを開始する
  func startSession() {
    sessionQueue.async { [unowned self] in
      self.addObservers()
      self.session.startRunning()
      self.isSessionRunning = self.session.isRunning
    }
  }
  
  /// ビデオ・セッションを中段する
  func stopSession() {
    sessionQueue.async { [unowned self] in
      if self.setupResult == .success {
        self.session.stopRunning()
        self.isSessionRunning = self.session.isRunning
        self.removeObservers()
      }
    }
  }
  
  /// 画面の回転（縦横の変更）時に呼び出される
  ///
  /// - Parameter size: 新たな画面サイズ
  func changeOrientation(to size: CGSize) {
    if let videoPreviewLayerConnection = cameraView.previewLayer.connection {
      let deviceOrientation = UIDevice.current.orientation
      guard let newVideoOrientation = deviceOrientation.videoOrientation, deviceOrientation.isPortrait || deviceOrientation.isLandscape else {
        return
      }
      
      videoPreviewLayerConnection.videoOrientation = newVideoOrientation
    }
  }
  
  /// ビデオ・セッションを準備する
  private func configureSession() {
    if setupResult != .success {
      return
    }
    
    session.beginConfiguration()
    session.sessionPreset = AVCaptureSessionPresetPhoto
    
    do {
      if let dualCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInDuoCamera, mediaType: AVMediaTypeVideo, position: .back) {
        camera = dualCameraDevice
      } else if let backCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .back) {
        camera = backCameraDevice
      }
      
      let videoDeviceInput = try AVCaptureDeviceInput(device: camera)
      
      if session.canAddInput(videoDeviceInput) {
        session.addInput(videoDeviceInput)
        DispatchQueue.main.async {
          let statusBarOrientation = UIApplication.shared.statusBarOrientation
          var initialVideoOrientation: AVCaptureVideoOrientation = .portrait
          if statusBarOrientation != .unknown {
            if let videoOrientation = statusBarOrientation.videoOrientation {
              initialVideoOrientation = videoOrientation
            }
          }
          
          self.cameraView.previewLayer.connection.videoOrientation = initialVideoOrientation
        }
      } else {
        print("Could not add video device input to the session")
        setupResult = .configurationFailed
      }
    }
    catch {
      print("Could not create video device input: \(error)")
      setupResult = .configurationFailed
    }
    
    session.commitConfiguration()
  }
  
  /// 中断されたビデオ・セッションの再開を試みる
  private func resumeInterruptedSession() {
    sessionQueue.async { [unowned self] in
      self.session.startRunning()
      self.isSessionRunning = self.session.isRunning
      if !self.session.isRunning {
        print("Unable to resume the session running")
      }
    }
  }
  
  /// ビデオ・セッションの状態の変化を監視する
  private func addObservers() {
    session.addObserver(self, forKeyPath: "running", options: .new, context: &sessionRunningObserveContext)
    
    NotificationCenter.default.addObserver(self, selector: #selector(sessionRuntimeError), name: Notification.Name("AVCaptureSessionRuntimeErrorNotification"), object: session)
    NotificationCenter.default.addObserver(self, selector: #selector(sessionWasInterrupted), name: Notification.Name("AVCaptureSessionWasInterruptedNotification"), object: session)
    NotificationCenter.default.addObserver(self, selector: #selector(sessionInterruptionEnded), name: Notification.Name("AVCaptureSessionInterruptionEndedNotification"), object: session)
  }
  
  /// ビデオ・セッションの状態の監視を解除する
  private func removeObservers() {
    NotificationCenter.default.removeObserver(self)
    
    session.removeObserver(self, forKeyPath: "running", context: &sessionRunningObserveContext)
  }
  
  /// ビデオ・セッションにエラーが発生した際のハンドラ
  ///
  /// - Parameter notification: 通知
  func sessionRuntimeError(notification: NSNotification) {
    guard let errorValue = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError else {
      return
    }
    
    let error = AVError(_nsError: errorValue)
    print("Capture session runtime error: \(error)")
    
    resumeInterruptedSession()
  }
  
  /// ビデオ・セッションが中断された際のハンドラ
  ///
  /// - Parameter notification: 通知
  func sessionWasInterrupted(notification: NSNotification) {
    if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?, let reasonIntegerValue = userInfoValue.integerValue, let reason = AVCaptureSessionInterruptionReason(rawValue: reasonIntegerValue) {
      print("Capture session was interrupted with reason \(reason)")
      
      resumeInterruptedSession()
    }
  }
  
  /// ビデオ・セッションの中断が解除された際のハンドラ
  ///
  /// - Parameter notification: 通知
  func sessionInterruptionEnded(notification: NSNotification) {
    print("Capture session interruption ended")
  }
  
  // MARK: - NSObject
  // KVOをサポートするために宣言が必要
  override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
  }
}
