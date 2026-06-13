// LoopFollow
// NightscoutContentView.swift

import SwiftUI

struct NightscoutContentView: View {
    @ObservedObject private var url = Storage.shared.url
    @ObservedObject private var token = Storage.shared.token

    var body: some View {
        if url.value.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "network")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text("Please enter your Nightscout URL in Settings.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        } else {
            NightscoutWebView()
                // NightscoutViewController loads the page once in viewDidLoad,
                // so recreate it when the URL or token changes.
                .id(url.value + "|" + token.value)
        }
    }
}

private struct NightscoutWebView: UIViewControllerRepresentable {
    func makeUIViewController(context _: Context) -> NightscoutViewController {
        NightscoutViewController()
    }

    func updateUIViewController(_ uiViewController: NightscoutViewController, context _: Context) {
        uiViewController.overrideUserInterfaceStyle = Storage.shared.appearanceMode.value.userInterfaceStyle
    }
}
