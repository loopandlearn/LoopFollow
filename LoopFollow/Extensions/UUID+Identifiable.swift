// LoopFollow
// UUID+Identifiable.swift
// Created by Jonas Björkert on 2025-04-26.

import Foundation

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}
