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

            let bundleDisplayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "LoopFollow"
            let contactName = "\(bundleDisplayName) - BG"
            let predicate = CNContact.predicateForContacts(matchingName: contactName)
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
                    newContact.givenName = contactName
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

        UIColor.black.setFill()
        context.fill(CGRect(origin: .zero, size: size))

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let maxFontSize: CGFloat = extra.isEmpty ? 200 : 160
        let fontSize = maxFontSize - CGFloat(bgValue.count * 10)

        var bgAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: fontSize),
            .foregroundColor: stale ? UIColor.gray : UIColor.white,
            .paragraphStyle: paragraphStyle
        ]

        if stale {
            bgAttributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }

        let extraAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 90),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]

        let bgRect = extra.isEmpty
        ? CGRect(x: 0, y: 46, width: size.width, height: size.height - 80)
        : CGRect(x: 0, y: 26, width: size.width, height: size.height / 2)

        bgValue.draw(in: bgRect, withAttributes: bgAttributes)

        if !extra.isEmpty {
            let extraRect = CGRect(x: 0, y: size.height / 2 + 6, width: size.width, height: size.height / 2 - 20)
            extra.draw(in: extraRect, withAttributes: extraAttributes)
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
