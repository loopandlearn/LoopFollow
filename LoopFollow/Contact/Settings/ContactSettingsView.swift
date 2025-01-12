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
    @State private var contactTrendSelection = 0
    @State private var contactDeltaSelection = 0

    let options = ["Off", "Include", "Separate Card"]

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

                Section(header: Text("Color Options")) {
                    Text("Select the colors for your BG values.  Note: not all watch faces allow control over colors. Recommend options like Activity or Modular Duo if you want to customize colors.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                    
                    Picker("Select Background Color", selection: $viewModel.contactBackgroundColor) {
                            Text("Red").tag("red")
                            Text("Blue").tag("blue")
                            Text("Cyan").tag("cyan")
                            Text("Green").tag("green")
                            Text("Yellow").tag("yellow")
                            Text("Orange").tag("orange")
                            Text("Purple").tag("purple")
                            Text("White").tag("white")
                            Text("Black").tag("black")
                        }
                        
                    Picker("Select Text Color", selection: $viewModel.contactTextColor) {
                        Text("Red").tag("red")
                        Text("Blue").tag("blue")
                        Text("Cyan").tag("cyan")
                        Text("Green").tag("green")
                        Text("Yellow").tag("yellow")
                        Text("Orange").tag("orange")
                        Text("Purple").tag("purple")
                        Text("White").tag("white")
                        Text("Black").tag("black")
                    }
                }
                    
                if viewModel.contactEnabled {
                    Section(header: Text("Additional Information")) {
                        Text("Show Trend")
                            .font(.subheadline)
                        Picker("Show Trend", selection: $contactTrendSelection) {
                            ForEach(0..<options.count, id: \.self) { index in
                                Text(self.options[index]).tag(index)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                
                        Text("Show Delta")
                            .font(.subheadline)
                        Picker("Show Delta", selection: $contactDeltaSelection) {
                            ForEach(0..<options.count, id: \.self) { index in
                                Text(self.options[index]).tag(index)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
            }
            .onChange(of: contactTrendSelection) { newValue in
                if newValue == 1 && contactDeltaSelection == 1 {
                    contactDeltaSelection = 0
                }
            }
            .onChange(of: contactDeltaSelection) { newValue in
                if newValue == 1 && contactTrendSelection == 1 {
                    contactTrendSelection = 0
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
