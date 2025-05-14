//
//  LogViewModel.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-01-13.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Combine
import Foundation

class LogViewModel: ObservableObject {
    @Published var allLogEntries: [LogEntry] = []
    @Published var filteredLogEntries: [LogEntry] = []
    @Published var selectedCategory: LogManager.Category? = nil
    @Published var searchText: String = ""

    private var cancellables = Set<AnyCancellable>()

    init() {
        Publishers.CombineLatest($selectedCategory, $searchText)
            .sink { [weak self] category, search in
                self?.filterLogs(category: category, searchText: search)
            }
            .store(in: &cancellables)

        loadLogEntries()

        Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.loadLogEntries()
            }
            .store(in: &cancellables)
    }

    func loadLogEntries() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            let logManager = LogManager.shared
            let logFileURL = logManager.currentLogFileURL

            guard FileManager.default.fileExists(atPath: logFileURL.path) else {
                DispatchQueue.main.async {
                    self.allLogEntries = []
                    self.filteredLogEntries = []
                }
                return
            }

            do {
                let logContent = try String(contentsOf: logFileURL, encoding: .utf8)
                var logLines = logContent.components(separatedBy: .newlines)
                logLines = logLines.filter { !$0.isEmpty }

                // Reverse the log lines to have newest first
                logLines.reverse()

                let uniqueLogEntries = logLines.map { LogEntry(id: UUID(), text: $0) }

                DispatchQueue.main.async {
                    self.allLogEntries = uniqueLogEntries
                    self.filterLogs(category: self.selectedCategory, searchText: self.searchText)
                }
            } catch {
                print("Error reading log file: \(error)")
                DispatchQueue.main.async {
                    self.allLogEntries = []
                    self.filteredLogEntries = []
                }
            }
        }
    }

    private func filterLogs(category: LogManager.Category?, searchText: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var filtered = self.allLogEntries

            // Filter by category and remove category tag
            if let category = category {
                let categoryTag = "[\(category.rawValue)] "
                filtered = filtered.filter { $0.text.contains(categoryTag) }
                    .map { logEntry in
                        var text = logEntry.text
                        if let range = text.range(of: categoryTag) {
                            text.removeSubrange(range)
                        }
                        return LogEntry(id: logEntry.id, text: text.trimmingCharacters(in: .whitespaces))
                    }
            }

            // Filter by search text
            if !searchText.isEmpty {
                filtered = filtered.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
            }

            DispatchQueue.main.async {
                self.filteredLogEntries = filtered
            }
        }
    }
}
