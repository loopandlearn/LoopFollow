// LoopFollow
// TextFieldWithToolBar.swift
// Created by Jonas Björkert.

import HealthKit
import SwiftUI
import UIKit

public struct TextFieldWithToolBar: UIViewRepresentable {
    @Binding var quantity: HKQuantity

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
    var onValidationError: (String) -> Void

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
        maxValue: HKQuantity? = nil,
        onValidationError: @escaping (String) -> Void
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
        self.onValidationError = onValidationError
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
        Coordinator(self, maxLength: maxLength, unit: unit, minValue: minValue, maxValue: maxValue, onValidationError: onValidationError)
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
        let onValidationError: (String) -> Void

        init(_ parent: TextFieldWithToolBar, maxLength: Int?, unit: HKUnit, minValue: HKQuantity?, maxValue: HKQuantity?, onValidationError: @escaping (String) -> Void) {
            self.parent = parent
            self.maxLength = maxLength
            self.unit = unit
            self.minValue = minValue
            self.maxValue = maxValue
            self.onValidationError = onValidationError
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
                        let formatter = NumberFormatter()
                        formatter.minimumFractionDigits = self.unit.preferredFractionDigits
                        formatter.maximumFractionDigits = self.unit.preferredFractionDigits
                        let step = pow(10.0, Double(-formatter.maximumFractionDigits))

                        var message = "Value outside of guardrails: \(text)\n"

                        if let minValue = self.parent.minValue {
                            let minVal = minValue.doubleValue(for: self.unit)
                            let adjustedMin = ceil(minVal / step) * step
                            let minQuantity = HKQuantity(unit: self.unit, doubleValue: adjustedMin)
                            message += "Minimum: \(self.format(quantity: minQuantity, for: self.unit))\n"
                        }

                        if let maxValue = self.parent.maxValue {
                            let maxVal = maxValue.doubleValue(for: self.unit)
                            let adjustedMax = floor(maxVal / step) * step
                            let maxQuantity = HKQuantity(unit: self.unit, doubleValue: adjustedMax)
                            message += "Maximum: \(self.format(quantity: maxQuantity, for: self.unit))"
                        }

                        self.onValidationError(message)
                        self.parent.quantity = HKQuantity(unit: self.unit, doubleValue: 0)
                    }
                } else {
                    self.onValidationError("Invalid number format")
                }
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

        private func isWithinLimits(_ quantity: HKQuantity) -> Bool {
            if let minValue = minValue, quantity.doubleValue(for: unit) < minValue.doubleValue(for: unit) {
                return false
            }
            if let maxValue = maxValue, quantity.doubleValue(for: unit) > maxValue.doubleValue(for: unit) {
                return false
            }
            return true
        }

        public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let currentText = textField.text ?? ""

            guard let textRange = Range(range, in: currentText) else {
                return false
            }
            let updatedText = currentText.replacingCharacters(in: textRange, with: string)

            if let maxLength = maxLength, updatedText.count > maxLength {
                return false
            }

            let decimalSeparator = Locale.current.decimalSeparator ?? "."
            let sanitizedText = updatedText.replacingOccurrences(of: decimalSeparator, with: ".")

            if sanitizedText.isEmpty {
                DispatchQueue.main.async {
                    self.parent.quantity = HKQuantity(unit: self.unit, doubleValue: 0)
                }
                return true
            } else if let number = Double(sanitizedText) {
                let quantity = HKQuantity(unit: unit, doubleValue: number)
                if isWithinLimits(quantity) {
                    DispatchQueue.main.async {
                        self.parent.quantity = quantity
                    }
                }
                return true
            } else {
                return true
            }
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
