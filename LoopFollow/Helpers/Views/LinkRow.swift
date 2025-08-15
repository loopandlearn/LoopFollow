// LoopFollow
// LinkRow.swift

import Foundation
import SwiftUI

@ViewBuilder
func LinkRow(
    title: String,
    icon: String,
    tint: Color = .white,
    url: URL
) -> some View {
    ActionRow(title: title, icon: icon, tint: tint) {
        UIApplication.shared.open(url)
    }
}
