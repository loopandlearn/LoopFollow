//
//  ContactImageUpdater.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-12-10.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation
import Contacts
import UIKit

class ContactImageUpdater {
    private let contactStore = CNContactStore()
    private let queue = DispatchQueue(label: "ContactImageUpdaterQueue")

    func updateContactImage(bgValue: String, extra: String, stale: Bool) {
        queue.async {
            guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
                print("Access to contacts is not authorized.")
                return
            }

            guard let imageData = self.generateContactImage(bgValue: bgValue, extra: extra, stale: stale)?.pngData() else {
                print("Failed to generate contact image.")
                return
            }

            let predicate = CNContact.predicateForContacts(matchingName: "LoopFollowBG")
            let keysToFetch = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactImageDataKey] as [CNKeyDescriptor]

            do {
                let contacts = try self.contactStore.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)

                if let contact = contacts.first, let mutableContact = contact.mutableCopy() as? CNMutableContact {
                    mutableContact.imageData = imageData
                    let saveRequest = CNSaveRequest()
                    saveRequest.update(mutableContact)
                    try self.contactStore.execute(saveRequest)
                    print("Contact image updated successfully.")
                } else {
                    let newContact = CNMutableContact()
                    newContact.givenName = "LoopFollowBG"
                    newContact.imageData = imageData
                    let saveRequest = CNSaveRequest()
                    saveRequest.add(newContact, toContainerWithIdentifier: nil)
                    try self.contactStore.execute(saveRequest)
                    print("New contact created with updated image.")
                }
            } catch {
                print("Failed to update or create contact: \(error)")
            }
        }
    }

    private func generateContactImage(bgValue: String, extra: String, stale: Bool) -> UIImage? {
        let size = CGSize(width: 300, height: 300)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        UIColor.systemBackground.setFill()
        context.fill(CGRect(origin: .zero, size: size))

        let bgText = bgValue
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        // Attributes for bgValue
        var bgAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: extra.isEmpty ? 140 : 100), // Larger font if no extra text
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ]

        if stale {
            bgAttributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }

        let bgRect = extra.isEmpty
        ? CGRect(x: 0, y: 80, width: size.width, height: 140) // Center bgValue vertically if no extra
        : CGRect(x: 0, y: 60, width: size.width, height: 100)

        bgText.draw(in: bgRect, withAttributes: bgAttributes)

        // Draw extra text if not empty
        if !extra.isEmpty {
            let trendAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 50),
                .foregroundColor: UIColor.secondaryLabel,
                .paragraphStyle: paragraphStyle
            ]
            let extraRect = CGRect(x: 0, y: 170, width: size.width, height: 50)
            extra.draw(in: extraRect, withAttributes: trendAttributes)
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
