    //
//  ContactSettingsView.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-12-10.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import SwiftUI
import Contacts

struct ContactSettingsView: View {
    @ObservedObject var viewModel: ContactSettingsViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var selectedColor: UIColor = .white  // Default color

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Contact Integration")) {
                    Text("Add the contact named '\(viewModel.contactName)' to your watch face to show the current BG value in real time. Make sure to give the app full access to Contacts when prompted.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)

                    Toggle("Enable Contact BG Updates", isOn: $viewModel.contactEnabled)
                        .toggleStyle(SwitchToggleStyle())
                        .onChange(of: viewModel.contactEnabled) { isEnabled in
                            if isEnabled {
                                requestContactAccess()
                            }
                        }
                    
                }

                if viewModel.contactEnabled {
                    Section(header: Text("Additional Information")) {
                        Toggle("Show Trend", isOn: $viewModel.contactTrend)
                            .toggleStyle(SwitchToggleStyle())
                            .onChange(of: viewModel.contactTrend) { isTrendEnabled in
                                if isTrendEnabled {
                                    viewModel.contactDelta = false
                                }
                            }

                        Toggle("Show Delta", isOn: $viewModel.contactDelta)
                            .toggleStyle(SwitchToggleStyle())
                            .onChange(of: viewModel.contactDelta) { isDeltaEnabled in
                                if isDeltaEnabled {
                                    viewModel.contactTrend = false
                                }
                            }
                        Picker("Select Color", selection: $selectedColor) {
                            Text("Red").tag(red)
                            Text("Blue").tag(blue)
                            Text("Cyan").tag(cyan)
                            Text("Green").tag(green)
                            Text("Yellow").tag(yellow)
                            Text("Orange").tag(orange)
                            Text("Purple").tag(purple)
                            Text("White").tag(white)
                        }
                    }
                }
            }
            .navigationBarTitle("Contact Settings", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func requestContactAccess() {
        let contactStore = CNContactStore()
        let status = CNContactStore.authorizationStatus(for: .contacts)

        if status == .authorized {
            // Already authorized, do nothing
        } else if status == .notDetermined {
            contactStore.requestAccess(for: .contacts) { granted, error in
                DispatchQueue.main.async {
                    if !granted {
                        viewModel.contactEnabled = false
                        showAlert(title: "Access Denied", message: "Please allow access to Contacts in Settings to enable this feature.")
                    }
                }
            }
        } else if status == .denied {
            viewModel.contactEnabled = false
            showAlert(title: "Access Denied", message: "Access to Contacts is denied. Please go to Settings and enable Contacts access.")
        } else if status == .restricted {
            viewModel.contactEnabled = false
            showAlert(title: "Access Restricted", message: "Access to Contacts is restricted.")
        } else {
            viewModel.contactEnabled = false
            showAlert(title: "Error", message: "An unknown error occurred while checking Contacts access.")
        }
    }

    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}
