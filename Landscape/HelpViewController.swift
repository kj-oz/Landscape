//
//  HelpViewController.swift
//  Landscape
//
//  Created by KO on 2017/04/23.
//  Copyright © 2017年 KO. All rights reserved.
//

import UIKit

class HelpViewController: UIViewController,UIWebViewDelegate {
  
  @IBOutlet weak var webView: UIWebView!
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let url = URL(string: "https://landscape-help.blogspot.jp")
    let request = URLRequest(url: url!)
    webView.loadRequest(request)
  }
}
