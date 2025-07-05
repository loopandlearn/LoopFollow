// LoopFollow
// ContactImageUpdater.swift
// Created by Jonas Björkert.

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

    func updateContactImage(bgValue: String, trend: String, delta: String, stale: Bool) {
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

                let contactName = "\(bundleDisplayName) - \(contactType.rawValue)"

                guard let imageData = self.generateContactImage(bgValue: bgValue, trend: trend, delta: delta, stale: stale, contactType: contactType)?.pngData() else {
                    LogManager.shared.log(category: .contact, message: "Failed to generate contact image for \(contactName).")
                    continue
                }

                let predicate = CNContact.predicateForContacts(matchingName: contactName)
                let keysToFetch = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactImageDataKey] as [CNKeyDescriptor]

                do {
                    let contacts = try self.contactStore.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)

                    if let contact = contacts.first, let mutableContact = contact.mutableCopy() as? CNMutableContact {
                        mutableContact.imageData = imageData
                        let saveRequest = CNSaveRequest()
                        saveRequest.update(mutableContact)
                        try self.contactStore.execute(saveRequest)
                        print("Contact image updated successfully for \(contactName).")
                    } else {
                        let newContact = CNMutableContact()
                        newContact.givenName = contactName
                        newContact.imageData = imageData
                        let saveRequest = CNSaveRequest()
                        saveRequest.add(newContact, toContainerWithIdentifier: nil)
                        try self.contactStore.execute(saveRequest)
                        print("New contact created with updated image for \(contactName).")
                    }
                } catch {
                    LogManager.shared.log(category: .contact, message: "Failed to update or create contact for \(contactName): \(error)")
                }
            }
        }
    }

    private func generateContactImage(bgValue: String, trend: String, delta: String, stale: Bool, contactType: ContactType) -> UIImage? {
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
        } else if contactType == .BG {
            let includesExtra = Storage.shared.contactDelta.value == .include || Storage.shared.contactTrend.value == .include

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

                let extra = Storage.shared.contactDelta.value == .include ? delta : trend
                extra.draw(in: extraRect, withAttributes: extraAttributes)
            }
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
