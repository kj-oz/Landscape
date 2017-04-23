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
    
    let request = URLRequest(url: URL(string: "https://mapwalk-help.blogspot.jp/?m=1")!)
    webView.loadRequest(request)
  }
}
