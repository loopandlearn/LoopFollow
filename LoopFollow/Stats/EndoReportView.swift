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

    // Optional Toggle Modules
    @AppStorage("endoReport.includeGlucoseSummary") private var includeGlucoseSummary = true
    @AppStorage("endoReport.includeInsulin") private var includeInsulin = true
    @AppStorage("endoReport.includeNutrition") private var includeNutrition = true
    @AppStorage("endoReport.includeTherapySettings") private var includeTherapySettings = true
    @AppStorage("endoReport.includeDevices") private var includeDevices = true
    @AppStorage("endoReport.includeAGP") private var includeAGP = true
    @AppStorage("endoReport.includeDailyBreakdown") private var includeDailyBreakdown = true
    @AppStorage("endoReport.includeFatProtein") private var includeFatProtein = false

    // Therapy settings (manual entry)
    @AppStorage("endoReport.carbRatio") private var carbRatio = ""
    @AppStorage("endoReport.isf") private var isf = ""
    @AppStorage("endoReport.basalRate") private var basalRate = ""
    @AppStorage("endoReport.targetGlucose") private var targetGlucose = ""
    @AppStorage("endoReport.customAidSystem") private var customAidSystem = ""
    @AppStorage("endoReport.notes") private var notes = ""

    // Date range
    @State private var startDate: Date = StatsDateRange.lastComplete(days: 14).start
    @State private var endDate: Date = StatsDateRange.lastComplete(days: 14).end

    // UI state
    @StateObject private var profileFetcher = NightscoutProfileFetcher()
    @State private var isGenerating = false
    @State private var reportURL: URL?
    @State private var errorMessage: String?
    @State private var showShareSheet = false
    @State private var pickedColor: Color = .init(hex: "#23A0AC") ?? .teal
    @State private var fetchSuccess = false
    @State private var showTherapyScheduleExamples = false
    @State private var therapyMode: TherapyInputMode = .simple

    let aidOptions = ["Trio", "Loop", "iAPS", "Other"]
    let unitOptions = ["mg/dL", "mmol/L"]

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    sectionCard("Report Period", icon: "calendar", color: .blue) {
                        VStack(spacing: 16) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(presets, id: \.label) { p in
                                        Button(action: {
                                            startDate = p.start; endDate = p.end
                                        }) {
                                            Text(p.label)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(isActive(p) ? .teal : .secondary)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 10)
                                                .background(isActive(p) ? Color.teal.opacity(0.16) : Color(UIColor.systemGray5))
                                                .cornerRadius(12)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }

                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Start")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    DatePicker("", selection: $startDate, in: ...endDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .datePickerStyle(.compact)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("End")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                                        .labelsHidden()
                                        .datePickerStyle(.compact)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }

                    sectionCard("Patient Information", icon: "person.fill", color: .indigo) {
                        VStack(spacing: 16) {
                            row("Name", placeholder: "Full name", text: $patientName)
                            row("DOB", placeholder: "MM/DD/YYYY", text: $dateOfBirth)
                            row("Diagnosed", placeholder: "Year (optional)", text: $diagnosisDate)
                            row("Provider", placeholder: "Dr. Name", text: $providerName)
                        }
                    }

                    sectionCard("Devices & System", icon: "iphone.radiowaves.left.and.right", color: .teal) {
                        VStack(spacing: 16) {
                            HStack {
                                Text("AID System")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                                Spacer()
                                Picker("AID System", selection: $aidSystem) {
                                    ForEach(aidOptions, id: \.self) { Text($0) }
                                }
                                .pickerStyle(.menu)
                            }

                            if aidSystem == "Other" {
                                row("Custom AID", placeholder: "Enter AID system", text: $customAidSystem)
                            }

                            row("Pump", placeholder: "e.g. Omnipod 5", text: $pumpDevice)
                            row("CGM", placeholder: "e.g. Dexcom G7", text: $cgmDevice)
                            row("Insulin", placeholder: "e.g. Humalog", text: $insulinType)
                        }
                    }

                    sectionCard("Therapy Settings", icon: "slider.horizontal.3", color: .orange) {
                        VStack(spacing: 16) {
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
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color(UIColor.systemGray6)))
                            }
                            .disabled(profileFetcher.isFetching)

                            if let fetchErr = profileFetcher.error {
                                Label(fetchErr, systemImage: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }

                            Picker("Input mode", selection: $therapyMode) {
                                ForEach(TherapyInputMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.vertical, 8)

                            Text("Simple values are best for most users. Use schedule mode only if you have time-based settings.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            // Legend for schedule previews
                            HStack(spacing: 16) {
                                HStack(spacing: 8) {
                                    Circle().fill(Color.mint).frame(width: 10, height: 10)
                                    Text("Carb Ratio").font(.caption).foregroundColor(.secondary)
                                }
                                HStack(spacing: 8) {
                                    Circle().fill(Color.indigo).frame(width: 10, height: 10)
                                    Text("ISF").font(.caption).foregroundColor(.secondary)
                                }
                                HStack(spacing: 8) {
                                    Circle().fill(Color.orange).frame(width: 10, height: 10)
                                    Text("Basal Rate").font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                            }

                            if therapyMode == .simple {
                                row("Carb Ratio", placeholder: "10", text: $carbRatio, keyboard: .decimalPad)
                                row("ISF", placeholder: "1.8", text: $isf, keyboard: .decimalPad)
                                row("Basal Rate (U/hr)", placeholder: "0.80", text: $basalRate, keyboard: .decimalPad)
                                row("Target BG", placeholder: "100–120", text: $targetGlucose, keyboard: .numbersAndPunctuation)
                            } else {
                                therapySettingRow(
                                    "Carb Ratio (g/U)", icon: "leaf.fill", text: $carbRatio,
                                    placeholder: "00:00 = 10",
                                    help: "Schedule one entry per line.",
                                    keyboard: .decimalPad
                                )

                                // Preview for carb ratio schedule
                                therapySchedulePreview(for: carbRatio, title: "Carb Ratio Schedule Preview", accent: .mint)

                                therapySettingRow(
                                    "ISF (per U)", icon: "drop.fill", text: $isf,
                                    placeholder: "00:00 = 45",
                                    help: "Schedule one entry per line.",
                                    keyboard: .decimalPad
                                )

                                // Preview for ISF schedule
                                therapySchedulePreview(for: isf, title: "ISF Schedule Preview", accent: .indigo)

                                therapySettingRow(
                                    "Basal Rate (U/hr)", icon: "waveform.path.ecg", text: $basalRate,
                                    placeholder: "00:00 = 0.8",
                                    help: "Schedule one entry per line.",
                                    keyboard: .decimalPad
                                )

                                // Basal preview (already present)
                                VStack(spacing: 8) {
                                    therapySchedulePreview(for: basalRate, title: "Basal Rate Schedule Preview", accent: .orange)
                                    Text("Format: HH:MM = rate (e.g., 00:00 = 0.8, 06:00 = 1.0)").font(.caption2).foregroundColor(.secondary)
                                }

                                row("Target BG", placeholder: "100–120", text: $targetGlucose, keyboard: .numbersAndPunctuation)

                                DisclosureGroup(isExpanded: $showTherapyScheduleExamples) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Schedule examples:")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Text("00:00 = 10\n06:00 = 9\n12:00 = 11\n18:00 = 10")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(10)
                                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.systemGray6)))
                                        Text("Use this mode only if you need multiple time-based values.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                } label: {
                                    Text("Show schedule entry examples")
                                        .font(.subheadline)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }

                    sectionCard("Clinician Notes", icon: "pencil.and.outline", color: .gray) {
                        VStack(alignment: .leading, spacing: 8) {
                            TextEditor(text: $notes)
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color(UIColor.systemGray6)))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
                                )
                                .frame(minHeight: 100)
                        }
                    }

                    sectionCard("Included Report Modules", icon: "checklist", color: .green) {
                        VStack(spacing: 12) {
                            toggleRow("Glucose Summary & TIR", isOn: $includeGlucoseSummary)
                            toggleRow("Insulin Delivery", isOn: $includeInsulin)
                            toggleRow("Nutrition & Meals", isOn: $includeNutrition)
                            toggleRow("Current Therapy Settings", isOn: $includeTherapySettings)
                            toggleRow("Devices & Insulin Type", isOn: $includeDevices)
                            toggleRow("AGP Chart", isOn: $includeAGP)
                            toggleRow("Daily Breakdowns", isOn: $includeDailyBreakdown)
                        }
                    }

                    sectionCard("Report Formatting", icon: "paintpalette.fill", color: .purple) {
                        VStack(spacing: 18) {
                            Picker("Units", selection: $units) {
                                ForEach(unitOptions, id: \.self) { Text($0) }
                            }
                            .pickerStyle(.segmented)

                            HStack {
                                Text("Theme Color")
                                    .foregroundColor(.secondary)
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
                    }

                    if let err = errorMessage {
                        Text(err)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.red.opacity(0.85)))
                    }

                    Button(action: generate) {
                        HStack {
                            Spacer()
                            if isGenerating {
                                ProgressView().padding(.trailing, 8)
                                Text("Generating Report…").fontWeight(.semibold)
                            } else {
                                Image(systemName: "doc.text.fill").padding(.trailing, 6)
                                Text("Create PDF").fontWeight(.semibold)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 18).fill(Color.teal))
                        .foregroundColor(.white)
                    }
                    .disabled(isGenerating)
                    .opacity(isGenerating ? 0.7 : 1)
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
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

    private enum TherapyInputMode: String, CaseIterable, Identifiable {
        case simple = "Simple"
        case schedule = "Schedule"

        var id: String { rawValue }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func row(_ label: String, placeholder: String, text: Binding<String>,
                     keyboard: UIKeyboardType = .default) -> some View
    {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .foregroundColor(.secondary)
                .font(.subheadline)
                .frame(width: 110, alignment: .leading)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(UIColor.systemGray6)))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
                )
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func therapySettingRow(_ label: String, icon: String, text: Binding<String>, placeholder: String, help: String, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(UIColor.systemGray5))
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .foregroundColor(.orange)
                        .font(.system(size: 14, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .foregroundColor(.primary)
                        .font(.subheadline)
                    Text(help)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
                TextEditor(text: text)
                    .keyboardType(keyboard)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(UIColor.systemGray6)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
                    )
                    .frame(minHeight: 100)
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func therapySchedulePreview(for schedule: String, title: String, accent: Color) -> some View {
        let points = parseSchedule(schedule)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if points.count > 1 {
                    Text("Min: \(formatted(points.map { $0.value }.min() ?? 0))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if points.count > 1 {
                scheduleGraph(points: points, accent: accent)
                HStack {
                    Text("00:00")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("24:00")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Enter a schedule like 00:00 = 0.8 to visualize the trend.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(UIColor.systemGray6)))
    }

    private func parseSchedule(_ input: String) -> [(hour: Double, value: Double)] {
        let lines = input
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var points: [(Double, Double)] = []
        for line in lines {
            let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2,
                  let value = Double(parts[1].replacingOccurrences(of: ",", with: "."))
            else {
                continue
            }

            let timeParts = parts[0].split(separator: ":").map { String($0) }
            guard timeParts.count == 2,
                  let hour = Double(timeParts[0]),
                  let minute = Double(timeParts[1])
            else {
                continue
            }
            let hourValue = max(0, min(24, hour + minute / 60.0))
            points.append((hourValue, value))
        }

        let sorted = points.sorted { $0.0 < $1.0 }
        guard let first = sorted.first else { return [] }

        var result = sorted
        if sorted.count == 1 {
            result = [(0, first.1), (24, first.1)]
        } else {
            if first.0 > 0 {
                result.insert((0, first.1), at: 0)
            }
            if let last = result.last, last.0 < 24 {
                result.append((24, last.1))
            }
        }
        return result
    }

    private func scheduleGraph(points: [(hour: Double, value: Double)], accent: Color) -> some View {
        GeometryReader { proxy in
            let minValue = points.map { $0.value }.min() ?? 0
            let maxValue = points.map { $0.value }.max() ?? 1
            let range = max(maxValue - minValue, 0.1)

            // Stepped Area Fill
            Path { path in
                guard let first = points.first else { return }
                path.move(to: CGPoint(x: proxy.size.width * CGFloat(first.hour / 24), y: proxy.size.height))

                for i in 0 ..< points.count {
                    let x = proxy.size.width * CGFloat(points[i].hour / 24)
                    let y = proxy.size.height * (1 - CGFloat((points[i].value - minValue) / range))
                    if i > 0 {
                        let prevY = proxy.size.height * (1 - CGFloat((points[i - 1].value - minValue) / range))
                        path.addLine(to: CGPoint(x: x, y: prevY))
                    }
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                if let last = points.last {
                    path.addLine(to: CGPoint(x: proxy.size.width * CGFloat(last.hour / 24), y: proxy.size.height))
                }
                path.closeSubpath()
            }
            .fill(accent.opacity(0.15))

            // Stepped Line
            Path { path in
                for index in points.indices {
                    let point = points[index]
                    let x = proxy.size.width * CGFloat(point.hour / 24)
                    let y = proxy.size.height * (1 - CGFloat((point.value - minValue) / range))
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        let prevPoint = points[index - 1]
                        let prevY = proxy.size.height * (1 - CGFloat((prevPoint.value - minValue) / range))
                        path.addLine(to: CGPoint(x: x, y: prevY))
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(accent, lineWidth: 2)

            ForEach(points.indices, id: \.self) { index in
                let point = points[index]
                let x = proxy.size.width * CGFloat(point.hour / 24)
                let y = proxy.size.height * (1 - CGFloat((point.value - minValue) / range))
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)
                    .position(x: x, y: y)
            }
        }
        .frame(height: 140)
    }

    private func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }

    @ViewBuilder
    private func settingCard<Content: View>(_ title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.18))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
            }
            content()
        }
        .padding(12)
        .background(Color(UIColor.systemBackground).overlay(color.opacity(0.1)))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    private func sectionCard<Content: View>(_ title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(title, icon: icon, color: color)
            content()
        }
        .padding(14)
        .background(Color(UIColor.systemBackground).overlay(color.opacity(0.1)))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 10)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isOn.wrappedValue ? Color.teal.opacity(0.18) : Color.secondary.opacity(0.12))
                    .frame(width: 30, height: 30)
                Image(systemName: toggleIcon(for: title))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isOn.wrappedValue ? .teal : .secondary)
            }
            Toggle(isOn: isOn) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            .toggleStyle(SwitchToggleStyle(tint: .teal))
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(UIColor.systemGray6)))
    }

    private func toggleIcon(for title: String) -> String {
        let lower = title.lowercased()
        if lower.contains("glucose") { return "waveform.path.ecg" }
        if lower.contains("insulin") { return "drop.fill" }
        if lower.contains("nutrition") { return "fork.knife" }
        if lower.contains("therapy") { return "heart.text.square" }
        if lower.contains("devices") { return "iphone" }
        if lower.contains("agp") { return "chart.bar.doc.horizontal" }
        if lower.contains("daily") { return "calendar" }
        return "circle.grid.2x2"
    }

    private func sectionLabel(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 14, weight: .semibold))
            }
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Presets

    private struct Preset { let label: String; let start: Date; let end: Date }
    private var presets: [Preset] {
        return [
            Preset(label: "3d", start: StatsDateRange.lastComplete(days: 3).start, end: StatsDateRange.lastComplete(days: 3).end),
            Preset(label: "7d", start: StatsDateRange.lastComplete(days: 7).start, end: StatsDateRange.lastComplete(days: 7).end),
            Preset(label: "14d", start: StatsDateRange.lastComplete(days: 14).start, end: StatsDateRange.lastComplete(days: 14).end),
            Preset(label: "30d", start: StatsDateRange.lastComplete(days: 30).start, end: StatsDateRange.lastComplete(days: 30).end),
            Preset(label: "90d", start: StatsDateRange.lastComplete(days: 90).start, end: StatsDateRange.lastComplete(days: 90).end),
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
            if !s.targetLow.isEmpty && !s.targetHigh.isEmpty {
                targetGlucose = "\(s.targetLow)–\(s.targetHigh)"
            } else {
                targetGlucose = s.targetLow.isEmpty ? s.targetHigh : s.targetLow
            }
            units = s.units
            fetchSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                fetchSuccess = false
            }
        }
    }

    // MARK: - Generate

    private func generate() {
        errorMessage = nil
        isGenerating = true

        // Strict boundary generation so we capture all 24 hours of start and end days
        let cal = Calendar.current
        let realStart = cal.startOfDay(for: startDate)
        var endComps = DateComponents()
        endComps.day = 1
        endComps.second = -1
        let realEnd = cal.date(byAdding: endComps, to: cal.startOfDay(for: endDate)) ?? endDate

        dataService.updateDateRange(start: realStart, end: realEnd)

        dataService.ensureDataAvailable(onProgress: {}) {
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let config = EndoReportConfig(
                        patientName: patientName,
                        dateOfBirth: dateOfBirth,
                        diagnosisDate: diagnosisDate,
                        providerName: providerName,
                        insulinType: insulinType,
                        aidSystem: aidSystem == "Other" ? customAidSystem : aidSystem,
                        pumpDevice: pumpDevice,
                        cgmDevice: cgmDevice,
                        carbRatio: carbRatio,
                        isf: isf,
                        basalRate: basalRate,
                        targetGlucose: targetGlucose,
                        units: units,
                        accentColorHex: accentColorHex,
                        notes: notes,
                        includeGlucoseSummary: includeGlucoseSummary,
                        includeInsulin: includeInsulin,
                        includeNutrition: includeNutrition,
                        includeTherapySettings: includeTherapySettings,
                        includeDevices: includeDevices,
                        includeAGP: includeAGP,
                        includeDailyBreakdown: includeDailyBreakdown,
                        includeFatProtein: includeFatProtein,
                        startDate: realStart,
                        endDate: realEnd
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

                    func fmtValue(_ value: Double) -> String {
                        if value == floor(value) {
                            return String(format: "%.0f", value)
                        }
                        let raw = String(format: "%.2f", value)
                        return raw.replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
                    }

                    func fmtSchedule<T>(_ entries: [T],
                                        value: (T) -> Double,
                                        time: (T) -> String) -> String
                    {
                        if entries.count == 1 {
                            return fmtValue(value(entries[0]))
                        }
                        // Output joined by newlines so it populates the multi-line UI cleanly
                        return entries.map {
                            "\(time($0)) = \(fmtValue(value($0)))"
                        }.joined(separator: "\n")
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
