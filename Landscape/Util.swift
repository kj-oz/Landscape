//
//  Util.swift
//  Landscape
//
//  Created by KO on 2017/01/26.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit
import AVFoundation
import CoreLocation


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

func toRadian(_ degree: Double) -> Double {
  return degree / 180 * M_PI
}

func toDegree(_ radian: Double) -> Double {
  return radian * 180 / M_PI
}


