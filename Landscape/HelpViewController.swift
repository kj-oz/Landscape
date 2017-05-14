//
//  HelpViewController.swift
//  Landscape
//
//  Created by KO on 2017/04/23.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit

/// ヘルプ画面のコントローラ
class HelpViewController: UIViewController, UIWebViewDelegate {
  // ヘルプHTMLを表示するWEBビュー
  @IBOutlet weak var webView: UIWebView!
  
  // ビューのロード時に呼び出される
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "www")
    let request = URLRequest(url: url!)
    webView.delegate = self
    webView.loadRequest(request)
  }
  
  // MARK: - UIWebViewDelegate
  // リンククリック時に呼び出される
  func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest,
                        navigationType: UIWebViewNavigationType) -> Bool {
    if navigationType == .linkClicked &&
        (request.url!.scheme == "http" || request.url!.scheme == "https") {
      UIApplication.shared.open(request.url!, options: [:], completionHandler: nil)
      return false
    }
    return true
  }
}
