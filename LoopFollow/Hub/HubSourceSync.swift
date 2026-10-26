// LoopFollow
// HubSourceSync.swift

import Combine
import CryptoKit
import Foundation

/// This app's Nightscout and Dexcom settings.
struct LocalSources: Equatable {
    var nightscoutURL = ""
    var token = ""
    var dexcomUser = ""
    var dexcomPassword = ""
    var dexcomServer = ""

    var hasNightscout: Bool { !nightscoutURL.isEmpty }
    var hasDexcom: Bool { !dexcomUser.isEmpty && !dexcomPassword.isEmpty }
    var isEmpty: Bool { !hasNightscout && !hasDexcom }

    static func stored() -> LocalSources {
        let storage = Storage.shared
        return LocalSources(nightscoutURL: storage.url.value, token: storage.token.value,
                            dexcomUser: storage.shareUserName.value, dexcomPassword: storage.sharePassword.value,
                            dexcomServer: storage.shareServer.value)
    }

    /// The settings for the hub's sources: one the hub does not have is empty, and a
    /// Dexcom server the hub does not name stays `server`.
    init(_ sources: HubClient.Sources, server: String) {
        if let url = sources.nightscoutUrl, !url.isEmpty {
            nightscoutURL = url
            token = sources.token ?? ""
        }
        dexcomUser = sources.dexcom?.username ?? ""
        dexcomPassword = sources.dexcom?.password ?? ""
        dexcomServer = sources.dexcom?.server.flatMap { $0.isEmpty ? nil : $0 } ?? server
    }

    init(nightscoutURL: String = "", token: String = "", dexcomUser: String = "", dexcomPassword: String = "",
         dexcomServer: String = "")
    {
        self.nightscoutURL = nightscoutURL
        self.token = token
        self.dexcomUser = dexcomUser
        self.dexcomPassword = dexcomPassword
        self.dexcomServer = dexcomServer
    }

    @MainActor func store() {
        let storage = Storage.shared
        storage.url.value = nightscoutURL
        storage.token.value = token
        storage.shareUserName.value = dexcomUser
        storage.sharePassword.value = dexcomPassword
        storage.shareServer.value = dexcomServer
    }

    /// A digest of the settings the hub holds: the token only with a Nightscout address,
    /// the server only with a Dexcom login.
    var digest: String {
        let parts = (hasNightscout ? [nightscoutURL, token] : ["", ""])
            + (hasDexcom ? [dexcomUser, dexcomPassword, dexcomServer] : ["", "", ""])
        return SHA256.hash(data: Data(parts.joined(separator: "\u{0}").utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// Keeps this app's Nightscout and Dexcom settings and the patient's data sources at the
/// hub the same, so the app's own fallback never follows the patient with old credentials.
/// The hub counts each change of the sources in `sourceRevision`; a revision this app has
/// not applied brings the hub's sources here. A change made in this app goes to the hub
/// once the app's own check of the new source succeeds: from an admin phone that did not
/// join with an invite, and from any admin phone while the user is making a change they
/// confirmed. On a member phone the hub's sources are put back.
@MainActor
final class HubSourceSync: ObservableObject {
    static let shared = HubSourceSync()

    enum State: Equatable {
        case idle
        case checking
        case sent
        case failed(String)
    }

    /// The last change this app sent, or why it did not reach the hub.
    @Published private(set) var state = State.idle

    /// The hub's source revision this app's settings follow; -1 before the first.
    private let appliedRevision = StorageValue<Int>(key: "hubAppliedSourceRevision", defaultValue: -1)
    /// `LocalSources.digest` of the settings as they last matched the hub's sources.
    private let syncedDigest = StorageValue<String>(key: "hubSyncedSourcesDigest", defaultValue: "")
    private var busy = false
    /// The settings changed while busy; looked at again when done.
    private var changedWhileBusy = false
    /// An admin confirmed changing the data source here, so the change goes to the hub even
    /// from a phone that joined with an invite. Lasts while the settings are open and
    /// `confirmedChangeGrace` after, so the last edit still settles.
    private var changeConfirmed = false
    private var editingSession = 0
    private static let confirmedChangeGrace: UInt64 = 5
    private var cancellables = Set<AnyCancellable>()

    private var client: HubClient { HubClient.shared }

    /// The hub keeps the patient's data sources in step across the devices.
    var isActive: Bool { client.offers("sourceRevision") }

    /// A member does not import settings on the data source screens: the hub's data source
    /// would replace them.
    var hidesImport: Bool { isActive && client.isMember }

    /// This app's settings are not the hub's sources as this app last saw them.
    var differsFromHub: Bool { LocalSources.stored().digest != syncedDigest.value }

    /// Whether a change of the settings goes to the hub: always from an admin that did not
    /// join with an invite, and from any admin on a change the user confirmed.
    nonisolated static func sendsChange(isAdmin: Bool, joinedWithInvite: Bool, confirmed: Bool) -> Bool {
        isAdmin && (!joinedWithInvite || confirmed)
    }

    /// Whether to take the hub's sources after a status: the hub counts revisions and
    /// this app has not applied the current one.
    nonisolated static func needsSources(hubRevision: Int?, applied: Int) -> Bool {
        guard let hubRevision else { return false }
        return hubRevision != applied
    }

    /// Whether a revision read right after this app changed the sources is that change
    /// alone, so the hub's sources are this app's already.
    nonisolated static func isOwnChange(revisionBefore: Int, revisionAfter: Int?) -> Bool {
        revisionBefore >= 0 && revisionAfter == revisionBefore + 1
    }

    /// Looks at the settings each time they settle after a change.
    func observe() {
        let storage = Storage.shared
        Publishers.MergeMany(storage.url.$value.map { _ in () }.eraseToAnyPublisher(),
                             storage.token.$value.map { _ in () }.eraseToAnyPublisher(),
                             storage.shareUserName.$value.map { _ in () }.eraseToAnyPublisher(),
                             storage.sharePassword.$value.map { _ in () }.eraseToAnyPublisher(),
                             storage.shareServer.$value.map { _ in () }.eraseToAnyPublisher())
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .map { _ in LocalSources.stored() }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in Task { await self?.settingsChanged() } }
            .store(in: &cancellables)
    }

    /// Forgets the hub's sources when this phone leaves the hub.
    func forget() {
        appliedRevision.value = -1
        syncedDigest.value = ""
        state = .idle
    }

    /// Takes the hub's sources when the status shows a revision this app has not applied,
    /// and on a phone that does not send its own whose settings changed here while the hub
    /// could not be asked.
    func follow(_ status: HubClient.Status) async {
        let hubHasSources = status.patient.nightscoutHost != nil || status.patient.dexcom == true
        let memberDiffers = isActive && client.isConnected && !client.isAdmin && hubHasSources && differsFromHub
        guard Self.needsSources(hubRevision: status.patient.sourceRevision, applied: appliedRevision.value)
            || memberDiffers,
            !busy
        else { return }
        busy = true
        defer { done() }
        do {
            try await takeHubSources(revision: status.patient.sourceRevision, sendOwnIfNone: false)
        } catch {
            LogManager.shared.log(category: .hub, message: "Hub data sources not taken: \(error.localizedDescription)")
        }
    }

    /// Makes the hub's sources this app's and records their revision. With none at the
    /// hub, `sendOwnIfNone` gives the hub this app's; otherwise this app's stay as they are.
    func takeHubSources(revision: Int?, sendOwnIfNone: Bool) async throws {
        let sources = try await client.sources()
        let own = LocalSources.stored()
        if sources.isEmpty, sendOwnIfNone, !own.isEmpty {
            try await client.sendSources(own)
            syncedDigest.value = own.digest
            LogManager.shared.log(category: .hub, message: "This app's data sources sent to the hub, which had none")
        } else {
            take(sources)
        }
        if let revision { appliedRevision.value = revision }
        LogManager.shared.log(category: .hub, message: "Hub data source revision \(revision.map(String.init) ?? "none") applied")
    }

    /// Sets this app's Nightscout and Dexcom settings to the hub's sources; with none at
    /// the hub they stay as they are.
    private func take(_ sources: HubClient.Sources) {
        guard !sources.isEmpty else { return }
        let hub = LocalSources(sources, server: Storage.shared.shareServer.value)
        syncedDigest.value = hub.digest
        guard hub != LocalSources.stored() else { return }
        hub.store()
        LogManager.shared.log(category: .hub, message: "Data sources taken from the hub: Nightscout "
            + (hub.hasNightscout ? "set" : "none") + ", Dexcom " + (hub.hasDexcom ? "set" : "none"))
        NotificationCenter.default.post(name: NSNotification.Name("refresh"), object: nil)
    }

    /// Sends this app's settings to the hub as they are, on a hub that does not count
    /// source revisions.
    func sendOwn() async throws {
        let own = LocalSources.stored()
        try await client.sendSources(own)
        syncedDigest.value = own.digest
    }

    /// Makes the hub's sources this app's, on a hub that does not count source revisions.
    func takeHub() async throws {
        try take(await client.sources())
    }

    /// Checks this app's settings again and sends them to the hub; for an admin after a
    /// failed check or a refused change.
    func retry() async {
        await settingsChanged(confirmed: true)
    }

    /// Puts the hub's sources back in this app's settings; for an admin whose change did
    /// not reach the hub.
    func undo() async {
        do {
            try take(await client.sources())
            state = .idle
            LogManager.shared.log(category: .hub, message: "Data source change undone; the hub's sources are back")
        } catch {
            state = .failed("LF Hub could not be reached to bring back its data source. \(HubClient.userMessage(for: error))")
            LogManager.shared.log(category: .hub, message: "Hub data sources not taken for undo: \(error.localizedDescription)")
        }
    }

    /// An admin confirmed changing the settings here; `state` follows the coming change.
    func beginEditing() {
        state = .idle
        changeConfirmed = true
        editingSession += 1
    }

    /// The admin left the settings: a change made from now on is not a confirmed one.
    func endEditing() {
        let session = editingSession
        Task {
            try? await Task.sleep(nanoseconds: Self.confirmedChangeGrace * 1_000_000_000)
            if editingSession == session { changeConfirmed = false }
        }
    }

    /// The settings changed in this app: they go to the hub as `sendsChange` says;
    /// otherwise the hub's come back.
    private func settingsChanged(confirmed: Bool? = nil) async {
        guard isActive, differsFromHub else { return }
        guard !busy else {
            changedWhileBusy = true
            return
        }
        busy = true
        defer { done() }
        let confirmed = confirmed ?? changeConfirmed
        if Self.sendsChange(isAdmin: client.isAdmin, joinedWithInvite: client.joinedWithInvite.value, confirmed: confirmed) {
            await send(LocalSources.stored(), confirmed: confirmed)
        } else {
            LogManager.shared.log(category: .hub, message: "Data sources changed without a change this phone sends; taking the hub's back")
            do {
                try take(await client.sources())
            } catch {
                LogManager.shared.log(category: .hub, message: "Hub data sources not taken: \(error.localizedDescription)")
            }
        }
    }

    private func done() {
        busy = false
        if changedWhileBusy {
            changedWhileBusy = false
            Task { await settingsChanged() }
        }
    }

    /// Sends the settings to the hub once the app's own check of them succeeds.
    private func send(_ sources: LocalSources, confirmed: Bool) async {
        state = .checking
        if let problem = await Self.check(sources) {
            // A newer change is checked on its own.
            guard LocalSources.stored() == sources else {
                state = .idle
                return
            }
            state = .failed(problem)
            LogManager.shared.log(category: .hub, message: "Data source change not sent to the hub: \(problem)")
            return
        }
        guard LocalSources.stored() == sources else {
            state = .idle
            return
        }
        do {
            let before = appliedRevision.value
            try await client.sendSources(sources, confirmed: confirmed)
            syncedDigest.value = sources.digest
            state = .sent
            LogManager.shared.log(category: .hub, message: "Data source change sent to the hub")
            // The new revision is this change; a later one is taken on the next status.
            let after = try await client.status().patient.sourceRevision
            if Self.isOwnChange(revisionBefore: before, revisionAfter: after), let after {
                appliedRevision.value = after
            }
        } catch {
            state = .failed("LF Hub did not take the change: \(Self.reason(error))")
            LogManager.shared.log(category: .hub, message: "Data source change refused by the hub: \(error.localizedDescription)")
        }
    }

    /// A refusal in plain words.
    private static func reason(_ error: Error) -> String {
        HubClient.userMessage(for: error)
    }

    /// Why the settings cannot go to the hub, from the same checks the Nightscout and
    /// Dexcom settings run; nil when every source set here works.
    private static func check(_ sources: LocalSources) async -> String? {
        if sources.isEmpty { return "Add a Nightscout site or a Dexcom login." }
        if sources.hasNightscout {
            let error = await withCheckedContinuation { continuation in
                NightscoutUtils.verifyURLAndToken { error, _, _, _ in continuation.resume(returning: error) }
            }
            if error != nil {
                return "LoopFollow could not connect to this Nightscout site, so LF Hub keeps the old data source."
            }
        }
        if sources.hasDexcom {
            let result = await withCheckedContinuation { continuation in
                DexcomSettingsViewModel.checkLogin(userName: sources.dexcomUser, password: sources.dexcomPassword,
                                                   server: sources.dexcomServer) { continuation.resume(returning: $0) }
            }
            switch result {
            case .accepted: break
            case .rejected: return "Dexcom did not accept this login, so LF Hub keeps the old data source."
            case .unreachable: return "LoopFollow could not reach Dexcom to check the login, so LF Hub keeps the old data source."
            }
        }
        return nil
    }
}
