//
//  AlarmBGSection.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-06.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import HealthKit
import SwiftUI

struct AlarmBGSection: View {
    let header: String?
    let footer: String?
    let title: String
    let range: ClosedRange<Double>
    @Binding var value: Double

    init(
        header: String? = nil,
        footer: String? = nil,
        title: String,
        range: ClosedRange<Double>,
        value: Binding<Double>
    ) {
        self.header = header
        self.footer = footer
        self.title = title
        self.range = range
        _value = value
    }

    var body: some View {
        Section(
            header: header.map(Text.init),
            footer: footer.map(Text.init)
        ) {
            AlarmBGPicker(
                title: title,
                range: range,
                value: $value
            )
        }
    }
}
