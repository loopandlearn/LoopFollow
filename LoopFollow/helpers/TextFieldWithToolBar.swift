//
//  TextFieldWithToolBar.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-07-27.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import SwiftUI
import UIKit
import HealthKit

public struct TextFieldWithToolBar: UIViewRepresentable {
    @Binding var quantity: HKQuantity
    var placeholder: String
    var textColor: UIColor
    var textAlignment: NSTextAlignment
    var keyboardType: UIKeyboardType
    var autocapitalizationType: UITextAutocapitalizationType
    var autocorrectionType: UITextAutocorrectionType
    var shouldBecomeFirstResponder: Bool
    var maxLength: Int?
    var isDismissible: Bool
    var textFieldDidBeginEditing: (() -> Void)?
    var unit: HKUnit
    var allowDecimalSeparator: Bool

    public init(
        quantity: Binding<HKQuantity>,
        placeholder: String,
        textColor: UIColor = .label,
        textAlignment: NSTextAlignment = .right,
        keyboardType: UIKeyboardType = .decimalPad,
        autocapitalizationType: UITextAutocapitalizationType = .none,
        autocorrectionType: UITextAutocorrectionType = .no,
        shouldBecomeFirstResponder: Bool = false,
        maxLength: Int? = nil,
        isDismissible: Bool = true,
        textFieldDidBeginEditing: (() -> Void)? = nil,
        unit: HKUnit,
        allowDecimalSeparator: Bool = true
    ) {
        _quantity = quantity
        self.placeholder = placeholder
        self.textColor = textColor
        self.textAlignment = textAlignment
        self.keyboardType = keyboardType
        self.autocapitalizationType = autocapitalizationType
        self.autocorrectionType = autocorrectionType
        self.shouldBecomeFirstResponder = shouldBecomeFirstResponder
        self.maxLength = maxLength
        self.isDismissible = isDismissible
        self.textFieldDidBeginEditing = textFieldDidBeginEditing
        self.unit = unit
        self.allowDecimalSeparator = allowDecimalSeparator
    }

    public func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        context.coordinator.textField = textField
        textField.inputAccessoryView = isDismissible ? makeDoneToolbar(for: textField, context: context) : nil
        textField.addTarget(context.coordinator, action: #selector(Coordinator.editingDidBegin), for: .editingDidBegin)
        textField.addTarget(context.coordinator, action: #selector(Coordinator.editingDidEnd), for: .editingDidEnd)
        textField.delegate = context.coordinator
        textField.text = quantity.doubleValue(for: unit) == 0 ? "" : context.coordinator.format(quantity: quantity, for: unit)
        textField.placeholder = placeholder
        return textField
    }

    private func makeDoneToolbar(for textField: UITextField, context: Context) -> UIToolbar {
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50))
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(
            image: UIImage(systemName: "keyboard.chevron.compact.down"),
            style: .done,
            target: textField,
            action: #selector(UITextField.resignFirstResponder)
        )
        let clearButton = UIBarButtonItem(
            image: UIImage(systemName: "trash"),
            style: .plain,
            target: context.coordinator,
            action: #selector(Coordinator.clearText)
        )

        toolbar.items = [clearButton, flexibleSpace, doneButton]
        toolbar.sizeToFit()
        return toolbar
    }

    public func updateUIView(_ textField: UITextField, context: Context) {
        if !context.coordinator.isEditing {
            let newText = quantity.doubleValue(for: unit) == 0 ? "" : context.coordinator.format(quantity: quantity, for: unit)
            if textField.text != newText {
                textField.text = newText
            }
        }

        textField.textColor = textColor
        textField.textAlignment = textAlignment
        textField.keyboardType = keyboardType
        textField.autocapitalizationType = autocapitalizationType
        textField.autocorrectionType = autocorrectionType

        if shouldBecomeFirstResponder, !context.coordinator.didBecomeFirstResponder {
            if textField.window != nil, textField.becomeFirstResponder() {
                context.coordinator.didBecomeFirstResponder = true
            }
        } else if !shouldBecomeFirstResponder, context.coordinator.didBecomeFirstResponder {
            context.coordinator.didBecomeFirstResponder = false
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self, maxLength: maxLength, unit: unit)
    }

    public final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: TextFieldWithToolBar
        var textField: UITextField?
        let maxLength: Int?
        var didBecomeFirstResponder = false
        var isEditing = false
        var unit: HKUnit

        init(_ parent: TextFieldWithToolBar, maxLength: Int?, unit: HKUnit) {
            self.parent = parent
            self.maxLength = maxLength
            self.unit = unit
        }

        @objc fileprivate func clearText() {
            DispatchQueue.main.async {
                self.parent.quantity = HKQuantity(unit: self.unit, doubleValue: 0)
                self.textField?.text = ""
            }
        }

        @objc fileprivate func editingDidBegin(_ textField: UITextField) {
            isEditing = true
            DispatchQueue.main.async {
                if self.parent.quantity.doubleValue(for: self.unit) == 0 {
                    textField.text = ""
                }
                textField.moveCursorToEnd()
            }
        }

        @objc fileprivate func editingDidEnd(_ textField: UITextField) {
            isEditing = false
            DispatchQueue.main.async {
                let decimalSeparator = Locale.current.decimalSeparator ?? "."
                let text = textField.text?.replacingOccurrences(of: decimalSeparator, with: ".") ?? ""
                if let number = Double(text) {
                    self.parent.quantity = HKQuantity(unit: self.unit, doubleValue: number)
                } else {
                    self.parent.quantity = HKQuantity(unit: self.unit, doubleValue: 0)
                }
                textField.text = self.format(quantity: self.parent.quantity, for: self.unit)
            }
        }

        func format(quantity: HKQuantity, for unit: HKUnit) -> String {
            let value = quantity.doubleValue(for: unit)
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = unit.preferredFractionDigits
            formatter.maximumFractionDigits = unit.preferredFractionDigits
            formatter.numberStyle = .decimal
            return formatter.string(from: NSNumber(value: value)) ?? ""
        }

        public func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            // Check if the input is a number or the decimal separator
            let decimalSeparator = Locale.current.decimalSeparator ?? "."
            let isNumber = CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: string))
            let isDecimalSeparator = (string == decimalSeparator && textField.text?.contains(decimalSeparator) == false)

            // Only proceed if the input is a valid number or decimal separator
            if isNumber || (isDecimalSeparator && parent.allowDecimalSeparator),
               let currentText = textField.text as NSString?
            {
                // Get the proposed new text
                let proposedTextOriginal = currentText.replacingCharacters(in: range, with: string)

                // Remove thousand separator
                let proposedText = proposedTextOriginal.replacingOccurrences(of: ",", with: "")

                // Try to convert proposed text to number
                if let number = Double(proposedText.replacingOccurrences(of: decimalSeparator, with: ".")) {
                    DispatchQueue.main.async {
                        self.parent.quantity = HKQuantity(unit: self.unit, doubleValue: number)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.parent.quantity = HKQuantity(unit: self.unit, doubleValue: 0)
                    }
                }
            }

            // Allow the change if it's a valid number or decimal separator
            return isNumber || (isDecimalSeparator && parent.allowDecimalSeparator)
        }

        public func textFieldDidBeginEditing(_: UITextField) {
            parent.textFieldDidBeginEditing?()
        }
    }
}

extension UITextField {
    func moveCursorToEnd() {
        dispatchPrecondition(condition: .onQueue(.main))
        let newPosition = endOfDocument
        selectedTextRange = textRange(from: newPosition, to: newPosition)
    }
}

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
