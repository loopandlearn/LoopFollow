// LoopFollow
// DateRangePicker.swift

import SwiftUI

struct DateRangePicker: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    var availability: DataAvailabilityInfo?
    var onDateChange: () -> Void

    @State private var isExpanded = false
    @State private var showStartDatePicker = false
    @State private var showEndDatePicker = false

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    private var compactDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }

    private var dayCount: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }

    private var lastFullDay: Date {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .second, value: -1, to: startOfToday) ?? Date()
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                    showStartDatePicker = false
                    showEndDatePicker = false
                }
            }) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(compactDateFormatter.string(from: startDate)) - \(compactDateFormatter.string(from: endDate))")
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        Text("(\(dayCount) days)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if let availability = availability {
                        HStack(spacing: 4) {
                            Image(systemName: statusIcon(for: availability.dataQuality))
                                .font(.caption)
                                .foregroundColor(statusColor(for: availability.dataQuality))

                            Text(String(format: "%.0f%%", availability.coveragePercentage))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(statusColor(for: availability.dataQuality))
                        }
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.secondary.opacity(0.1))

            if isExpanded {
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Start Date")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button(action: {
                                showStartDatePicker.toggle()
                                showEndDatePicker = false
                            }) {
                                HStack {
                                    Image(systemName: "calendar")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text(dateFormatter.string(from: startDate))
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(6)
                            }
                        }

                        Spacer()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("End Date")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button(action: {
                                showEndDatePicker.toggle()
                                showStartDatePicker = false
                            }) {
                                HStack {
                                    Image(systemName: "calendar")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text(dateFormatter.string(from: endDate))
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(6)
                            }
                        }
                    }
                    .padding(.top, 8)

                    if showStartDatePicker {
                        DatePicker(
                            "Select Start Date",
                            selection: $startDate,
                            in: ...endDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
                        .onChange(of: startDate) { _ in
                            startDate = Calendar.current.startOfDay(for: startDate)
                            showStartDatePicker = false
                            onDateChange()
                        }
                    }

                    if showEndDatePicker {
                        DatePicker(
                            "Select End Date",
                            selection: $endDate,
                            in: startDate ... lastFullDay,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
                        .onChange(of: endDate) { _ in
                            let calendar = Calendar.current
                            let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
                            endDate = calendar.date(byAdding: .second, value: -1, to: startOfNextDay) ?? endDate
                            showEndDatePicker = false
                            onDateChange()
                        }
                    }

                    Divider()

                    HStack(spacing: 8) {
                        QuickSelectButton(title: "7d") {
                            setDateRange(days: 7)
                        }
                        QuickSelectButton(title: "14d") {
                            setDateRange(days: 14)
                        }
                        QuickSelectButton(title: "30d") {
                            setDateRange(days: 30)
                        }
                        QuickSelectButton(title: "90d") {
                            setDateRange(days: 90)
                        }
                    }

                    if let availability = availability {
                        VStack(spacing: 6) {
                            HStack {
                                Text("Data Availability")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Spacer()

                                Text(String(format: "%.1f%%", availability.coveragePercentage))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(statusColor(for: availability.dataQuality))
                            }

                            HStack {
                                Text("\(availability.actualReadings) of \(availability.totalExpectedReadings) expected readings")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                if availability.missingIntervals > 0 {
                                    Text("\(availability.missingIntervals) gaps")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }

                            Text("Expected: 1 CGM reading every 5 minutes")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .background(Color.secondary.opacity(0.05))
            }
        }
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }

    private func setDateRange(days: Int) {
        let calendar = Calendar.current
        endDate = lastFullDay
        let endDayStart = calendar.startOfDay(for: endDate)
        let startDayStart = calendar.date(byAdding: .day, value: -days, to: endDayStart) ?? endDayStart
        startDate = calendar.startOfDay(for: startDayStart)
        showStartDatePicker = false
        showEndDatePicker = false
        onDateChange()
    }

    private func statusIcon(for quality: DataAvailabilityInfo.DataQuality) -> String {
        switch quality {
        case .excellent:
            return "checkmark.circle.fill"
        case .good:
            return "checkmark.circle"
        case .fair:
            return "exclamationmark.triangle"
        case .poor:
            return "xmark.circle"
        }
    }

    private func statusColor(for quality: DataAvailabilityInfo.DataQuality) -> Color {
        switch quality {
        case .excellent:
            return .green
        case .good:
            return .blue
        case .fair:
            return .orange
        case .poor:
            return .red
        }
    }
}

struct QuickSelectButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(6)
        }
    }
}
