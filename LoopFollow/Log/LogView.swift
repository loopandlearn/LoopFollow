// LoopFollow
// LogView.swift
// Created by Jonas Björkert.

import SwiftUI

struct LogView: View {
    @ObservedObject var viewModel = LogViewModel()

    var body: some View {
        NavigationView {
            VStack {
                Picker("Category", selection: $viewModel.selectedCategory) {
                    Text("All").tag(LogManager.Category?.none)
                    ForEach(LogManager.Category.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(LogManager.Category?.some(category))
                    }
                }
                .pickerStyle(MenuPickerStyle())

                SearchBar(text: $viewModel.searchText)
                    .padding([.leading, .trailing])

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(viewModel.filteredLogEntries) { entry in
                            Text(entry.text)
                                .font(.system(size: 12, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 0)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .onAppear {
                viewModel.loadLogEntries()
            }
        }
        .preferredColorScheme(Storage.shared.forceDarkMode.value ? .dark : nil)
        .navigationBarTitle("Today's Logs", displayMode: .inline)
    }
}
