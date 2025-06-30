// LoopFollow
// ObservationToken.swift
// Created by Jon Fawcett.

import Foundation

/// The token received by an observe when subscribes to its subject. The observer can cancel observation, so the subject will remove it from its observers list.
class ObservationToken {
    private let cancellationClosure: () -> Void

    init(cancellationClosure: @escaping () -> Void) {
        self.cancellationClosure = cancellationClosure
    }

    func cancel() {
        cancellationClosure()
    }
}
