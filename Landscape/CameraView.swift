//
//  CameraView.swift
//  Landscape
//
//  Created by KO on 2017/01/04.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit
import AVFoundation

class CameraView: UIView {

  var previewLayer: AVCaptureVideoPreviewLayer {
    return layer as! AVCaptureVideoPreviewLayer
  }
  
  var session: AVCaptureSession? {
    get {
      return previewLayer.session
    }
    set {
      previewLayer.session = newValue
    }
  }
  
  func addDdecoration(_ drawer: CALayerDelegate) -> CALayer {
    let newLayer = CALayer()
    newLayer.delegate = drawer
    newLayer.frame = self.bounds
    self.layer.addSublayer(newLayer)
    return newLayer
  }
  
  // MARK: UIView
  override class var layerClass: AnyClass {
    return AVCaptureVideoPreviewLayer.self
  }
}
