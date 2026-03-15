// LoopFollow
// DataAvailabilityView.swift

import SwiftUI

struct DataAvailabilityView: View {
    let availability: DataAvailabilityInfo
    var compact: Bool = false

    var body: some View {
        if compact {
            compactView
        } else {
            fullView
        }
    }

    private var compactView: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.caption)
                .foregroundColor(statusColor)

            Text(availability.displayText)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(availability.dataQuality.description)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(backgroundColor.opacity(0.5))
        .cornerRadius(8)
    }

    private var fullView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Data Availability")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(availability.displayText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(availability.dataQuality.description)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(statusColor)

                    if availability.missingIntervals > 0 {
                        Text("\(availability.missingIntervals) gaps")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(backgroundColor)
            .cornerRadius(12)
        }
    }

    private var statusIcon: String {
        switch availability.dataQuality {
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

    private var statusColor: Color {
        switch availability.dataQuality {
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

    private var backgroundColor: Color {
        switch availability.dataQuality {
        case .excellent:
            return Color.green.opacity(0.1)
        case .good:
            return Color.blue.opacity(0.1)
        case .fair:
            return Color.orange.opacity(0.1)
        case .poor:
            return Color.red.opacity(0.1)
        }
    }
}
