// LoopFollow
// DataSourceChoiceStepView.swift

import SwiftUI

struct DataSourceChoiceStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                OnboardingStepHeader(
                    systemImage: "antenna.radiowaves.left.and.right",
                    title: "Choose a data source",
                    subtitle: "LoopFollow needs a glucose data source. Pick one now — you can change or add more later in Settings."
                )
                .padding(.horizontal)

                VStack(spacing: 14) {
                    choiceCard(
                        source: .nightscout,
                        icon: "globe",
                        title: "Nightscout",
                        detail: "Follow a Nightscout site. Works with Loop, Trio, and most uploaders. Enables the full set of LoopFollow features."
                    )
                    choiceCard(
                        source: .dexcom,
                        icon: "sensor.tag.radiowaves.forward.fill",
                        title: "Dexcom Share",
                        detail: "Follow glucose directly from a Dexcom Share account, without a Nightscout site."
                    )
                    choiceCard(
                        source: .copyFromPhone,
                        icon: "qrcode",
                        title: "Copy from another phone",
                        detail: "Already using LoopFollow on another phone? Scan its QR code to copy the connection here."
                    )
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
    }

    private func choiceCard(source: OnboardingViewModel.DataSource, icon: String, title: String, detail: String) -> some View {
        let isSelected = viewModel.dataSource == source
        return Button {
            viewModel.dataSource = source
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color(.systemGray3))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
