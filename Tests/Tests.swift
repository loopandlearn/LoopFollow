// LoopFollow
// Tests.swift

@testable import LoopFollow
import SwiftUI
import Testing

struct TreatmentDetailRequestTests {
    @Test("matches only the requested supported treatment kind")
    func matchesSupportedKind() {
        let request = TreatmentDetailRequest(kind: .carb, timestamp: 1000, amount: 20)
        let treatments = [
            treatment(id: "bolus", type: .bolusManual, date: 1000, title: "1.00 U"),
            treatment(id: "carb", type: .carb, date: 1001, title: "20g"),
        ]

        #expect(request.bestMatch(in: treatments)?.id == "carb")
    }

    @Test("automatic graph boluses match automatic or SMB details")
    func matchesAutomaticBolusVariants() {
        let request = TreatmentDetailRequest(kind: .automaticBolus, timestamp: 2000, amount: 0.8)
        let treatments = [
            treatment(id: "automatic", type: .bolusAutomatic, date: 2000, title: "0.50 U"),
            treatment(id: "unparseable", type: .bolusAutomatic, date: 2000, title: "Unknown"),
            treatment(id: "smb", type: .smb, date: 2000, title: "0.80 U"),
        ]

        #expect(request.bestMatch(in: treatments)?.id == "smb")

        let trioGraphRequest = TreatmentDetailRequest(kind: .bolus, timestamp: 2000, amount: 0.8)
        let trioCandidates = [
            treatment(id: "manual", type: .bolusManual, date: 2000, title: "0.50 U"),
            treatment(id: "trio-smb", type: .bolusAutomatic, date: 2030, title: "0.80 U"),
        ]
        #expect(trioGraphRequest.bestMatch(in: trioCandidates)?.id == "trio-smb")
    }

    @Test("rejects unsupported types and treatments outside the time tolerance")
    func rejectsUnsupportedOrDistantTreatments() {
        let request = TreatmentDetailRequest(kind: .bolus, timestamp: 3000, amount: 1)
        let treatments = [
            treatment(id: "basal", type: .tempBasal, date: 3000, title: "1.00 U/hr"),
            treatment(
                id: "distant",
                type: .bolusManual,
                date: 3000 + TreatmentDetailRequest.matchTolerance + 1,
                title: "1.00 U"
            ),
        ]

        #expect(request.bestMatch(in: treatments) == nil)
    }

    @Test("matches override and temp target detail types")
    func matchesBandTreatmentTypes() {
        let overrideRequest = TreatmentDetailRequest(kind: .override, timestamp: 4000, amount: nil)
        let targetRequest = TreatmentDetailRequest(kind: .tempTarget, timestamp: 5000, amount: nil)
        let treatments = [
            treatment(id: "override", type: .override, date: 4000, title: "Workout"),
            treatment(id: "target", type: .tempTarget, date: 5000, title: "100 mg/dL"),
        ]

        #expect(overrideRequest.bestMatch(in: treatments)?.id == "override")
        #expect(targetRequest.bestMatch(in: treatments)?.id == "target")
    }

    private func treatment(
        id: String,
        type: TreatmentType,
        date: TimeInterval,
        title: String
    ) -> Treatment {
        Treatment(
            id: id,
            type: type,
            date: date,
            title: title,
            subtitle: nil,
            icon: "circle.fill",
            color: .blue,
            bgValue: 0
        )
    }
}
