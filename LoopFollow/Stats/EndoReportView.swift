// LoopFollow
// EndoReportView.swift

import SwiftUI

struct EndoReportView: View {
    let dataService: StatsDataService

    @Environment(\.dismiss) private var dismiss

    // Persisted patient/clinic info
    @AppStorage("endoReport.patientName") private var patientName = ""
    @AppStorage("endoReport.dateOfBirth") private var dateOfBirth = ""
    @AppStorage("endoReport.providerName") private var providerName = ""
    @AppStorage("endoReport.insulinType") private var insulinType = ""
    @AppStorage("endoReport.diagnosisDate") private var diagnosisDate = ""
    @AppStorage("endoReport.aidSystem") private var aidSystem = "Loop"
    @AppStorage("endoReport.pumpDevice") private var pumpDevice = ""
    @AppStorage("endoReport.cgmDevice") private var cgmDevice = ""
    @AppStorage("endoReport.units") private var units = "mg/dL"
    @AppStorage("endoReport.accentColorHex") private var accentColorHex = "#23A0AC"
    @AppStorage("endoReport.includeDailyBreakdown") private var includeDailyBreakdown = true
    @AppStorage("endoReport.includeFatProtein") private var includeFatProtein = false

    // Therapy settings (manual entry)
    @AppStorage("endoReport.carbRatio") private var carbRatio = ""
    @AppStorage("endoReport.isf") private var isf = ""
    @AppStorage("endoReport.basalRate") private var basalRate = ""
    @AppStorage("endoReport.targetGlucose") private var targetGlucose = ""

    // Date range
    @State private var startDate: Date = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
    @State private var endDate: Date = .init()

    // UI state
    @StateObject private var profileFetcher = NightscoutProfileFetcher()
    @State private var isGenerating = false
    @State private var reportURL: URL?
    @State private var errorMessage: String?
    @State private var showShareSheet = false
    @State private var showColorPicker = false
    @State private var pickedColor: Color = .init(hex: "#23A0AC") ?? .teal
    @State private var fetchSuccess = false

    let aidOptions = ["Loop", "Trio", "OpenAPS", "Android APS", "CamAPS FX", "Other"]
    let unitOptions = ["mg/dL", "mmol/L"]

    var body: some View {
        NavigationView {
            Form {
                // ── Patient ──────────────────────────────────────────────
                Section(header: label("Patient Information", icon: "person.fill")) {
                    row("Name", placeholder: "Full name", text: $patientName)
                    row("Date of Birth", placeholder: "MM/DD/YYYY", text: $dateOfBirth)
                    row("Diagnosed", placeholder: "Year (optional)", text: $diagnosisDate)
                    row("Provider", placeholder: "Dr. Name", text: $providerName)
                }

                // ── Devices & AID ─────────────────────────────────────────
                Section(header: label("Devices & System", icon: "gear")) {
                    Picker("AID System", selection: $aidSystem) {
                        ForEach(aidOptions, id: \.self) { Text($0) }
                    }
                    row("Pump", placeholder: "e.g. Omnipod 5", text: $pumpDevice)
                    row("CGM", placeholder: "e.g. Dexcom G7", text: $cgmDevice)
                    row("Insulin", placeholder: "e.g. Humalog", text: $insulinType)
                }

                // ── Therapy settings ──────────────────────────────────────
                Section(header: label("Current Therapy Settings", icon: "slider.horizontal.3")) {
                    // Fetch from Nightscout button
                    Button(action: fetchFromNightscout) {
                        HStack {
                            if profileFetcher.isFetching {
                                ProgressView().scaleEffect(0.8)
                                Text("Fetching from Nightscout…")
                                    .font(.subheadline)
                            } else {
                                Image(systemName: fetchSuccess ? "checkmark.circle.fill" : "arrow.down.circle")
                                    .foregroundColor(fetchSuccess ? .green : .accentColor)
                                Text(fetchSuccess ? "Settings Fetched!" : "Auto-Fill from Nightscout")
                                    .font(.subheadline)
                            }
                            Spacer()
                        }
                    }
                    .disabled(profileFetcher.isFetching)

                    if let fetchErr = profileFetcher.error {
                        Label(fetchErr, systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    row("Carb Ratio (CR)", placeholder: "g/U  e.g. 10", text: $carbRatio, keyboard: .decimalPad)
                    row("ISF", placeholder: "mg/dL per U", text: $isf, keyboard: .decimalPad)
                    row("Basal Rate", placeholder: "U/hr  e.g. 0.85", text: $basalRate, keyboard: .decimalPad)
                    row("Target Glucose", placeholder: "mg/dL  e.g. 100", text: $targetGlucose, keyboard: .decimalPad)
                }

                // ── Report period ─────────────────────────────────────────
                Section(header: label("Report Period", icon: "calendar")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(presets, id: \.label) { p in
                                Button(p.label) {
                                    startDate = p.start; endDate = p.end
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .tint(isActive(p) ? .teal : .secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    DatePicker("Start", selection: $startDate, in: ...endDate, displayedComponents: .date)
                    DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
                }

                // ── Report options ────────────────────────────────────────
                Section(header: label("Report Options", icon: "doc.richtext")) {
                    Picker("Units", selection: $units) {
                        ForEach(unitOptions, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Include Daily Breakdown", isOn: $includeDailyBreakdown)
                    Toggle("Include Fat & Protein", isOn: $includeFatProtein)

                    HStack {
                        Text("Accent Color")
                        Spacer()
                        Circle()
                            .fill(pickedColor)
                            .frame(width: 24, height: 24)
                            .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                        if #available(iOS 16.0, *) {
                            ColorPicker("", selection: $pickedColor, supportsOpacity: false)
                                .labelsHidden()
                                .onChange(of: pickedColor) { newVal in
                                    accentColorHex = newVal.toHex() ?? "#23A0AC"
                                }
                        }
                    }
                }

                // ── What's included ───────────────────────────────────────
                Section(header: label("Report Includes", icon: "checklist")) {
                    Group {
                        Label("eA1C / GMI estimate", systemImage: "drop.fill")
                        Label("Time in Range distribution", systemImage: "chart.bar.fill")
                        Label("Ambulatory Glucose Profile", systemImage: "waveform.path.ecg")
                        Label("Glucose by time of day", systemImage: "clock.fill")
                        Label("Insulin delivery summary", systemImage: "syringe.fill")
                        if includeDailyBreakdown {
                            Label("Daily breakdown (newest first)", systemImage: "calendar.day.timeline.left")
                        }
                        if includeFatProtein {
                            Label("Fat & protein entries", systemImage: "fork.knife")
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }

                // ── Error ─────────────────────────────────────────────────
                if let err = errorMessage {
                    Section {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }
                }

                // ── Generate ──────────────────────────────────────────────
                Section {
                    Button(action: generate) {
                        HStack {
                            Spacer()
                            if isGenerating {
                                ProgressView().padding(.trailing, 6)
                                Text("Generating…").fontWeight(.semibold)
                            } else {
                                Image(systemName: "doc.richtext").padding(.trailing, 4)
                                Text("Generate PDF Report").fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isGenerating)
                    .foregroundColor(.white)
                    .listRowBackground(isGenerating ? Color.teal.opacity(0.5) : Color.teal)
                }
            }
            .navigationTitle("Endo Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = reportURL { ShareSheet(items: [url]) }
            }
            .onAppear {
                pickedColor = Color(hex: accentColorHex) ?? .teal
            }
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func row(_ label: String, placeholder: String, text: Binding<String>,
                     keyboard: UIKeyboardType = .default) -> some View
    {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 110, alignment: .leading)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
        }
    }

    private func label(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption)
            .textCase(.uppercase)
    }

    // MARK: - Presets

    private struct Preset { let label: String; let start: Date; let end: Date }
    private var presets: [Preset] {
        let now = Date(); let cal = Calendar.current
        return [
            Preset(label: "3d", start: cal.date(byAdding: .day, value: -3, to: now)!, end: now),
            Preset(label: "7d", start: cal.date(byAdding: .day, value: -7, to: now)!, end: now),
            Preset(label: "14d", start: cal.date(byAdding: .day, value: -14, to: now)!, end: now),
            Preset(label: "30d", start: cal.date(byAdding: .day, value: -30, to: now)!, end: now),
            Preset(label: "90d", start: cal.date(byAdding: .day, value: -90, to: now)!, end: now),
        ]
    }

    private func isActive(_ p: Preset) -> Bool {
        Calendar.current.isDate(p.start, inSameDayAs: startDate) &&
            Calendar.current.isDate(p.end, inSameDayAs: endDate)
    }

    // MARK: - Fetch from Nightscout

    private func fetchFromNightscout() {
        fetchSuccess = false
        profileFetcher.fetch { settings in
            guard let s = settings else { return }
            carbRatio = s.carbRatio
            isf = s.isf
            basalRate = s.basalRate
            // Target: show low-high range if both present
            if !s.targetLow.isEmpty && !s.targetHigh.isEmpty {
                targetGlucose = "\(s.targetLow)–\(s.targetHigh)"
            } else {
                targetGlucose = s.targetLow.isEmpty ? s.targetHigh : s.targetLow
            }
            // Auto-set units from profile
            units = s.units
            fetchSuccess = true
            // Reset success indicator after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                fetchSuccess = false
            }
        }
    }

    // MARK: - Generate

    private func generate() {
        errorMessage = nil
        isGenerating = true
        dataService.updateDateRange(start: startDate, end: endDate)
        dataService.ensureDataAvailable(onProgress: {}) {
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let config = EndoReportConfig(
                        patientName: patientName,
                        dateOfBirth: dateOfBirth,
                        diagnosisDate: diagnosisDate,
                        providerName: providerName,
                        insulinType: insulinType,
                        aidSystem: aidSystem,
                        pumpDevice: pumpDevice,
                        cgmDevice: cgmDevice,
                        carbRatio: carbRatio,
                        isf: isf,
                        basalRate: basalRate,
                        targetGlucose: targetGlucose,
                        units: units,
                        accentColorHex: accentColorHex,
                        includeDailyBreakdown: includeDailyBreakdown,
                        includeFatProtein: includeFatProtein,
                        startDate: startDate,
                        endDate: endDate
                    )
                    let url = try EndoReportGenerator.generate(config: config, dataService: dataService)
                    DispatchQueue.main.async {
                        isGenerating = false
                        reportURL = url
                        showShareSheet = true
                    }
                } catch {
                    DispatchQueue.main.async {
                        isGenerating = false
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}

// MARK: - Config struct (passed to generator)

struct EndoReportConfig {
    let patientName: String
    let dateOfBirth: String
    let diagnosisDate: String
    let providerName: String
    let insulinType: String
    let aidSystem: String
    let pumpDevice: String
    let cgmDevice: String
    let carbRatio: String
    let isf: String
    let basalRate: String
    let targetGlucose: String
    let units: String
    let accentColorHex: String
    let includeDailyBreakdown: Bool
    let includeFatProtein: Bool
    let startDate: Date
    let endDate: Date

    var accentColor: UIColor {
        UIColor(hex: accentColorHex) ?? UIColor(red: 0.137, green: 0.624, blue: 0.675, alpha: 1)
    }

    var isMMOL: Bool { units == "mmol/L" }
    func fmtBG(_ mgdl: Double) -> String {
        isMMOL ? String(format: "%.1f", mgdl * 0.0555) : String(format: "%.0f", mgdl)
    }

    var accentUIColor: UIColor {
        UIColor(hex: accentColorHex) ?? UIColor(red: 0.137, green: 0.624, blue: 0.675, alpha: 1)
    }
}

// MARK: - Share sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}

// MARK: - Color extensions

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if h.count == 6 { h += "FF" }
        guard h.count == 8, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red: Double((val >> 24) & 0xFF) / 255,
            green: Double((val >> 16) & 0xFF) / 255,
            blue: Double((val >> 8) & 0xFF) / 255,
            opacity: Double(val & 0xFF) / 255
        )
    }

    func toHex() -> String? {
        guard let c = UIColor(self).cgColor.components, c.count >= 3 else { return nil }
        return String(format: "#%02X%02X%02X",
                      Int(c[0] * 255), Int(c[1] * 255), Int(c[2] * 255))
    }
}

extension UIColor {
    convenience init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if h.count == 6 { h += "FF" }
        guard h.count == 8, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red: CGFloat((val >> 24) & 0xFF) / 255,
            green: CGFloat((val >> 16) & 0xFF) / 255,
            blue: CGFloat((val >> 8) & 0xFF) / 255,
            alpha: CGFloat(val & 0xFF) / 255
        )
    }
}

// MARK: - NightscoutProfileFetcher

class NightscoutProfileFetcher: ObservableObject {
    @Published var isFetching = false
    @Published var error: String?
    @Published var success = false

    struct FetchedSettings {
        let carbRatio: String
        let isf: String
        let basalRate: String
        let targetLow: String
        let targetHigh: String
        let units: String
    }

    func fetch(completion: @escaping (FetchedSettings?) -> Void) {
        isFetching = true
        error = nil
        success = false

        NightscoutUtils.executeRequest(
            eventType: .profile,
            parameters: [:]
        ) { [weak self] (result: Result<NSProfile, Error>) in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isFetching = false

                switch result {
                case let .failure(err):
                    self.error = err.localizedDescription
                    completion(nil)

                case let .success(profile):
                    // Use defaultProfile store, fall back to "default" / "Default"
                    let store = profile.store[profile.defaultProfile]
                        ?? profile.store["default"]
                        ?? profile.store["Default"]
                        ?? profile.store.values.first

                    guard let s = store else {
                        self.error = "No profile store found in Nightscout response."
                        completion(nil)
                        return
                    }

                    let isMMOL = s.units.lowercased().contains("mmol")

                    // Pick the first (midnight) entry for each schedule
                    // and format a readable multi-segment string if >1 entry
                    func fmtSchedule<T>(_ entries: [T],
                                        value: (T) -> Double,
                                        time: (T) -> String) -> String
                    {
                        if entries.count == 1 {
                            return String(format: isMMOL ? "%.2f" : "%.0f", value(entries[0]))
                        }
                        return entries.prefix(6).map {
                            "\(time($0)): \(String(format: isMMOL ? "%.2f" : "%.0f", value($0)))"
                        }.joined(separator: " | ")
                    }

                    let cr = fmtSchedule(s.carbratio, value: { $0.value }, time: { $0.time })
                    let isf = fmtSchedule(s.sens, value: { $0.value }, time: { $0.time })
                    let bas = fmtSchedule(s.basal, value: { $0.value }, time: { $0.time })

                    let targetLow = s.target_low?.first.map { String(format: isMMOL ? "%.1f" : "%.0f", $0.value) } ?? ""
                    let targetHigh = s.target_high?.first.map { String(format: isMMOL ? "%.1f" : "%.0f", $0.value) } ?? ""

                    self.success = true
                    completion(FetchedSettings(
                        carbRatio: cr,
                        isf: isf,
                        basalRate: bas,
                        targetLow: targetLow,
                        targetHigh: targetHigh,
                        units: isMMOL ? "mmol/L" : "mg/dL"
                    ))
                }
            }
        }
    }
}
