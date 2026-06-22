// LoopFollow
// ShareLogNoticeView.swift

import SwiftUI

struct ShareLogNoticeView: View {
    @State private var noticeText: String = ""
    let onCancel: () -> Void
    let onShare: (String) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Thanks for sharing these logs to help us find the problem. Please describe it in as much detail as possible — what time did it happen, what did you do, and what did you expect to happen that didn't?")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Description")) {
                    TextEditor(text: $noticeText)
                        .frame(minHeight: 180)
                }
            }
            .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
            .navigationBarTitle("Share Logs", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Share") { onShare(noticeText) }
                }
            }
        }
    }
}
