//
//  CustomButton.swift
//  KLibrary
//
//  Created by KO on 2017/02/24.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit

/// Disable時の背景色や枠、角丸を指定できるカスタムボタン
@IBDesignable class CustomButton: UIButton {

  // 角丸の半径(0で四角形)
  @IBInspectable var cornerRadius: CGFloat = 0.0
  
  // 枠
  @IBInspectable var borderColor: UIColor = UIColor.clear
  @IBInspectable var borderWidth: CGFloat = 0.0
  
  // Disableになる前の背景色
  private var originalBackgroundColor = UIColor.white
  
  // Disable時の背景色
  @IBInspectable var disabledBackgroundColor: UIColor?
  
  
  // 描画時に呼び出される
  // この中で背景色を変えてもうまくいかないので、プロパティの変更を監視して設定
  override func draw(_ rect: CGRect) {
    // 角丸
    layer.cornerRadius = cornerRadius
    clipsToBounds = (cornerRadius > 0)
    
    // 枠線
    layer.borderColor = borderColor.cgColor
    layer.borderWidth = borderWidth
    
    super.draw(rect)
  }
  
  // 背景色プロパティ
  override var backgroundColor: UIColor? {
    didSet {
      if isEnabled {
        // Enable時の設定値を記憶する
        originalBackgroundColor = backgroundColor!
      }
    }
  }
  
  // 使用可・不可の状態のプロパティ
  override var isEnabled: Bool {
    didSet {
      // 設定時・解除時に背景色を変更
      if isEnabled {
        backgroundColor = originalBackgroundColor
      } else {
        backgroundColor = disabledBackgroundColor
      }
    }
  }
}

