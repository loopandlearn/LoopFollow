// LoopFollow
// AboutView.swift

import SwiftUI

struct AboutView: View {
    @State private var latestVersion: String?
    @State private var versionTint: Color = .secondary

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image("AppIcon")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .cornerRadius(16)

                        Text("LoopFollow")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Monitor blood glucose remotely")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            }

            buildInfoSection
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshVersionInfo() }
    }

    @ViewBuilder
    private var buildInfoSection: some View {
        let build = BuildDetails.default
        let ver = AppVersionManager().version()

        Section {
            keyValue("Version", ver, tint: versionTint)
            keyValue("Latest Version", latestVersion ?? "Fetching...")

            if !(build.isMacApp() || build.isSimulatorBuild()) {
                keyValue(build.expirationHeaderString,
                         dateTimeUtils.formattedDate(from: build.calculateExpirationDate()))
            }
            keyValue("Built",
                     dateTimeUtils.formattedDate(from: build.buildDate()))
            keyValue("Branch", build.branchAndSha)
        } header: {
            Label("Build Information", systemImage: "hammer")
        }
    }

    private func keyValue(_ key: String,
                          _ value: String,
                          tint: Color = .secondary) -> some View
    {
        HStack {
            Text(key)
            Spacer()
            Text(value)
                .foregroundStyle(tint)
        }
    }

    private func refreshVersionInfo() async {
        let mgr = AppVersionManager()
        let (latest, newer, blacklisted) = await mgr.checkForNewVersionAsync()
        latestVersion = latest ?? "Unknown"

        let current = mgr.version()
        versionTint = blacklisted ? .red
            : newer ? .orange
            : latest == current ? .green
            : .secondary
    }
}

#Preview {
    AboutView()
}
