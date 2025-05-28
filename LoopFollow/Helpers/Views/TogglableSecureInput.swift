// LoopFollow
// TogglableSecureInput.swift
// Created by Jonas Björkert on 2025-05-28.

import SwiftUI

struct TogglableSecureInput: View {
    enum Style { case singleLine, multiLine }

    let placeholder: String
    @Binding var text: String
    let style: Style

    @State private var isVisible = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .top) {
            Group {
                switch style {
                case .singleLine:
                    if isVisible {
                        TextField(placeholder, text: $text).multilineTextAlignment(.trailing)
                    } else {
                        SecureField(placeholder, text: $text).multilineTextAlignment(.trailing)
                    }

                case .multiLine:
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $text)
                            .opacity(isVisible ? 1 : 0)
                            .focused($isFocused)
                            .frame(minHeight: 100)

                        if !isVisible {
                            Text(maskString)
                                .font(.body.monospaced())
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity,
                                       maxHeight: .infinity,
                                       alignment: .topLeading)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                    }
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .privacySensitive()
            .submitLabel(.done)

            Button { isVisible.toggle() } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
    }

    private var maskString: String {
        text.map { $0.isNewline ? "\n" : "•" }.joined()
    }
}
