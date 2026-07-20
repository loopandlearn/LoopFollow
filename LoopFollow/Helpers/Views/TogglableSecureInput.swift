// LoopFollow
// TogglableSecureInput.swift

import SwiftUI

struct TogglableSecureInput: View {
    enum Style { case singleLine, multiLine }

    let placeholder: String
    @Binding var text: String
    let style: Style
    var textContentType: UITextContentType? = nil

    @State private var isVisible = false
    @FocusState private var isFocused: Bool
    @FocusState private var isMultilineFocused: Bool

    var body: some View {
        HStack(alignment: .top) {
            Group {
                switch style {
                case .singleLine:
                    ZStack(alignment: .trailing) {
                        if isVisible {
                            TextField(placeholder, text: $text)
                                .multilineTextAlignment(.trailing)
                                .textContentType(textContentType)
                                .submitLabel(.done)
                                .focused($isFocused)
                        } else {
                            // A real (masked) SecureField, not static text, so the
                            // value stays editable while hidden and — crucially —
                            // iOS AutoFill/keychain has a secure field to fill.
                            SecureField(placeholder, text: $text)
                                .multilineTextAlignment(.trailing)
                                .textContentType(textContentType)
                                .submitLabel(.done)
                                .focused($isFocused)
                        }
                    }

                case .multiLine:
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $text)
                            .focused($isMultilineFocused)
                            .frame(minHeight: 100)
                            .opacity(isVisible ? 1 : 0)
                            .disabled(!isVisible)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    if isMultilineFocused {
                                        Spacer()
                                        Button("Done") {
                                            isMultilineFocused = false
                                        }
                                    }
                                }
                            }

                        if !isVisible {
                            HStack {
                                Spacer()
                                Text(maskString)
                                    .font(.body.monospaced())
                                    .foregroundColor(.primary)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                    .frame(minHeight: 100)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .privacySensitive()

            Button { isVisible.toggle() } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            switch style {
            case .singleLine:
                // The hidden state is already an editable SecureField, so tapping
                // just focuses it — no need to reveal the plaintext to type.
                isFocused = true
            case .multiLine:
                // The multi-line editor is only editable once revealed.
                if !isVisible { isVisible = true }
                isMultilineFocused = true
            }
        }
    }

    private var maskString: String {
        text.map { $0.isNewline ? "\n" : "•" }.joined()
    }
}
