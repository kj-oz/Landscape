//
//  CameraView.swift
//  Landscape
//
//  Created by KO on 2017/01/04.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit
import AVFoundation

/// カメラのプレビューを表示するビュー
class CameraView: UIView {

  /// プレビューを表示するレイヤ
  var previewLayer: AVCaptureVideoPreviewLayer {
    return layer as! AVCaptureVideoPreviewLayer
  }
  
  /// ビデオ・セッション
  var session: AVCaptureSession? {
    get {
      return previewLayer.session
    }
    set {
      previewLayer.session = newValue
    }
  }
  
  
  // レイヤで使用するクラスを返す
  override class var layerClass: AnyClass {
    return AVCaptureVideoPreviewLayer.self
  }
}
