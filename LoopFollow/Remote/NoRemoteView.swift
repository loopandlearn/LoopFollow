// LoopFollow
// NoRemoteView.swift
// Created by Jonas Björkert.

import SwiftUI

struct NoRemoteView: View {
    private let remoteController = TrioNightscoutRemoteController()

    var body: some View {
        NavigationView {
            VStack {
                ErrorMessageView(
                    message: "Remote commands are currently only available for Trio and Loop."
                )
            }
        }
    }
}
