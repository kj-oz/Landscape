//
//  HelpViewController.swift
//  Landscape
//
//  Created by KO on 2017/04/23.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit

/// ヘルプ画面のコントローラ
class HelpViewController: UIViewController,UIWebViewDelegate {
  // ヘルプHTMLを表示するWEBビュー
  @IBOutlet weak var webView: UIWebView!
  
  // ビューのロード時に呼び出される
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let url = URL(string: "https://landscape-help.blogspot.jp")
    let request = URLRequest(url: url!)
    webView.loadRequest(request)
  }
}
