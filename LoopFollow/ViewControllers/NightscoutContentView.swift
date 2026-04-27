// LoopFollow
// NightscoutContentView.swift

import SwiftUI

struct NightscoutContentView: UIViewControllerRepresentable {
    func makeUIViewController(context _: Context) -> NightscoutViewController {
        NightscoutViewController()
    }

    func updateUIViewController(_ uiViewController: NightscoutViewController, context _: Context) {
        uiViewController.overrideUserInterfaceStyle = Storage.shared.appearanceMode.value.userInterfaceStyle
    }
}
