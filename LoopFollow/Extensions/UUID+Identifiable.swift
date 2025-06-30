// LoopFollow
// UUID+Identifiable.swift
// Created by Jonas Björkert.

import Foundation

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}
