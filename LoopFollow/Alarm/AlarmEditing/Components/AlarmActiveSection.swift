//
//  AlarmActiveSection.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-12.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct AlarmActiveSection: View {
    @Binding var alarm: Alarm

    var body: some View {
        Section(header: Text("Active During")) {
            AlarmEnumMenuPicker(title: "Active",
                                selection: $alarm.activeOption)
        }
    }
}
