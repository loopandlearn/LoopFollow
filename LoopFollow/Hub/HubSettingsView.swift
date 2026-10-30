// LoopFollow
// HubSettingsView.swift

import SwiftUI

struct HubSettingsView: View {
    @ObservedObject private var hubURL = Storage.shared.hubURL
    @ObservedObject private var deviceKey = HubClient.shared.deviceKey
    @ObservedObject private var backgroundRefreshType = Storage.shared.backgroundRefreshType
    @ObservedObject private var laEnabled = Storage.shared.laEnabled
    @ObservedObject private var nightscoutURL = Storage.shared.url
    @ObservedObject private var dexcomUser = Storage.shared.shareUserName
    @ObservedObject private var role = HubClient.shared.role
    @ObservedObject private var joinedWithInvite = HubClient.shared.joinedWithInvite
    @ObservedObject private var hubInfo = HubClient.shared.hubInfo
    @ObservedObject private var hubConfirmed = HubClient.shared.hubConfirmed
    @ObservedObject private var hubProblems = HubClient.shared.hubProblems
    @ObservedObject private var removedFromHub = HubClient.shared.removedFromHub
    @ObservedObject private var lfKeyId = Storage.shared.lfKeyId
    @ObservedObject private var lfApnsKey = Storage.shared.lfApnsKey

    @State private var urlInput = Storage.shared.hubURL.value
    @State private var setupToken = ""
    @State private var patientName = ""
    @State private var deviceName = UIDevice.current.model
    /// The hub's devices offered when joining; nil until the address and token, or the
    /// invite, are checked.
    @State private var joinableDevices: [HubClient.Device]?
    /// The patient's name the hub gave with the devices offered when joining.
    @State private var joinPatientName: String?
    @State private var join = HubClient.Join.new
    /// A recently used device about to be replaced, with the question to ask first.
    @State private var replaceCandidate: ReplaceCandidate?
    /// The invite being joined with; nil while joining with the setup token.
    @State private var joinInvite: HubClient.Invite?
    @State private var inviteLink = ""
    @State private var inviteError: String?
    @State private var scanningInvite = false

    @State private var status: HubClient.Status?
    @State private var statusError: String?
    @State private var devices: [HubClient.Device] = []
    @State private var deviceToRemove: HubClient.Device?
    /// This phone, about to stop being an admin.
    @State private var deviceToDemote: HubClient.Device?
    @State private var sourceAction: SourceAction?
    @State private var shownInvite: ShownInvite?
    @State private var notifications: HubChecklist.Permission?
    @State private var confirmingDisconnect = false
    /// Just connected while another Background Refresh mode is chosen.
    @State private var offeringHubMode = false
    @State private var busy = false
    @State private var actionError: ActionError?
    @State private var testAlarmInfo: String?
    @State private var sourcesInfo: String?

    /// How often the page reads the hub's view again while it is shown.
    private static let reloadInterval: UInt64 = 30

    private enum SourceAction: Identifiable {
        case send, take
        var id: Self { self }
    }

    private struct ShownInvite: Identifiable {
        let invite: HubClient.Invite
        let expiresAt: Date
        var id: String { invite.code }
    }

    private struct ActionError: Identifiable {
        let title: String
        let message: String
        var id: String { title + message }
    }

    private struct ReplaceCandidate: Identifiable {
        let device: HubClient.Device
        let warning: String
        var id: UUID { device.id }
    }

    private var connected: Bool {
        !hubURL.value.isEmpty && !deviceKey.value.isEmpty
    }

    private var hubMode: Bool {
        backgroundRefreshType.value == .hub
    }

    private var isAdmin: Bool {
        connected && role.value == .admin
    }

    private func offers(_ feature: String) -> Bool {
        connected && hubInfo.value?.features.contains(feature) == true
    }

    var body: some View {
        Form {
            if !HubClient.isSupported {
                Section { Text("LF Hub requires iOS 26 or later.").foregroundColor(.secondary) }
            } else if connected {
                connectedSections
            } else {
                connectSections
            }
        }
        .disabled(busy)
        .task {
            await readNotificationPermission()
            await refresh()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.reloadInterval * 1_000_000_000)
                if Task.isCancelled { break }
                await reload()
            }
        }
        .refreshable { await refresh() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task {
                await readNotificationPermission()
                await reload()
            }
        }
        .sheet(isPresented: $scanningInvite) {
            SimpleQRCodeScannerView { result in
                // The scanner can report a code more than once before it stops.
                guard scanningInvite else { return }
                scanningInvite = false
                if case let .success(text) = result {
                    inviteLink = text
                    readInvite(text)
                }
            }
        }
        .sheet(item: $shownInvite) { shown in
            HubInviteSheet(invite: shown.invite, expiresAt: shown.expiresAt,
                           patientName: status?.patient.name ?? HubClient.shared.patientName.value)
        }
        .alert(actionError?.title ?? "", isPresented: Binding(get: { actionError != nil },
                                                              set: { if !$0 { actionError = nil } }),
               presenting: actionError)
        { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.message)
        }
        .alert(replaceCandidate.map { "Replace \($0.device.name)?" } ?? "",
               isPresented: Binding(get: { replaceCandidate != nil },
                                    set: { if !$0 { replaceCandidate = nil } }),
               presenting: replaceCandidate)
        { candidate in
            Button("Cancel", role: .cancel) {}
            Button("Replace", role: .destructive) { choose(.replace(candidate.device.id), name: candidate.device.name) }
        } message: { candidate in
            Text(candidate.warning)
        }
        .alert(deviceToRemove.map { "Remove \($0.name)?" } ?? "",
               isPresented: Binding(get: { deviceToRemove != nil },
                                    set: { if !$0 { deviceToRemove = nil } }),
               presenting: deviceToRemove)
        { device in
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) { Task { await remove(device) } }
        } message: { _ in
            Text("The hub stops sending to it.")
        }
        .alert("Make this phone a member?",
               isPresented: Binding(get: { deviceToDemote != nil },
                                    set: { if !$0 { deviceToDemote = nil } }),
               presenting: deviceToDemote)
        { device in
            Button("Cancel", role: .cancel) {}
            Button("Make Member") { Task { await setRole(.member, of: device) } }
        } message: { _ in
            Text("This phone can no longer change the data source, invite or manage phones. Only another admin can make it an admin again.")
        }
        .confirmationDialog(sourceAction == .take ? "Use the hub's data sources in this app?" : "Send this app's data sources to the hub?",
                            isPresented: Binding(get: { sourceAction != nil },
                                                 set: { if !$0 { sourceAction = nil } }),
                            titleVisibility: .visible,
                            presenting: sourceAction)
        { action in
            Button(action == .take ? "Use Hub's Sources" : "Send to Hub") {
                Task { action == .take ? await takeSources() : await sendSources() }
            }
        } message: { action in
            Text(action == .take ? "This app's Nightscout and Dexcom settings are replaced."
                : "The hub's Nightscout and Dexcom settings are replaced for every phone.")
        }
        .alert("Use LF Hub for Background Refresh?", isPresented: $offeringHubMode) {
            Button("Not Now", role: .cancel) {}
            Button("Use LF Hub") {
                Task {
                    await BackgroundRefreshSettingsViewModel.change(to: .hub)?.value
                    await reload()
                }
            }
        } message: {
            Text("The hub keeps the badge, Live Activity and alarms up to date while LoopFollow is closed. You can change this under Background Refresh.")
        }
        .confirmationDialog("Disconnect from LF Hub?", isPresented: $confirmingDisconnect, titleVisibility: .visible) {
            Button("Disconnect", role: .destructive) { Task { await disconnect() } }
        } message: {
            Text("This phone stops getting LF Hub's alarms. LoopFollow goes back to alarming by itself.")
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
        .navigationTitle("LF Hub")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Not connected

    @ViewBuilder
    private var connectSections: some View {
        if removedFromHub.value {
            Section {
                Label("This phone was removed from LF Hub", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Another phone replaced it, or an admin removed it. LoopFollow alarms by itself now. To use LF Hub again, ask an admin for an invite and join below.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Button("Dismiss") { removedFromHub.value = false }
            }
        }

        if let joinInvite, let joinableDevices {
            Section(header: Text("Join with Invite")) {
                row("Hub", Self.host(joinInvite))
                if let joinPatientName { row("Patient", joinPatientName) }
                Button("Use a Different Invite") { leaveInvite() }
            }
            joinChoiceSections(joinableDevices, invite: joinInvite)
        } else {
            Section(
                header: Text("Join with Invite"),
                footer: Text("Someone who manages LF Hub shows the invite under Settings → LF Hub → Invite Family Member.")
            ) {
                Button {
                    inviteError = nil
                    scanningInvite = true
                } label: {
                    Label("Scan Invite Code", systemImage: "qrcode.viewfinder")
                }
                TextField("Or paste the invite link", text: $inviteLink)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { readInvite(inviteLink) }
                    .onChange(of: inviteLink) { old, new in
                        if new.isEmpty { inviteError = nil }
                        if let invite = HubClient.Invite.pasted(from: old, to: new) { readInvite(invite.link) }
                    }
                Button("Continue") { readInvite(inviteLink) }
                    .disabled(inviteLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if let inviteError {
                    Text(inviteError).font(.caption).foregroundColor(.red)
                }
            }

            Section(
                header: Text("Set Up as Owner"),
                footer: Text("The owner connects with the hub's setup token. The hub stores this phone's APN key, encrypted, to send it notifications.")
            ) {
                TextField("https://hub.example.com", text: $urlInput)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: urlInput) { joinableDevices = nil }
                TogglableSecureInput(placeholder: "Setup token", text: $setupToken, style: .singleLine)
                    .onChange(of: setupToken) { joinableDevices = nil }
                if joinableDevices == nil {
                    Button("Continue") { Task { await listDevices() } }
                        .disabled(urlInput.isEmpty || setupToken.isEmpty)
                } else if let joinPatientName {
                    row("Patient", joinPatientName)
                }
            }

            if let joinableDevices {
                joinChoiceSections(joinableDevices, invite: nil)
            }
        }
    }

    /// How this phone joins: a new hub creates the patient; otherwise it replaces a phone,
    /// copies one or comes as a new device. An invite cannot replace an admin's phone.
    @ViewBuilder
    private func joinChoiceSections(_ devices: [HubClient.Device], invite: HubClient.Invite?) -> some View {
        if devices.isEmpty {
            Section {
                if invite == nil { TextField("Patient name", text: $patientName) }
                TextField("This device's name", text: $deviceName)
                Button(invite.map { "Join \(Self.host($0))" } ?? "Connect") { Task { await connect() } }
            } footer: {
                if invite == nil { Text("A new hub: connecting creates the patient.") }
            }
        } else {
            let replaceable = invite == nil ? devices : devices.filter { $0.role != .admin }
            Section(
                header: Text("This Phone"),
                footer: Text("Replace a phone you no longer use, or copy another phone's alarms to this one.")
            ) {
                ForEach(replaceable) { device in
                    joinRow("Replace \(device.name)", detail: deviceDetail(device), .replace(device.id),
                            name: device.name)
                    {
                        if let warning = HubClient.recentUseWarning(device, now: Date()) {
                            replaceCandidate = ReplaceCandidate(device: device, warning: warning)
                        } else {
                            choose(.replace(device.id), name: device.name)
                        }
                    }
                }
                ForEach(devices) { device in
                    joinRow("Copy Settings from \(device.name)", detail: nil, .copy(device.id),
                            name: UIDevice.current.model)
                }
                joinRow("New Device", detail: nil, .new, name: UIDevice.current.model)
            }
            Section {
                TextField("This device's name", text: $deviceName)
                Button(invite.map { "Join \(Self.host($0))" } ?? "Connect") { Task { await connect() } }
            }
        }
    }

    static func host(_ invite: HubClient.Invite) -> String {
        URL(string: invite.hubURL)?.host ?? invite.hubURL
    }

    private func choose(_ choice: HubClient.Join, name: String) {
        join = choice
        deviceName = name
    }

    private func joinRow(_ title: String, detail: String?, _ choice: HubClient.Join, name: String,
                         onSelect: (() -> Void)? = nil) -> some View
    {
        Button {
            if let onSelect { onSelect() } else { choose(choice, name: name) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundColor(.primary)
                    if let detail {
                        Text(detail).font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                if join == choice {
                    Image(systemName: "checkmark").foregroundColor(.accentColor)
                }
            }
        }
    }

    // MARK: - Connected

    @ViewBuilder
    private var connectedSections: some View {
        Section(header: Text("Hub")) {
            row("Address", hubURL.value)
            if let version = hubInfo.value?.version {
                row("LF Hub version", version)
            }
            if let status {
                row("Patient", status.patient.name)
                row("This device", status.device.name)
                if offers("roles") {
                    row("Role", isAdmin ? "Admin" : "Member")
                }
                row("Live connection", status.live.connected ? "Connected" : "Disconnected")
                if let at = status.live.lastReadingAt {
                    row("Last reading", relative(at))
                }
                row("Push", status.device.apnsConfigured ? (status.device.apnsEnvironment ?? "") : "Not registered")
                if let at = status.device.lastPushAt {
                    row("Last push", "\(relative(at)) · \(status.device.lastPushStatus ?? "")")
                }
                if let alarm = status.device.activeAlarm {
                    row("Sounding alarm", "\(alarm.title) · \(relative(alarm.firedAt))")
                }
                if hubMode {
                    let la = status.device.liveActivity
                    row("Live Activity", la.registered ? "Registered" : "No activity")
                    row("Push-to-start", la.pushToStartRegistered ? "Registered" : "Missing")
                    if let renewBy = la.renewBy {
                        row("Renews", la.renewalFailed ? "Failed, retrying" : relative(renewBy))
                    }
                    if let at = la.lastPushAt {
                        row("Last LA push", "\(relative(at)) · \(la.lastPushStatus ?? "")")
                    }
                }
            }
        }

        Section {
            let items = checklist
            if items.isEmpty {
                ProgressView()
            } else {
                HubChecklistRows(items: items) { fix in Task { await apply(fix) } }
            }
        } header: {
            Text("Ready")
        } footer: {
            if hubMode {
                Text("The hub sends the alarms, badge and Live Activity, so LoopFollow can stay closed. Alarms depend on the network and Apple's push service. If the hub stops working, LoopFollow alarms by itself only when iOS lets it run, which can take a long time while the phone is locked.")
            }
        }

        Section(
            header: Text("Patient Data Sources"),
            footer: Text(sourcesFooter)
        ) {
            if let status {
                if isAdmin, offers("sourceRevision") {
                    NavigationLink(value: SettingsRoute.nightscout) {
                        row("Nightscout", status.patient.nightscoutHost ?? "Not set")
                    }
                    NavigationLink(value: SettingsRoute.dexcom) {
                        row("Dexcom", status.patient.dexcom == true ? "Set" : "Not set")
                    }
                } else {
                    row("Nightscout", status.patient.nightscoutHost ?? "Not set")
                    row("Dexcom", status.patient.dexcom == true ? "Set" : "Not set")
                }
            }
            if !offers("sourceRevision") {
                if !joinedWithInvite.value {
                    Button("Send This App's Sources to the Hub") { sourceAction = .send }
                        .disabled(nightscoutURL.value.isEmpty && dexcomUser.value.isEmpty)
                }
                Button("Use the Hub's Sources in This App") { sourceAction = .take }
                    .disabled(status.map { $0.patient.nightscoutHost == nil && $0.patient.dexcom != true } ?? true)
            }
            if let sourcesInfo {
                Text(sourcesInfo).font(.footnote).foregroundColor(.secondary)
            }
        }

        if isAdmin, offers("invites") {
            Section(footer: Text("An invite lets one more phone follow \(patientDisplayName) as a member.")) {
                Button {
                    Task { await createInvite() }
                } label: {
                    Label("Invite Family Member", systemImage: "person.badge.plus")
                }
            }
        }

        if !devices.isEmpty {
            Section {
                ForEach(devices) { device in
                    deviceEntry(device)
                }
            } header: {
                Text("Devices")
            } footer: {
                if isAdmin { Text("Tap a phone to remove it or change its role.") }
            }
        }

        Section(header: Text("Hub Mode")) {
            row("Background Refresh", backgroundRefreshType.value.rawValue)
            Button("Send Test Alarm") { Task { await testAlarm() } }
            Button("Send Test Alarm in 30 s") { Task { await testAlarm(delaySeconds: 30) } }
            if let testAlarmInfo {
                Text(testAlarmInfo).font(.footnote).foregroundColor(.secondary)
            }
        }

        Section {
            Button("Disconnect", role: .destructive) { confirmingDisconnect = true }
        }
    }

    private var patientDisplayName: String {
        status?.patient.name ?? HubClient.shared.patientName.value
    }

    private var sourcesFooter: String {
        guard offers("sourceRevision") else {
            return "The hub reads Dexcom if set, otherwise Nightscout. Every phone keeps a copy for when LoopFollow reads the data itself."
        }
        return (isAdmin
            ? "A change made here reaches every phone following \(patientDisplayName)."
            : "An admin manages \(patientDisplayName)'s data sources.")
            + " The hub reads Dexcom if set, otherwise Nightscout. Every phone keeps a copy for when LoopFollow reads the data itself."
    }

    /// The checklist for the hub's last answer.
    private var checklist: [HubChecklist.Item] {
        var facts = HubChecklist.Facts()
        facts.hubMode = hubMode
        facts.hubLooksHealthy = HubWatchdog.hubLooksHealthy
        facts.notifications = notifications
        facts.alarmKit = HubChecklist.alarmKitPermission
        facts.liveActivityOn = laEnabled.value
        facts.ownApnKey = !lfKeyId.value.isEmpty && !lfApnsKey.value.isEmpty && !joinedWithInvite.value
        facts.ownKeyAllowed = !joinedWithInvite.value
        facts.isAdmin = isAdmin
        facts.hubSharesKeys = offers("sharedApnsKey")
        facts.sourcesDiffer = HubSourceSync.shared.isActive && HubSourceSync.shared.differsFromHub
        facts.drivesAlarms = HubClient.shared.drivesAlarms
        facts.hubProblems = hubProblems.value
        return HubChecklist.items(status: status, error: statusError, facts: facts, now: Date())
    }

    /// A device of the patient; an admin taps it, or swipes it, for its role and removal.
    @ViewBuilder
    private func deviceEntry(_ device: HubClient.Device) -> some View {
        if isAdmin, device.current != true || (offers("roles") && device.role != nil) {
            Menu {
                deviceActions(device)
            } label: {
                deviceRow(device).contentShape(Rectangle())
            }
            .swipeActions { deviceActions(device) }
        } else {
            deviceRow(device)
        }
    }

    @ViewBuilder
    private func deviceActions(_ device: HubClient.Device) -> some View {
        if offers("roles"), let role = device.role {
            Button(role == .admin ? "Make Member" : "Make Admin") {
                if device.current == true, role == .admin {
                    deviceToDemote = device
                } else {
                    Task { await setRole(role == .admin ? .member : .admin, of: device) }
                }
            }
            .tint(.blue)
        }
        if device.current != true {
            Button("Remove", role: .destructive) { deviceToRemove = device }
        }
    }

    private func deviceRow(_ device: HubClient.Device) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(device.name).foregroundColor(.primary)
                if device.current == true {
                    Text("This device").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                if device.pushFailingSince != nil {
                    Label("Push failing", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            Text(deviceDetail(device)).font(.caption).foregroundColor(.secondary)
        }
    }

    /// Whether the device is an admin, when it was last used, and its app version.
    private func deviceDetail(_ device: HubClient.Device) -> String {
        var parts = [device.lastSeenAt.map { "Last used \(relative($0))" } ?? "Never used"]
        if device.role == .admin { parts.insert("Admin", at: 0) }
        if let version = device.appVersion { parts.append(version) }
        return parts.joined(separator: " · ")
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundColor(.secondary).multilineTextAlignment(.trailing)
        }
    }

    private func relative(_ date: Date) -> String {
        Self.relative(date, now: Date())
    }

    /// A time relative to now; within a minute of now in words.
    static func relative(_ date: Date, now: Date) -> String {
        let interval = date.timeIntervalSince(now)
        if abs(interval) < 60 { return interval > 0 ? "in under a minute" : "just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: now)
    }

    // MARK: - Actions

    /// Runs an action the user started; a failure shows in an alert with `failureTitle`,
    /// in plain words, and goes to the log as the hub said it.
    private func run(_ failureTitle: String, _ action: () async throws -> Void) async {
        busy = true
        do {
            try await action()
        } catch {
            LogManager.shared.log(category: .hub, message: "\(failureTitle): \(error.localizedDescription)")
            actionError = ActionError(title: failureTitle, message: HubClient.userMessage(for: error))
        }
        busy = false
    }

    /// Brings the hub up to date, then reads its view of this device and the patient's devices.
    private func refresh() async {
        guard connected else { return }
        await HubClient.shared.sync()
        await reload()
    }

    /// Reads the hub's view of this device and the patient's devices again, without
    /// sending anything. A hub that does not answer shows on the Ready list.
    private func reload() async {
        guard connected else { return }
        do {
            status = try await HubClient.shared.currentStatus()
            statusError = nil
        } catch {
            if HubClient.isCancellation(error) { return }
            guard connected else {
                status = nil
                statusError = nil
                devices = []
                return
            }
            LogManager.shared.log(category: .hub, message: "Hub status failed: \(error.localizedDescription)")
            statusError = HubClient.userMessage(for: error)
            return
        }
        guard offers("devices") else {
            devices = []
            return
        }
        do {
            devices = try await HubClient.shared.devices()
        } catch {
            LogManager.shared.log(category: .hub, message: "Hub device list failed: \(error.localizedDescription)")
        }
    }

    private func readNotificationPermission() async {
        notifications = await HubChecklist.notificationPermission()
        await HubClient.shared.readNotificationPermission()
    }

    private func listDevices() async {
        await run("Could Not Reach LF Hub") {
            let list = try await HubClient.shared.joinableDevices(url: urlInput, setupToken: setupToken)
            joinInvite = nil
            join = .new
            deviceName = UIDevice.current.model
            joinPatientName = list.patientName
            joinableDevices = list.devices
        }
    }

    /// Reads a scanned, pasted or submitted invite and offers the hub's devices to join as.
    private func readInvite(_ text: String) {
        guard let invite = HubClient.Invite(link: text) else {
            inviteError = "This is not an LF Hub invite link."
            return
        }
        guard invite != joinInvite, !busy else { return }
        inviteError = nil
        Task {
            busy = true
            defer { busy = false }
            do {
                let list = try await HubClient.shared.joinableDevices(invite: invite)
                join = .new
                deviceName = UIDevice.current.model
                joinInvite = invite
                joinPatientName = list.patientName
                joinableDevices = list.devices
            } catch {
                LogManager.shared.log(category: .hub, message: "Invite not read: \(error.localizedDescription)")
                inviteError = HubClient.userMessage(for: error)
            }
        }
    }

    private func leaveInvite() {
        joinInvite = nil
        joinableDevices = nil
        joinPatientName = nil
        inviteLink = ""
        inviteError = nil
    }

    private func connect() async {
        await run("Could Not Join LF Hub") {
            defer {
                if connected {
                    setupToken = ""
                    joinableDevices = nil
                    joinPatientName = nil
                    joinInvite = nil
                    inviteLink = ""
                }
            }
            let choice = joinableDevices?.isEmpty == false ? join : .new
            if let joinInvite {
                try await HubClient.shared.join(invite: joinInvite, deviceName: deviceName, join: choice)
            } else {
                try await HubClient.shared.claim(url: urlInput, setupToken: setupToken, patientName: patientName,
                                                 deviceName: deviceName, join: choice)
            }
        }
        await reload()
        if connected, backgroundRefreshType.value != .hub { offeringHubMode = true }
    }

    private func sendSources() async {
        sourcesInfo = nil
        await run("Could Not Send the Data Sources") {
            try await HubSourceSync.shared.sendOwn()
            sourcesInfo = "Data sources sent to the hub."
            status = try await HubClient.shared.status()
        }
    }

    private func takeSources() async {
        sourcesInfo = nil
        await run("Could Not Use the Hub's Data Sources") {
            try await HubSourceSync.shared.takeHub()
            sourcesInfo = "This app now uses the hub's data sources."
        }
    }

    private func createInvite() async {
        await run("Could Not Create an Invite") {
            let (invite, expiresAt) = try await HubClient.shared.createInvite()
            shownInvite = ShownInvite(invite: invite, expiresAt: expiresAt)
        }
    }

    private func setRole(_ role: HubClient.Role, of device: HubClient.Device) async {
        await run("Could Not Change the Role") {
            try await HubClient.shared.setRole(role, of: device.id)
            LogManager.shared.log(category: .hub, message: "Device \(device.id.uuidString.prefix(8)) made \(role.rawValue)")
        }
        await reload()
    }

    private func remove(_ device: HubClient.Device) async {
        await run("Could Not Remove the Phone") {
            try await HubClient.shared.deleteDevice(device.id)
        }
        await reload()
    }

    private func testAlarm(delaySeconds: Int = 0) async {
        testAlarmInfo = nil
        await run("Could Not Send the Test Alarm") {
            try await HubClient.shared.sendTestAlarm(delaySeconds: delaySeconds)
            testAlarmInfo = delaySeconds > 0 ? "Test alarm in \(delaySeconds) s. Lock the phone now." : "Test alarm sent."
        }
    }

    /// Carries out a checklist item's fix, then reads the hub's view again.
    private func apply(_ fix: HubChecklist.Fix) async {
        await HubChecklist.perform(fix)
        await readNotificationPermission()
        await refresh()
    }

    private func disconnect() async {
        busy = true
        await HubClient.shared.disconnect()
        status = nil
        statusError = nil
        devices = []
        busy = false
    }
}

/// An invite's QR code for another phone to scan in LoopFollow, and its link to share.
struct HubInviteSheet: View {
    let invite: HubClient.Invite
    let expiresAt: Date
    let patientName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    QRCodeDisplayView(qrCodeString: invite.link, size: CGSize(width: 260, height: 260))
                        .padding(.top, 8)
                    Text("On the other phone, open LoopFollow, go to Settings → LF Hub → Join with Invite, and scan this code.")
                        .multilineTextAlignment(.center)
                    Text("The invite works once, until \(expiresAt.formatted(date: .abbreviated, time: .shortened)). Share it only with someone who should follow \(patientName).")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    ShareLink(item: invite.link) {
                        Label("Share Invite Link", systemImage: "square.and.arrow.up")
                    }
                }
                .padding()
            }
            .navigationTitle("Invite Family Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Shown while LF Hub mode is selected and the hub does not drive the alarms:
/// the app alarms itself, and the LF Hub page lists what is missing.
struct HubModeWarning: View {
    @ObservedObject private var backgroundRefreshType = Storage.shared.backgroundRefreshType
    @ObservedObject private var hubConfirmed = HubClient.shared.hubConfirmed
    @ObservedObject private var hubProblems = HubClient.shared.hubProblems
    @ObservedObject private var notificationsAllowed = HubClient.shared.notificationsAllowed
    @ObservedObject private var looksHealthy = HubWatchdog.looksHealthy

    /// Hub mode is selected and the hub does not drive the alarms. The hub's health turns
    /// with time; views follow it through `HubWatchdog.looksHealthy`, set at each check.
    static var isShown: Bool {
        HubClient.isSupported && Storage.shared.backgroundRefreshType.value == .hub && !HubClient.shared.drivesAlarms
    }

    var body: some View {
        if Self.isShown {
            NavigationLink(value: SettingsRoute.hub) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("LF Hub is not sending this phone's alarms", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.red)
                    Text("LoopFollow checks the alarms itself until LF Hub is ready. See what is missing.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
}

/// A compact line on Home while LF Hub mode is selected and the hub does not drive the
/// alarms; tapping it opens the LF Hub page.
struct HubStatusBanner: View {
    let onTap: () -> Void

    @ObservedObject private var backgroundRefreshType = Storage.shared.backgroundRefreshType
    @ObservedObject private var hubConfirmed = HubClient.shared.hubConfirmed
    @ObservedObject private var hubProblems = HubClient.shared.hubProblems
    @ObservedObject private var notificationsAllowed = HubClient.shared.notificationsAllowed
    @ObservedObject private var looksHealthy = HubWatchdog.looksHealthy

    var body: some View {
        if HubModeWarning.isShown {
            Button(action: onTap) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("LF Hub isn't sending alarms. LoopFollow is alarming by itself.")
                        .font(.footnote.weight(.semibold))
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.footnote)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding([.horizontal, .top], 8)
        }
    }
}

/// The LF Hub page on its own, as Home opens it from the banner.
struct HubSettingsSheet: View {
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            HubSettingsView()
                .navigationDestination(for: SettingsRoute.self) { $0.destination }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: onDone)
                    }
                }
        }
    }
}
