//
//  BLEDevice.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-01-02.
//

import Foundation

struct BLEDevice: Identifiable, Codable, Equatable {
    let id: UUID

    var name: String?
    var rssi: Int
    var isConnected: Bool
    var advertisedServices: [String]?
    var lastSeen: Date
    var lastConnected: Date?

    init(id: UUID,
         name: String? = nil,
         rssi: Int,
         isConnected: Bool = false,
         advertisedServices: [String]? = nil,
         lastSeen: Date = Date(),
         lastConnected: Date? = nil) {
        self.id = id
        self.name = name
        self.rssi = rssi
        self.isConnected = isConnected
        self.advertisedServices = advertisedServices
        self.lastSeen = lastSeen
        self.lastConnected = lastConnected
    }

    func updateLastSeen() -> BLEDevice {
        var updatedDevice = self
        updatedDevice.lastSeen = Date()
        return updatedDevice
    }

    func updateLastConnected() -> BLEDevice {
        var updatedDevice = self
        updatedDevice.lastConnected = Date()
        updatedDevice.isConnected = true
        return updatedDevice
    }
}
