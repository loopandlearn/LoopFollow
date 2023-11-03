//
//  SecondViewController.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/1/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import UIKit
import WebKit



class NightscoutViewController: UIViewController {

    @IBOutlet weak var webView: WKWebView!
    
    var appStateController: AppStateController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if UserDefaultsRepository.forceDarkMode.value {
            overrideUserInterfaceStyle = .dark
        }
        
        var url = UserDefaultsRepository.url.value
        let token = UserDefaultsRepository.token.value
        
        if token != "" {
            url = url + "?token=" + token
        }
        
        guard let myUrl = URL(string: url) else { return  }

        webView.configuration.preferences.javaScriptEnabled = true
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.load(URLRequest(url: myUrl))
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(reloadWebView(_:)), for: .valueChanged)
        webView.scrollView.addSubview(refreshControl)
        
        self.webView.uiDelegate = self
    }

    @objc func reloadWebView(_ sender: UIRefreshControl) {
        clearWebCache() // Clear web cache
        webView.reload()
        sender.endRefreshing()
    }
    // New code to Clear web cache
    func clearWebCache() {
        let dataStore = WKWebsiteDataStore.default()
        let date = Date(timeIntervalSince1970: 0)
        dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: date) {
            print("Web cache cleared.")
        }
    }
    
    // this handles target=_blank links by opening them in the same view
    func webView(webView: WKWebView!, createWebViewWithConfiguration configuration: WKWebViewConfiguration!, forNavigationAction navigationAction: WKNavigationAction!, windowFeatures: WKWindowFeatures!) -> WKWebView! {
        if let frame = navigationAction.targetFrame,
            frame.isMainFrame {
            return nil
        }
        // for _blank target or non-mainFrame target
        webView.load(navigationAction.request)
        return nil    }
}

// MARK:- WKUIDelegate implementation
extension NightscoutViewController: WKNavigationDelegate, WKUIDelegate {
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        
        let alertCtrl = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        
        alertCtrl.addAction(UIAlertAction(title: "OK", style: .default) { action in
            completionHandler(true)
        })

        alertCtrl.addAction(UIAlertAction(title: "Cancel", style: .cancel) { action in
            completionHandler(false)
        })
        
        present(alertCtrl, animated: true)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        guard let _ = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
     
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, shouldStartLoadWith request: URLRequest) -> Bool {
        
        guard let url = request.url else {
            return false
        }
        
        NSLog("Should start: \(url.absoluteString)")
        return true
    }
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        
        return nil
    }
    

 
}
