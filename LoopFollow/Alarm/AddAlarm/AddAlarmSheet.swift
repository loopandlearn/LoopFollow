// LoopFollow
// AddAlarmSheet.swift

import SwiftUI

struct AddAlarmSheet: View {
    let onSelect: (AlarmType) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    private let columns = [
        GridItem(.adaptive(minimum: 110), spacing: 16),
    ]

    private func matches(_ type: AlarmType) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return type.rawValue.localizedCaseInsensitiveContains(query)
            || type.blurb.localizedCaseInsensitiveContains(query)
            || type.group.rawValue.localizedCaseInsensitiveContains(query)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(AlarmType.Group.allCases, id: \.self) { group in
                        let types = AlarmType.allCases.filter { $0.group == group && matches($0) }
                        if !types.isEmpty {
                            Section(header: Text(group.rawValue)
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                            ) {
                                ForEach(types, id: \.self) { type in
                                    AlarmTile(type: type) {
                                        onSelect(type)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()

                if !AlarmType.allCases.contains(where: matches) {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No Results")
                            .font(.headline)
                        Text("No alarms match “\(searchText)”.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Add Alarm")
            .searchable(text: $searchText, prompt: "Search alarms")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
    }
}
