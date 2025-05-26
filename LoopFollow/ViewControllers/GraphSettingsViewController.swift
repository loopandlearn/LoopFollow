// LoopFollow
// GraphSettingsViewController.swift
// Created by Jose Paredes on 2020-07-17.

import Eureka
import EventKit
import EventKitUI
import Foundation

class GraphSettingsViewController: FormViewController {
    var appStateController: AppStateController?

    override func viewDidLoad() {
        super.viewDidLoad()
        if Storage.shared.forceDarkMode.value {
            overrideUserInterfaceStyle = .dark
        }

        buildGraphSettings()

        showHideNSDetails()
    }

    func showHideNSDetails() {
        var isHidden = false
        var isEnabled = true
        if !IsNightscoutEnabled() {
            isHidden = true
            isEnabled = false
        }

        if let row1 = form.rowBy(tag: "predictionToLoad") as? StepperRow {
            row1.hidden = .function(["hide"]) { _ in
                isHidden
            }
            row1.evaluateHidden()
        }
        if let row2 = form.rowBy(tag: "smallGraphTreatments") as? SwitchRow {
            row2.hidden = .function(["hide"]) { _ in
                isHidden
            }
            row2.evaluateHidden()
        }
        if let row3 = form.rowBy(tag: "minBasalScale") as? StepperRow {
            row3.hidden = .function(["hide"]) { _ in
                isHidden
            }
            row3.evaluateHidden()
        }

        if let row4 = form.rowBy(tag: "showValues") as? SwitchRow {
            row4.hidden = .function(["hide"]) { _ in
                isHidden
            }
            row4.evaluateHidden()
        }
        if let row5 = form.rowBy(tag: "showAbsorption") as? SwitchRow {
            row5.hidden = .function(["hide"]) { _ in
                isHidden
            }
            row5.evaluateHidden()
        }
    }

    private func buildGraphSettings() {
        form
            +++ Section("Graph Settings")

            <<< SwitchRow("switchRowDots") { row in
                row.title = "Display Dots"
                row.value = UserDefaultsRepository.showDots.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.showDots.value = value
                // Force main screen update
                // guard let mainScreen = self?.tabBarController!.viewControllers?[0] as? MainViewController else { return }
                // mainScreen.updateBGGraphSettings()

                // tell main screen that grap needs updating
                if let appState = self!.appStateController {
                    appState.chartSettingsChanged = true
                    appState.chartSettingsChanges |= ChartSettingsChangeEnum.showDotsChanged.rawValue
                }
            }
            <<< SwitchRow("switchRowLines") { row in
                row.title = "Display Lines"
                row.value = UserDefaultsRepository.showLines.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.showLines.value = value
                // Force main screen update
                // guard let mainScreen = self?.tabBarController!.viewControllers?[0] as? MainViewController else { return }
                // mainScreen.updateBGGraphSettings()

                if let appState = self!.appStateController {
                    appState.chartSettingsChanged = true
                    appState.chartSettingsChanges |= ChartSettingsChangeEnum.showLinesChanged.rawValue
                }
            }
            <<< SwitchRow("showValues") { row in
                row.title = "Show Carb/Bolus Values"
                row.value = UserDefaultsRepository.showValues.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.showValues.value = value
            }
            <<< SwitchRow("showAbsorption") { row in
                row.title = "Show Carb Absorption"
                row.value = UserDefaultsRepository.showAbsorption.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.showAbsorption.value = value
            }
            <<< SwitchRow("showDIAMarkers") { row in
                row.title = "Show DIA Lines"
                row.value = UserDefaultsRepository.showDIALines.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.showDIALines.value = value

                // tell main screen that graph needs updating
                if let appState = self!.appStateController {
                    appState.chartSettingsChanged = true
                    appState.chartSettingsChanges |= ChartSettingsChangeEnum.showDIALinesChanged.rawValue
                }
            }
            <<< SwitchRow("show30MinLine") { row in
                row.title = "Show -30 min line"
                row.value = UserDefaultsRepository.show30MinLine.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.show30MinLine.value = value

                // Tell the main screen that graph needs updating
                if let appState = self!.appStateController {
                    appState.chartSettingsChanged = true
                    appState.chartSettingsChanges |= ChartSettingsChangeEnum.show30MinLineChanged.rawValue
                }
            }
            <<< SwitchRow("show90MinLine") { row in
                row.title = "Show -90 min line"
                row.value = UserDefaultsRepository.show90MinLine.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.show90MinLine.value = value

                // Tell the main screen that graph needs updating
                if let appState = self!.appStateController {
                    appState.chartSettingsChanged = true
                    appState.chartSettingsChanges |= ChartSettingsChangeEnum.show90MinLineChanged.rawValue
                }
            }
            <<< SwitchRow("smallGraphTreatments") { row in
                row.title = "Treatments on Small Graph"
                row.value = UserDefaultsRepository.smallGraphTreatments.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.smallGraphTreatments.value = value
            }
            <<< StepperRow("smallGraphHeight") { row in
                row.title = "Small Graph Height"
                row.cell.stepper.stepValue = 5
                row.cell.stepper.minimumValue = 40
                row.cell.stepper.maximumValue = 80
                row.value = Double(UserDefaultsRepository.smallGraphHeight.value)
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.smallGraphHeight.value = Int(value)

                if let appState = self!.appStateController {
                    appState.chartSettingsChanged = true
                    appState.chartSettingsChanges |= ChartSettingsChangeEnum.smallGraphHeight.rawValue
                }
            }
            <<< StepperRow("predictionToLoad") { row in
                row.title = "Hours of Prediction"
                row.cell.stepper.stepValue = 0.25
                row.cell.stepper.minimumValue = 0.0
                row.cell.stepper.maximumValue = 6.0
                row.value = Double(UserDefaultsRepository.predictionToLoad.value)
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.predictionToLoad.value = value
            }
            <<< StepperRow("minBGScale") { row in
                row.title = "Min BG Scale"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = Double(UserDefaultsRepository.highLine.value)
                row.cell.stepper.maximumValue = 400
                row.value = Double(UserDefaultsRepository.minBGScale.value)
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return Localizer.toDisplayUnits(String(value))
                }
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.minBGScale.value = Float(value)
            }

            <<< StepperRow("minBasalScale") { row in
                row.title = "Min Basal Scale"
                row.cell.stepper.stepValue = 0.5
                row.cell.stepper.minimumValue = 0.5
                row.cell.stepper.maximumValue = 20
                row.value = Double(UserDefaultsRepository.minBasalScale.value)
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.minBasalScale.value = value
            }
            <<< StepperRow("lowLine") { row in
                row.title = "Low BG Display Value"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 40
                row.cell.stepper.maximumValue = 120
                row.value = Double(UserDefaultsRepository.lowLine.value)
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return Localizer.toDisplayUnits(String(value))
                }
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.lowLine.value = Float(value)
                // Force main screen update
                // guard let mainScreen = self?.tabBarController!.viewControllers?[0] as? MainViewController else { return }
                // mainScreen.updateBGGraphSettings()

                // tell main screen to update
                if let appState = self!.appStateController {
                    appState.chartSettingsChanged = true
                    appState.chartSettingsChanges |= ChartSettingsChangeEnum.lowLineChanged.rawValue
                }
            }
            <<< StepperRow("highLine") { row in
                row.title = "High BG Display Value"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 120
                row.cell.stepper.maximumValue = 400
                row.value = Double(UserDefaultsRepository.highLine.value)
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return Localizer.toDisplayUnits(String(value))
                }
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.highLine.value = Float(value)
                // Force main screen update
                // guard let mainScreen = self?.tabBarController!.viewControllers?[0] as? MainViewController else { return }
                // mainScreen.updateBGGraphSettings()

                // let app state know of the change
                if let appState = self!.appStateController {
                    appState.chartSettingsChanged = true
                    appState.chartSettingsChanges |= ChartSettingsChangeEnum.highLineChanged.rawValue
                }
            }
            <<< StepperRow("downloadDays") { row in
                // NS supports up to 4 days
                row.title = "Show Days Back"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 1
                row.cell.stepper.maximumValue = 4
                row.value = Double(UserDefaultsRepository.downloadDays.value)
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.downloadDays.value = Int(value)
            }
            <<< SwitchRow("showMidnightMarkers") { row in
                row.title = "Show Midnight Lines"
                row.value = UserDefaultsRepository.showMidnightLines.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.showMidnightLines.value = value

                // tell main screen that graph needs updating
                if let appState = self!.appStateController {
                    appState.chartSettingsChanged = true
                    appState.chartSettingsChanges |= ChartSettingsChangeEnum.showMidnightLinesChanged.rawValue
                }
            }

            +++ ButtonRow {
                $0.title = "DONE"
            }.onCellSelection { _, _ in
                self.dismiss(animated: true, completion: nil)
            }
    }
}
