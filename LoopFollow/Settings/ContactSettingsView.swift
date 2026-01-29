// LoopFollow
// ContactSettingsView.swift

import Contacts
import SwiftUI

struct ContactSettingsView: View {
    @ObservedObject var viewModel: ContactSettingsViewModel

    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""

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
                    Section(header: Text("Color Options")) {
                        Text("Select the colors for your BG values.  Note: not all watch faces allow control over colors. Recommend options like Activity or Modular Duo if you want to customize colors.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)

                        Picker("Select Background Color", selection: $viewModel.contactBackgroundColor) {
                            ForEach(ContactColorOption.allCases, id: \.rawValue) { option in
                                Text(option.rawValue.capitalized).tag(option.rawValue)
                            }
                        }

                        Picker("Select Text Color", selection: $viewModel.contactTextColor) {
                            ForEach(ContactColorOption.allCases, id: \.rawValue) { option in
                                Text(option.rawValue.capitalized).tag(option.rawValue)
                            }
                        }
                    }

                    Section(header: Text("Additional Information")) {
                        Text("To see your trend, delta, or IOB, include them in another contact or create separate contacts. When using 'Include', select which contact to add the value to.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)

                        Text("Trend")
                            .font(.subheadline)
                        Picker("Show Trend", selection: $viewModel.contactTrend) {
                            ForEach(ContactIncludeOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())

                        if viewModel.contactTrend == .include {
                            Picker("Include Trend in", selection: $viewModel.contactTrendTarget) {
                                ForEach(viewModel.availableTargets(for: .Trend), id: \.self) { target in
                                    Text(target.rawValue).tag(target)
                                }
                            }
                        }

                        Text("Delta")
                            .font(.subheadline)
                        Picker("Show Delta", selection: $viewModel.contactDelta) {
                            ForEach(ContactIncludeOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())

                        if viewModel.contactDelta == .include {
                            Picker("Include Delta in", selection: $viewModel.contactDeltaTarget) {
                                ForEach(viewModel.availableTargets(for: .Delta), id: \.self) { target in
                                    Text(target.rawValue).tag(target)
                                }
                            }
                        }

                        Text("IOB")
                            .font(.subheadline)
                        Picker("Show IOB", selection: $viewModel.contactIOB) {
                            ForEach(ContactIncludeOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())

                        if viewModel.contactIOB == .include {
                            Picker("Include IOB in", selection: $viewModel.contactIOBTarget) {
                                ForEach(viewModel.availableTargets(for: .IOB), id: \.self) { target in
                                    Text(target.rawValue).tag(target)
                                }
                            }
                        }
                    }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
        .navigationBarTitle("Contact", displayMode: .inline)
    }

    private func requestContactAccess() {
        let contactStore = CNContactStore()
        let status = CNContactStore.authorizationStatus(for: .contacts)

        if status == .authorized {
            // Already authorized, do nothing
        } else if status == .notDetermined {
            contactStore.requestAccess(for: .contacts) { granted, _ in
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
