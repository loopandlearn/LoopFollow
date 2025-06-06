// LoopFollow
// NightScoutViewController.swift
// Created by Jon Fawcett on 2020-06-05.

import UIKit
import WebKit

class NightscoutViewController: UIViewController {
    @IBOutlet var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        if Storage.shared.forceDarkMode.value {
            overrideUserInterfaceStyle = .dark
        }

        var url = ObservableUserDefaults.shared.url.value
        let token = Storage.shared.token.value

        if token != "" {
            url = url + "?token=" + token
        }

        guard let myUrl = URL(string: url) else { return }

        webView.configuration.preferences.javaScriptEnabled = true
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.load(URLRequest(url: myUrl))

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(reloadWebView(_:)), for: .valueChanged)
        webView.scrollView.addSubview(refreshControl)

        webView.uiDelegate = self
    }

    @objc func reloadWebView(_ sender: UIRefreshControl) {
        clearWebCache()
        webView.reload()
        sender.endRefreshing()
    }

    // New code to clear web cache
    func clearWebCache() {
        let dataStore = WKWebsiteDataStore.default()
        let cacheTypes = Set([WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache])
        let date = Date(timeIntervalSince1970: 0)
        dataStore.removeData(ofTypes: cacheTypes, modifiedSince: date) {
            print("Web cache cleared.")
        }
    }

    // this handles target=_blank links by opening them in the same view
    func webView(webView: WKWebView!, createWebViewWithConfiguration _: WKWebViewConfiguration!, forNavigationAction navigationAction: WKNavigationAction!, windowFeatures _: WKWindowFeatures!) -> WKWebView! {
        if let frame = navigationAction.targetFrame,
           frame.isMainFrame
        {
            return nil
        }
        // for _blank target or non-mainFrame target
        webView.load(navigationAction.request)
        return nil
    }
}

// MARK: - WKUIDelegate implementation

extension NightscoutViewController: WKNavigationDelegate, WKUIDelegate {
    func webView(_: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame _: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alertCtrl = UIAlertController(title: nil, message: message, preferredStyle: .alert)

        alertCtrl.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler(true)
        })

        alertCtrl.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completionHandler(false)
        })

        present(alertCtrl, animated: true)
    }

    func webView(_: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let _ = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    func webView(_: WKWebView, shouldStartLoadWith request: URLRequest) -> Bool {
        guard let url = request.url else {
            return false
        }

        NSLog("Should start: \(url.absoluteString)")
        return true
    }

    func webView(_ webView: WKWebView, createWebViewWith _: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures _: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }

        return nil
    }
}
