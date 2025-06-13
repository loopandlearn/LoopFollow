// LoopFollow
// TreatmentResponse.swift
// Created by Jonas Björkert on 2024-07-28.

import Foundation

struct TreatmentResponse: Decodable {
    let enteredBy: String
    let eventType: String
    let reason: String
    let targetTop: Double
    let targetBottom: Double
    let duration: Int
    let createdAt: String
    let utcOffset: Int
    let id: String

    enum CodingKeys: String, CodingKey {
        case enteredBy
        case eventType
        case reason
        case targetTop
        case targetBottom
        case duration
        case createdAt = "created_at"
        case utcOffset
        case id = "_id"
    }
}

struct TreatmentCancelResponse: Decodable {
    let enteredBy: String
    let eventType: String
    let reason: String
    let duration: Int
    let createdAt: String
    let utcOffset: Int
    let id: String

    enum CodingKeys: String, CodingKey {
        case enteredBy
        case eventType
        case reason
        case duration
        case createdAt = "created_at"
        case utcOffset
        case id = "_id"
    }
}
