//
//  CustomButton.swift
//  KLibrary
//
//  Created by KO on 2017/02/24.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit

/**
 * Disable時の背景色や枠、角丸を指定できるカスタムボタン
 */
@IBDesignable class CustomButton: UIButton {

  // 角丸の半径(0で四角形)
  @IBInspectable var cornerRadius: CGFloat = 0.0
  
  // 枠
  @IBInspectable var borderColor: UIColor = UIColor.clear
  @IBInspectable var borderWidth: CGFloat = 0.0
  
  // 背景
  private var originalBackgroundColor = UIColor.white
  @IBInspectable var disabledBackgroundColor: UIColor?
  
  override func draw(_ rect: CGRect) {
    // 角丸
    layer.cornerRadius = cornerRadius
    clipsToBounds = (cornerRadius > 0)
    
    // 枠線
    layer.borderColor = borderColor.cgColor
    layer.borderWidth = borderWidth
    
    super.draw(rect)
  }
  
  override var backgroundColor: UIColor? {
    didSet {
      if isEnabled {
        originalBackgroundColor = backgroundColor!
      }
    }
  }
  
  override var isEnabled: Bool {
    didSet {
      if isEnabled {
        backgroundColor = originalBackgroundColor
      } else {
        backgroundColor = disabledBackgroundColor
      }
    }
  }
  
  private func col(_ color: UIColor) -> String {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return String(format: "%.1f %.1f %.1f %.1f", red, green, blue, alpha)
  }
}

