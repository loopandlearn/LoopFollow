// LoopFollow
// EndoReportView.swift

import SwiftUI

struct EndoReportView: View {
    let dataService: StatsDataService

    @Environment(\.dismiss) private var dismiss

    // Patient info — persisted in UserDefaults so they don't retype each time
    @AppStorage("endoReport.patientName") private var patientName = ""
    @AppStorage("endoReport.dateOfBirth") private var dateOfBirth = ""
    @AppStorage("endoReport.providerName") private var providerName = ""

    // Date range defaults to last 14 days
    @State private var startDate: Date = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
    @State private var endDate: Date = .init()

    @State private var isGenerating = false
    @State private var reportURL: URL?
    @State private var errorMessage: String?
    @State private var showShareSheet = false
    @State private var showingDates = false

    var body: some View {
        NavigationView {
            Form {
                // ── Patient info ─────────────────────────────────────────
                Section(header: Text("Patient Information")
                    .font(.caption).textCase(.uppercase))
                {
                    HStack {
                        Text("Name")
                            .foregroundColor(.secondary)
                            .frame(width: 90, alignment: .leading)
                        TextField("Full name", text: $patientName)
                    }
                    HStack {
                        Text("Date of Birth")
                            .foregroundColor(.secondary)
                            .frame(width: 90, alignment: .leading)
                        TextField("MM/DD/YYYY", text: $dateOfBirth)
                            .keyboardType(.numbersAndPunctuation)
                    }
                    HStack {
                        Text("Provider")
                            .foregroundColor(.secondary)
                            .frame(width: 90, alignment: .leading)
                        TextField("Dr. Name", text: $providerName)
                    }
                }

                // ── Date range ───────────────────────────────────────────
                Section(header: Text("Report Period")
                    .font(.caption).textCase(.uppercase))
                {
                    // Quick presets
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(presets, id: \.label) { preset in
                                Button(preset.label) {
                                    withAnimation {
                                        startDate = preset.start
                                        endDate = preset.end
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .tint(isActivePreset(preset) ? .blue : .secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    DatePicker("Start", selection: $startDate,
                               in: ...endDate,
                               displayedComponents: .date)
                    DatePicker("End", selection: $endDate,
                               in: startDate...,
                               displayedComponents: .date)
                }

                // ── What's included ──────────────────────────────────────
                Section(header: Text("Report Includes")
                    .font(.caption).textCase(.uppercase))
                {
                    Label("eA1C / GMI estimate", systemImage: "drop.fill")
                    Label("Time in Range distribution", systemImage: "chart.bar.fill")
                    Label("Ambulatory Glucose Profile", systemImage: "waveform.path.ecg")
                    Label("Daily glucose statistics", systemImage: "calendar")
                    Label("Insulin & carb summary", systemImage: "syringe.fill")
                }
                .foregroundColor(.secondary)
                .font(.subheadline)

                // ── Error message ────────────────────────────────────────
                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }
                }

                // ── Generate button ──────────────────────────────────────
                Section {
                    Button(action: generateReport) {
                        HStack {
                            Spacer()
                            if isGenerating {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Generating…")
                                    .fontWeight(.semibold)
                            } else {
                                Image(systemName: "doc.richtext")
                                    .padding(.trailing, 4)
                                Text("Generate PDF Report")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isGenerating)
                    .foregroundColor(.white)
                    .listRowBackground(isGenerating ? Color.blue.opacity(0.5) : Color.blue)
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
                if let url = reportURL {
                    ShareSheet(items: [url])
                }
            }
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
    }

    // MARK: - Presets

    private struct DatePreset {
        let label: String
        let start: Date
        let end: Date
    }

    private var presets: [DatePreset] {
        let now = Date()
        let cal = Calendar.current
        return [
            DatePreset(label: "7 days",
                       start: cal.date(byAdding: .day, value: -7, to: now) ?? now, end: now),
            DatePreset(label: "14 days",
                       start: cal.date(byAdding: .day, value: -14, to: now) ?? now, end: now),
            DatePreset(label: "30 days",
                       start: cal.date(byAdding: .day, value: -30, to: now) ?? now, end: now),
            DatePreset(label: "90 days",
                       start: cal.date(byAdding: .day, value: -90, to: now) ?? now, end: now),
        ]
    }

    private func isActivePreset(_ preset: DatePreset) -> Bool {
        let cal = Calendar.current
        return cal.isDate(preset.start, inSameDayAs: startDate) &&
            cal.isDate(preset.end, inSameDayAs: endDate)
    }

    // MARK: - Generate

    private func generateReport() {
        errorMessage = nil
        isGenerating = true

        // Update the data service date range to match what the user picked
        dataService.updateDateRange(start: startDate, end: endDate)

        // Fetch data if needed, then generate
        dataService.ensureDataAvailable(onProgress: {}) {
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let url = try EndoReportGenerator.generate(
                        patientName: patientName,
                        dateOfBirth: dateOfBirth,
                        providerName: providerName,
                        startDate: startDate,
                        endDate: endDate,
                        dataService: dataService
                    )
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

// MARK: - Share sheet wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}
