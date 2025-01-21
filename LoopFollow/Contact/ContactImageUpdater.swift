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

    //convert the saved strings to UI Color
        private var savedBackgroundUIColor: UIColor {
            switch ObservableUserDefaults.shared.contactBackgroundColor.value {
            case "red": return .red
            case "blue": return .blue
            case "cyan": return .cyan
            case "green": return .green
            case "yellow": return .yellow
            case "orange": return .orange
            case "purple": return .purple
            case "white": return .white
            case "black": return .black    
            default: return .black
            }
        }
    
        private var savedTextUIColor: UIColor {
            switch ObservableUserDefaults.shared.contactTextColor.value {
            case "red": return .red
            case "blue": return .blue
            case "cyan": return .cyan
            case "green": return .green
            case "yellow": return .yellow
            case "orange": return .orange
            case "purple": return .purple
            case "white": return .white
            case "black": return .black
            default: return .white
            }
        }

        func updateContactImage(bgValue: String, extra: String, extraTrend: String, extraDelta: String, stale: Bool) {
        let contactSuffixes = ["- BG", "- Trend", "- Delta"]
        queue.async {
            guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
                print("Access to contacts is not authorized.")
                return
            }
    
            let bundleDisplayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "LoopFollow"
    
            for suffix in contactSuffixes {
                let contactName = "\(bundleDisplayName) \(suffix)"
                let contactType = suffix.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "-", with: "")
                guard let imageData = self.generateContactImage(bgValue: bgValue, extra: extra, extraTrend: extraTrend, extraDelta: extraDelta, stale: stale, contactType: contactType)?.pngData() else {
                    print("Failed to generate contact image for \(contactName).")
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
                    print("Failed to update or create contact for \(contactName): \(error)")
                }
            }
        }
    }

    private func generateContactImage(bgValue: String, extra: String, extraTrend: String, extraDelta: String, stale: Bool, contactType: String) -> UIImage? {
    let size = CGSize(width: 300, height: 300)
    UIGraphicsBeginImageContextWithOptions(size, false, 0)
    guard let context = UIGraphicsGetCurrentContext() else { return nil }

    savedBackgroundUIColor.setFill()
    context.fill(CGRect(origin: .zero, size: size))

    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center

    let maxFontSize: CGFloat = extra.isEmpty ? 200 : 160
    let fontSize = maxFontSize - CGFloat(bgValue.count * 15)
    var bgAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.boldSystemFont(ofSize: fontSize),
        .foregroundColor: stale ? UIColor.gray : savedTextUIColor,
        .paragraphStyle: paragraphStyle
    ]

    if stale {
        // Force background color back to black if stale
        UIColor.black.setFill()
        context.fill(CGRect(origin: .zero, size: size))
        bgAttributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
    }

    let extraAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 90),
        .foregroundColor: stale ? UIColor.gray : savedTextUIColor,
        .paragraphStyle: paragraphStyle
    ]

    if contactType == "Trend" && ObservableUserDefaults.shared.contactTrend.value == "Separate" {
        // Customizing image for Trend contact when value is Separate
        let trendRect = CGRect(x: 0, y: 46, width: size.width, height: size.height - 80)
        extraTrend.draw(in: trendRect, withAttributes: extraAttributes)
    } else if contactType == "Delta" && ObservableUserDefaults.shared.contactDelta.value == "Separate" {
        // Customizing image for Delta contact when value is Separate
        let deltaRect = CGRect(x: 0, y: 46, width: size.width, height: size.height - 80)
        extraDelta.draw(in: deltaRect, withAttributes: extraAttributes)
    } else if contactType == "BG" {
        // Customizing image for BG contact
        let bgRect = extra.isEmpty
            ? CGRect(x: 0, y: 46, width: size.width, height: size.height - 80)
            : CGRect(x: 0, y: 26, width: size.width, height: size.height / 2)

        bgValue.draw(in: bgRect, withAttributes: bgAttributes)

        if !extra.isEmpty {
            let extraRect = CGRect(x: 0, y: size.height / 2 + 6, width: size.width, height: size.height / 2 - 20)
            extra.draw(in: extraRect, withAttributes: extraAttributes)
        }
    }

    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image
}
}
