// LoopFollow
// DeleteAlarmSection.swift
// Created by Jonas Björkert.

//
//  DeleteAlarmSection.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-06-09.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//
import SwiftUI

struct DeleteAlarmSection: View {
    @State private var ask = false
    let delete: () -> Void

    var body: some View {
        Section {
            Button(role: .destructive) {
                ask = true
            } label: {
                Label("Delete Alarm", systemImage: "trash")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .alert("Delete this alarm?", isPresented: $ask) {
            Button("Delete", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {}
        }
    }
}
