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

                guard let imageData = self.generateContactImage(bgValue: bgValue, trend: trend, delta: delta, iob: iob, stale: stale, contactType: contactType)?.pngData() else {
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

    private func generateContactImage(bgValue: String, trend: String, delta: String, iob: String, stale: Bool, contactType: ContactType) -> UIImage? {
        let size = CGSize(width: 300, height: 300)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        savedBackgroundUIColor.setFill()
        context.fill(CGRect(origin: .zero, size: size))

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        // Format extraDelta based on the user's unit preference
        let unitPreference = Storage.shared.units.value
        let yOffset: CGFloat = 48
        if contactType == .Trend, Storage.shared.contactTrend.value == .separate {
            let trendRect = CGRect(x: 0, y: 46, width: size.width, height: size.height - 80)
            let trendFontSize = max(40, 200 - CGFloat(trend.count * 15))

            let trendAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: trendFontSize),
                .foregroundColor: stale ? UIColor.gray : savedTextUIColor,
                .paragraphStyle: paragraphStyle,
            ]

            trend.draw(in: trendRect, withAttributes: trendAttributes)
        } else if contactType == .Delta, Storage.shared.contactDelta.value == .separate {
            let deltaRect = CGRect(x: 0, y: yOffset, width: size.width, height: size.height - 80)
            let deltaFontSize = max(40, 200 - CGFloat(delta.count * 15))

            let deltaAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: deltaFontSize),
                .foregroundColor: stale ? UIColor.gray : savedTextUIColor,
                .paragraphStyle: paragraphStyle,
            ]

            delta.draw(in: deltaRect, withAttributes: deltaAttributes)
        } else if contactType == .IOB, Storage.shared.contactIOB.value == .separate {
            let iobRect = CGRect(x: 0, y: yOffset, width: size.width, height: size.height - 80)
            let iobFontSize = max(40, 200 - CGFloat(iob.count * 15))

            let iobAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: iobFontSize),
                .foregroundColor: stale ? UIColor.gray : savedTextUIColor,
                .paragraphStyle: paragraphStyle,
            ]

            iob.draw(in: iobRect, withAttributes: iobAttributes)
        } else if contactType == .BG {
            let includesExtra = Storage.shared.contactDelta.value == .include || Storage.shared.contactTrend.value == .include || Storage.shared.contactIOB.value == .include

            let maxFontSize: CGFloat = includesExtra ? 160 : 200
            let fontSize = maxFontSize - CGFloat(bgValue.count * 15)
            var bgAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: stale ? UIColor.gray : savedTextUIColor,
                .paragraphStyle: paragraphStyle,
            ]

            if stale {
                // Force background color back to black if stale
                UIColor.black.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                bgAttributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            }

            let bgRect: CGRect = includesExtra
                ? CGRect(x: 0, y: yOffset - 20, width: size.width, height: size.height / 2)
                : CGRect(x: 0, y: yOffset, width: size.width, height: size.height - 80)

            bgValue.draw(in: bgRect, withAttributes: bgAttributes)

            if includesExtra {
                let extraRect = CGRect(x: 0, y: size.height / 2 + 6, width: size.width, height: size.height / 2 - 20)
                let extraAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 90),
                    .foregroundColor: stale ? UIColor.gray : savedTextUIColor,
                    .paragraphStyle: paragraphStyle,
                ]

                let extra: String
                if Storage.shared.contactDelta.value == .include {
                    extra = delta
                } else if Storage.shared.contactTrend.value == .include {
                    extra = trend
                } else {
                    extra = iob
                }
                extra.draw(in: extraRect, withAttributes: extraAttributes)
            }
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
