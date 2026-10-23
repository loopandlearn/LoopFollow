// LoopFollow
// StatusIntents.swift

import AppIntents

struct GetStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Status"
    static var description = IntentDescription("Reads out the latest glucose, trend, IOB, COB and loop status that LoopFollow has received.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let input = try IntentDataSource.readoutInput()
        let text = StatusReadoutFormatter.fullReadout(input)
        return .result(value: text, dialog: IntentDialog("\(text)"))
    }
}

struct GetGlucoseIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Glucose"
    static var description = IntentDescription("Reads out the latest glucose reading and returns it as a number in your display unit, for use in Shortcuts automations.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Double> {
        let input = try IntentDataSource.readoutInput()
        guard let snapshot = input.snapshot, let text = StatusReadoutFormatter.glucoseLine(input) else {
            throw LoopFollowIntentError.noGlucoseData
        }
        let value = StatusReadoutFormatter.displayValue(snapshot.glucose, unit: snapshot.unit)
        return .result(value: value, dialog: IntentDialog("\(text)"))
    }
}

struct GetStatusItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Status Item"
    static var description = IntentDescription("Reads out one value, such as IOB, pump reservoir, sensor age or last loop time.")

    @Parameter(title: "Item")
    var item: StatusItem

    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$item)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let input = try IntentDataSource.readoutInput()
        let text = StatusReadoutFormatter.text(for: item.field, input)
        return .result(value: text, dialog: IntentDialog("\(text)"))
    }
}
