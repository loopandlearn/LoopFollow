// LoopFollow
// HubJoinStepView.swift

import SwiftUI

/// The "join a family hub" connect path: scan an invite, choose how this phone joins,
/// name it, and join. The hub brings the data source, and a replaced or copied phone's
/// alarms and settings. After a failure the user can try again or go back and choose
/// another data source; once the hub has taken the phone, it counts as joined, and what
/// is left is finished by a later sync.
struct HubJoinStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @ObservedObject private var patientName = HubClient.shared.patientName

    private enum Page: Int {
        case invite, choice, name
    }

    @State private var page = Page.invite
    @State private var invite: HubClient.Invite?
    @State private var devices: [HubClient.Device] = []
    /// The patient's name the hub gave with the devices; absent on an older hub.
    @State private var invitePatientName: String?
    @State private var join = HubClient.Join.new
    /// A recently used device about to be replaced, with the question to ask first.
    @State private var replaceWarning: (device: HubClient.Device, warning: String)?
    @State private var deviceName = UIDevice.current.model
    @State private var inviteLink = ""
    @State private var scanning = false
    @State private var busy = false
    @State private var errorText: String?
    /// The failed step may work when tried again.
    @State private var canRetry = false

    private var joined: Bool {
        viewModel.hubJoin != nil && HubClient.shared.isConnected
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                if joined {
                    joinedContent
                } else {
                    switch page {
                    case .invite: inviteContent
                    case .choice: choiceContent
                    case .name: nameContent
                    }
                }
                if let errorText {
                    Section {
                        Text(errorText).font(.caption).foregroundColor(.red)
                        if canRetry {
                            Button("Try Again") { next() }
                        }
                        Button("Choose Another Data Source") { chooseAnotherSource() }
                    }
                }
            }
            .disabled(busy)

            OnboardingNavFooter(
                continueTitle: !joined && page == .name ? "Join" : "Continue",
                continueEnabled: continueEnabled,
                showBack: true,
                onBack: back,
                onContinue: next
            )
        }
        .sheet(isPresented: $scanning) {
            SimpleQRCodeScannerView { result in
                // The scanner can report a code more than once before it stops.
                guard scanning else { return }
                scanning = false
                if case let .success(text) = result { Task { await read(text) } }
            }
        }
        .onAppear { reportProgress() }
        .onChange(of: page) { reportProgress() }
        .alert(replaceWarning.map { "Replace \($0.device.name)?" } ?? "",
               isPresented: Binding(get: { replaceWarning != nil }, set: { if !$0 { replaceWarning = nil } }))
        {
            Button("Cancel", role: .cancel) {}
            Button("Replace", role: .destructive) {
                if let device = replaceWarning?.device { join = .replace(device.id) }
            }
        } message: {
            Text(replaceWarning?.warning ?? "")
        }
    }

    // MARK: - Pages

    private func header(_ systemImage: String, _ title: String, _ subtitle: String) -> some View {
        Section {
            EmptyView()
        } header: {
            OnboardingStepHeader(systemImage: systemImage, title: title, subtitle: subtitle)
                .textCase(nil)
                .padding(.bottom, 8)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var inviteContent: some View {
        header("person.2.fill", "Join a family hub",
               "On a phone that already uses LF Hub, open Settings → LF Hub → Invite Family Member. Then scan the code it shows.")
        Section {
            Button {
                errorText = nil
                scanning = true
            } label: {
                HStack {
                    Image(systemName: "qrcode.viewfinder").foregroundColor(.accentColor)
                    Text("Scan Invite Code")
                }
            }
            TextField("Or paste the invite link", text: $inviteLink)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: inviteLink) { if inviteLink.isEmpty { errorText = nil } }
            if busy {
                HStack {
                    ProgressView()
                    Text("Reading the invite…").foregroundColor(.secondary)
                }
            }
        }
    }

    /// The hub the invite is for, so the user sees where this phone is joining.
    @ViewBuilder
    private var hubSection: some View {
        if let invite {
            Section {
                HStack {
                    Text("Hub")
                    Spacer()
                    Text(HubSettingsView.host(invite)).foregroundColor(.secondary)
                }
                if let invitePatientName {
                    HStack {
                        Text("Patient")
                        Spacer()
                        Text(invitePatientName).foregroundColor(.secondary)
                    }
                }
            } footer: {
                Text(invitePatientName.map { "Join \(HubSettingsView.host(invite)) to follow \($0)? Only join a hub you know." }
                    ?? "Join \(HubSettingsView.host(invite))? Only join a hub you know.")
            }
        }
    }

    @ViewBuilder
    private var choiceContent: some View {
        header("iphone.and.arrow.forward", "How should this phone join?",
               "Copy another phone's alarms and settings, or start fresh and choose alarms next.")
        hubSection
        Section {
            ForEach(devices) { device in
                choiceRow("Copy settings from \(device.name)", detail: "Starts with the same alarms and settings.",
                          .copy(device.id))
            }
            ForEach(devices.filter { $0.role != .admin }) { device in
                choiceRow("Replace \(device.name)",
                          detail: "This replaces my old phone. It takes over its alarms and settings.", .replace(device.id))
                {
                    if let warning = HubClient.recentUseWarning(device, now: Date()) {
                        replaceWarning = (device, warning)
                    } else {
                        join = .replace(device.id)
                    }
                }
            }
            choiceRow("Start fresh", detail: "A new phone with its own alarms.", .new)
        }
    }

    @ViewBuilder
    private var nameContent: some View {
        header("character.cursor.ibeam", "Name this phone",
               "Everyone who manages LF Hub sees this name in the list of phones.")
        hubSection
        Section {
            TextField("This phone's name", text: $deviceName)
            if busy {
                HStack {
                    ProgressView()
                    Text("Joining…").foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var joinedContent: some View {
        header("checkmark.circle.fill", "You're in",
               "This phone now follows \(patientName.value.isEmpty ? "the patient" : patientName.value) with the family's data source."
                   + (viewModel.hubJoin == .new ? "" : " Its alarms and settings came along."))
    }

    private func choiceRow(_ title: String, detail: String, _ choice: HubClient.Join,
                           onSelect: (() -> Void)? = nil) -> some View
    {
        Button {
            if let onSelect { onSelect() } else { join = choice }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundColor(.primary)
                    Text(detail).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: join == choice ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(join == choice ? Color.accentColor : Color(.systemGray3))
            }
        }
    }

    // MARK: - Navigation

    private var continueEnabled: Bool {
        if busy { return false }
        if joined { return true }
        switch page {
        case .invite: return HubClient.Invite(link: inviteLink) != nil
        case .choice: return true
        case .name: return !deviceName.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func reportProgress() {
        viewModel.phaseProgress = joined ? nil : .init(page: page.rawValue, count: 3)
    }

    private func back() {
        errorText = nil
        canRetry = false
        if joined {
            viewModel.goBack()
            return
        }
        switch page {
        case .invite: viewModel.goBack()
        case .choice: page = .invite
        case .name: page = devices.isEmpty ? .invite : .choice
        }
    }

    private func next() {
        errorText = nil
        canRetry = false
        if joined {
            viewModel.advance()
            return
        }
        switch page {
        case .invite:
            Task { await read(inviteLink) }
        case .choice:
            if case let .replace(id) = join, let device = devices.first(where: { $0.id == id }) {
                deviceName = device.name
            } else {
                deviceName = UIDevice.current.model
            }
            page = .name
        case .name:
            Task { await joinHub() }
        }
    }

    /// Leaves the join path for the data source choice.
    private func chooseAnotherSource() {
        errorText = nil
        canRetry = false
        page = .invite
        viewModel.goBack()
    }

    /// Shows why a step failed; an invite the hub does not take sends the user back to scan another.
    private func failed(_ error: Error) {
        LogManager.shared.log(category: .hub, message: "Joining with an invite failed: \(error.localizedDescription)")
        errorText = HubClient.userMessage(for: error)
        switch error {
        case HubClient.HubError.inviteNotValid:
            canRetry = false
            invite = nil
            inviteLink = ""
            page = .invite
        default:
            canRetry = true
        }
    }

    /// Reads the invite and offers the hub's phones to copy or replace.
    private func read(_ link: String) async {
        guard let invite = HubClient.Invite(link: link) else {
            errorText = "This is not an LF Hub invite code."
            return
        }
        busy = true
        defer { busy = false }
        do {
            let list = try await HubClient.shared.joinableDevices(invite: invite)
            devices = list.devices
            invitePatientName = list.patientName
            self.invite = invite
            inviteLink = invite.link
            join = .new
            page = devices.isEmpty ? .name : .choice
        } catch {
            failed(error)
        }
    }

    private func joinHub() async {
        guard let invite else { return }
        busy = true
        defer { busy = false }
        do {
            try await HubClient.shared.join(invite: invite, deviceName: deviceName, join: join)
            viewModel.hubJoin = join
            viewModel.advance()
        } catch {
            failed(error)
        }
    }
}
