//
//  AlarmBGLimitSection.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-13.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct AlarmBGLimitSection: View {
    let header: String?
    let footer: String?
    let toggleText: String
    let pickerTitle: String
    let range: ClosedRange<Double>
    @Binding var value: Double?
    
    init(
        header:  String? = nil,
        footer:  String? = nil,
        toggleText:  String,
        pickerTitle: String,
        range: ClosedRange<Double>,
        value: Binding<Double?>
    ) {
        self.header      = header
        self.footer      = footer
        self.toggleText  = toggleText
        self.pickerTitle = pickerTitle
        self.range       = range
        self._value      = value
    }

    private var isOn: Binding<Bool> {
        Binding(
            get: { value != nil },
            set: { on in
                if on, value == nil { value = range.lowerBound }
                if !on { value = nil }
            }
        )
    }

    private var pickerValue: Binding<Double> {
        Binding(
            get: { value ?? range.lowerBound },
            set: { newVal in value = newVal }
        )
    }

    var body: some View {
        Section(
            header: header.map(Text.init),
            footer: footer.map(Text.init)
        ) {
            Toggle(toggleText, isOn: isOn)

            if isOn.wrappedValue {
                AlarmBGPicker(
                    title: pickerTitle,
                    range: range,
                    value: pickerValue
                )
            }
        }
    }
}
