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
                    if isVisible {
                        TextField(placeholder, text: $text)
                            .multilineTextAlignment(.trailing)
                            .textContentType(textContentType)
                            .submitLabel(.done)
                            .focused($isFocused)
                    } else {
                        SecureField(placeholder, text: $text)
                            .multilineTextAlignment(.trailing)
                            .textContentType(textContentType)
                            .submitLabel(.done)
                            .focused($isFocused)
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
                            Text(maskString)
                                .font(.body.monospaced())
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity,
                                       maxHeight: .infinity,
                                       alignment: .topLeading)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
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
            if style == .multiLine && !isVisible {
                isVisible = true
                isMultilineFocused = true
            } else if style == .singleLine {
                isFocused = true
            } else if style == .multiLine && isVisible {
                isMultilineFocused = true
            }
        }
    }

    private var maskString: String {
        text.map { $0.isNewline ? "\n" : "•" }.joined()
    }
}
