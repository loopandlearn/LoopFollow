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

    @State private var alertMessage: String? = nil
    @State private var showAlert: Bool = false

    var textColor: UIColor
    var textAlignment: NSTextAlignment
    var autocapitalizationType: UITextAutocapitalizationType
    var autocorrectionType: UITextAutocorrectionType
    var shouldBecomeFirstResponder: Bool
    var maxLength: Int?
    var isDismissible: Bool
    var textFieldDidBeginEditing: (() -> Void)?
    var unit: HKUnit
    var allowDecimalSeparator: Bool
    var minValue: HKQuantity?
    var maxValue: HKQuantity?

    public init(
        quantity: Binding<HKQuantity>,
        textColor: UIColor = .label,
        textAlignment: NSTextAlignment = .right,
        autocapitalizationType: UITextAutocapitalizationType = .none,
        autocorrectionType: UITextAutocorrectionType = .no,
        shouldBecomeFirstResponder: Bool = false,
        maxLength: Int? = nil,
        isDismissible: Bool = true,
        textFieldDidBeginEditing: (() -> Void)? = nil,
        unit: HKUnit,
        allowDecimalSeparator: Bool = true,
        minValue: HKQuantity? = nil,
        maxValue: HKQuantity? = nil
    ) {
        _quantity = quantity
        self.textColor = textColor
        self.textAlignment = textAlignment
        self.autocapitalizationType = autocapitalizationType
        self.autocorrectionType = autocorrectionType
        self.shouldBecomeFirstResponder = shouldBecomeFirstResponder
        self.maxLength = maxLength
        self.isDismissible = isDismissible
        self.textFieldDidBeginEditing = textFieldDidBeginEditing
        self.unit = unit
        self.allowDecimalSeparator = allowDecimalSeparator
        self.minValue = minValue
        self.maxValue = maxValue
    }

    private func formattedPlaceholder(for unit: HKUnit) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = unit.preferredFractionDigits
        formatter.maximumFractionDigits = unit.preferredFractionDigits
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: 0)) ?? "0"
    }

    public func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        context.coordinator.textField = textField
        textField.inputAccessoryView = isDismissible ? makeDoneToolbar(for: textField, context: context) : nil
        textField.addTarget(context.coordinator, action: #selector(Coordinator.editingDidBegin), for: .editingDidBegin)
        textField.addTarget(context.coordinator, action: #selector(Coordinator.editingDidEnd), for: .editingDidEnd)
        textField.delegate = context.coordinator
        textField.text = quantity.doubleValue(for: unit) == 0 ? "" : context.coordinator.format(quantity: quantity, for: unit)
        textField.placeholder = formattedPlaceholder(for: unit)
        textField.keyboardType = unit.preferredFractionDigits == 0 ? .numberPad : .decimalPad

        if showAlert {
            let alert = UIAlertController(title: "Input Error", message: alertMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                showAlert = false
            })
            UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true, completion: nil)
        }

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
        textField.keyboardType = unit.preferredFractionDigits == 0 ? .numberPad : .decimalPad
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
        Coordinator(self, maxLength: maxLength, unit: unit, minValue: minValue, maxValue: maxValue)
    }

    public final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: TextFieldWithToolBar
        var textField: UITextField?
        let maxLength: Int?
        var didBecomeFirstResponder = false
        var isEditing = false
        var unit: HKUnit
        var minValue: HKQuantity?
        var maxValue: HKQuantity?

        init(_ parent: TextFieldWithToolBar, maxLength: Int?, unit: HKUnit, minValue: HKQuantity?, maxValue: HKQuantity?) {
            self.parent = parent
            self.maxLength = maxLength
            self.unit = unit
            self.minValue = minValue
            self.maxValue = maxValue
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
                if text.isEmpty {
                    self.parent.quantity = HKQuantity(unit: self.unit, doubleValue: 0)
                } else if let number = Double(text) {
                    let quantity = HKQuantity(unit: self.unit, doubleValue: number)
                    if self.isWithinLimits(quantity) {
                        self.parent.quantity = quantity
                        textField.text = self.format(quantity: self.parent.quantity, for: self.unit)
                    } else {
                        var message = "Value outside of guardrails: \(text)\n"
                        if let minValue = self.parent.minValue {
                            message += "Minimum: \(self.format(quantity: minValue, for: self.unit))\n"
                        }
                        if let maxValue = self.parent.maxValue {
                            message += "Maximum: \(self.format(quantity: maxValue, for: self.unit))"
                        }
                        self.showInvalidInputAlert(textField, message: message)
                    }
                } else {
                    self.showInvalidInputAlert(textField, message: "Invalid number format")
                }
            }
        }

        private func showInvalidInputAlert(_ textField: UITextField, message: String) {
            var message = "Value outside of guardrails\n"
            let preferredFractionDigits = self.unit.preferredFractionDigits
            let roundingFactor = pow(10.0, Double(preferredFractionDigits))

            if let minValue = self.parent.minValue {
                let minValueValue = minValue.doubleValue(for: self.unit)
                let minValueRoundedUp = ceil(minValueValue * roundingFactor) / roundingFactor
                message += "Minimum: \(self.format(quantity: HKQuantity(unit: self.unit, doubleValue: minValueRoundedUp), for: self.unit))\n"
            }
            if let maxValue = self.parent.maxValue {
                let maxValueValue = maxValue.doubleValue(for: self.unit)
                let maxValueRoundedDown = floor(maxValueValue * roundingFactor) / roundingFactor
                message += "Maximum: \(self.format(quantity: HKQuantity(unit: self.unit, doubleValue: maxValueRoundedDown), for: self.unit))"
            }
            let alert = UIAlertController(title: "Input Validation Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                textField.becomeFirstResponder()
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            })
            UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true, completion: nil)
        }

        public func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let decimalSeparator = Locale.current.decimalSeparator ?? "."
            let isNumber = CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: string))
            let isDecimalSeparator = (string == decimalSeparator && textField.text?.contains(decimalSeparator) == false)

            let currentText = textField.text ?? ""
            let proposedText = (currentText as NSString).replacingCharacters(in: range, with: string)

            if let maxLength = maxLength, proposedText.count > maxLength {
                return false
            }

            let isValidInput = isNumber || (isDecimalSeparator && parent.allowDecimalSeparator && unit.preferredFractionDigits > 0)

            if isValidInput, let number = Double(proposedText.replacingOccurrences(of: decimalSeparator, with: ".")) {
                let quantity = HKQuantity(unit: unit, doubleValue: number)
                if isWithinLimits(quantity) {
                    parent.quantity = quantity
                } else {
                    parent.quantity = HKQuantity(unit: unit, doubleValue: 0)
                }
            } else {
                parent.quantity = HKQuantity(unit: unit, doubleValue: 0)
            }

            return isValidInput
        }

        public func textFieldDidBeginEditing(_: UITextField) {
            parent.textFieldDidBeginEditing?()
        }

        func format(quantity: HKQuantity, for unit: HKUnit) -> String {
            let value = quantity.doubleValue(for: unit)
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = unit.preferredFractionDigits
            formatter.maximumFractionDigits = unit.preferredFractionDigits
            formatter.numberStyle = .decimal
            return formatter.string(from: NSNumber(value: value)) ?? ""
        }

        private func isWithinLimits(_ quantity: HKQuantity) -> Bool {
            if let minValue = minValue, quantity.doubleValue(for: unit) < minValue.doubleValue(for: unit) {
                return false
            }
            if let maxValue = maxValue, quantity.doubleValue(for: unit) > maxValue.doubleValue(for: unit) {
                return false
            }
            return true
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
