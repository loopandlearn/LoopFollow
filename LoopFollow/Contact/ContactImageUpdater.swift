// LoopFollow
// ContactImageUpdater.swift

import Contacts
import Foundation
import UIKit

class ContactImageUpdater {
    private let contactStore = CNContactStore()
    private let queue = DispatchQueue(label: "ContactImageUpdaterQueue")

    private var savedBackgroundUIColor: UIColor {
        let rawValue = Storage.shared.contactBackgroundColor.value
        return ContactColorOption(rawValue: rawValue)?.uiColor ?? .black
    }

    private var savedTextUIColor: UIColor {
        let rawValue = Storage.shared.contactTextColor.value
        return ContactColorOption(rawValue: rawValue)?.uiColor ?? .white
    }

    func updateContactImage(bgValue: String, trend: String, delta: String, iob: String, stale: Bool) {
        queue.async {
            guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
                LogManager.shared.log(category: .contact, message: "Access to contacts is not authorized.")
                return
            }

            let bundleDisplayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "LoopFollow"

            for contactType in ContactType.allCases {
                if contactType == .Delta, Storage.shared.contactDelta.value != .separate {
                    continue
                }

                if contactType == .Trend, Storage.shared.contactTrend.value != .separate {
                    continue
                }

                if contactType == .IOB, Storage.shared.contactIOB.value != .separate {
                    continue
                }

                let contactName = "\(bundleDisplayName) - \(contactType.rawValue)"

                let includedFields = self.getIncludedFields(for: contactType)

                guard let imageData = self.generateContactImage(bgValue: bgValue, trend: trend, delta: delta, iob: iob, stale: stale, contactType: contactType, includedFields: includedFields)?.pngData() else {
                    LogManager.shared.log(category: .contact, message: "Failed to generate contact image for \(contactName).")
                    continue
                }

                do {
                    let keysToFetch = [
                        CNContactIdentifierKey as CNKeyDescriptor,
                        CNContactGivenNameKey as CNKeyDescriptor,
                        CNContactImageDataKey as CNKeyDescriptor,
                    ]

                    var allMatchingContacts: [CNContact] = []
                    let containers = try self.contactStore.containers(matching: nil)

                    // Run fast check first
                    let namePredicate = CNContact.predicateForContacts(matchingName: contactName)
                    let nameContacts = try self.contactStore.unifiedContacts(matching: namePredicate, keysToFetch: keysToFetch)
                    let matchingNameContacts = nameContacts.filter { $0.givenName == contactName }
                    allMatchingContacts.append(contentsOf: matchingNameContacts)

                    // If it fails, make heavy iteration by containers
                    if allMatchingContacts.isEmpty {
                        for container in containers {
                            let containerPredicate = CNContact.predicateForContactsInContainer(withIdentifier: container.identifier)
                            let containerContacts = try self.contactStore.unifiedContacts(matching: containerPredicate, keysToFetch: keysToFetch)
                            let matchingContacts = containerContacts.filter { $0.givenName == contactName }
                            for contact in matchingContacts {
                                if !allMatchingContacts.contains(where: { $0.identifier == contact.identifier }) {
                                    allMatchingContacts.append(contact)
                                }
                            }
                        }
                    }

                    let saveRequest = CNSaveRequest()

                    if let existingContact = allMatchingContacts.first {
                        if let mutableContact = existingContact.mutableCopy() as? CNMutableContact {
                            mutableContact.imageData = imageData
                            saveRequest.update(mutableContact)
                            try self.contactStore.execute(saveRequest)
                            LogManager.shared.log(category: .contact, message: "Contact image updated successfully for \(contactName).")
                        }
                    } else {
                        // Use default container
                        let defaultContainer = self.contactStore.defaultContainerIdentifier()
                        let newContact = CNMutableContact()
                        newContact.givenName = contactName
                        newContact.imageData = imageData
                        saveRequest.add(newContact, toContainerWithIdentifier: defaultContainer)
                        try self.contactStore.execute(saveRequest)
                        LogManager.shared.log(category: .contact, message: "New contact created with updated image for \(contactName).")
                    }
                } catch {
                    LogManager.shared.log(category: .contact, message: "Failed to update or create contact for \(contactName): \(error)")
                }
            }
        }
    }

    private func getIncludedFields(for contactType: ContactType) -> [ContactType] {
        var included: [ContactType] = []
        if Storage.shared.contactTrend.value == .include,
           Storage.shared.contactTrendTarget.value == contactType {
            included.append(.Trend)
        }
        if Storage.shared.contactDelta.value == .include,
           Storage.shared.contactDeltaTarget.value == contactType {
            included.append(.Delta)
        }
        if Storage.shared.contactIOB.value == .include,
           Storage.shared.contactIOBTarget.value == contactType {
            included.append(.IOB)
        }
        return included
    }

    private func generateContactImage(bgValue: String, trend: String, delta: String, iob: String, stale: Bool, contactType: ContactType, includedFields: [ContactType]) -> UIImage? {
        let size = CGSize(width: 300, height: 300)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        savedBackgroundUIColor.setFill()
        context.fill(CGRect(origin: .zero, size: size))

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let yOffset: CGFloat = 48

        // Get the primary value for this contact type
        let primaryValue: String
        switch contactType {
        case .BG: primaryValue = bgValue
        case .Trend: primaryValue = trend
        case .Delta: primaryValue = delta
        case .IOB: primaryValue = iob
        }

        // Build extra values from included fields
        var extraValues: [String] = []
        for field in includedFields {
            switch field {
            case .Trend: extraValues.append(trend)
            case .Delta: extraValues.append(delta)
            case .IOB: extraValues.append(iob)
            case .BG: break
            }
        }

        let hasExtras = !extraValues.isEmpty

        // Determine font sizes based on number of extras
        let maxFontSize: CGFloat = extraValues.count >= 2 ? 140 : (hasExtras ? 160 : 200)
        let extraFontSize: CGFloat = extraValues.count >= 2 ? 60 : 90

        let fontSize = max(40, maxFontSize - CGFloat(primaryValue.count * 15))

        var primaryAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: fontSize),
            .foregroundColor: stale ? UIColor.gray : savedTextUIColor,
            .paragraphStyle: paragraphStyle,
        ]

        if stale {
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            primaryAttributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }

        let primaryRect: CGRect = hasExtras
            ? CGRect(x: 0, y: yOffset - 20, width: size.width, height: size.height / 2)
            : CGRect(x: 0, y: yOffset, width: size.width, height: size.height - 80)

        primaryValue.draw(in: primaryRect, withAttributes: primaryAttributes)

        if hasExtras {
            let extraString = extraValues.joined(separator: " ")
            let extraRect = CGRect(x: 0, y: size.height / 2 + 6, width: size.width, height: size.height / 2 - 20)
            let extraAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: extraFontSize),
                .foregroundColor: stale ? UIColor.gray : savedTextUIColor,
                .paragraphStyle: paragraphStyle,
            ]
            extraString.draw(in: extraRect, withAttributes: extraAttributes)
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
