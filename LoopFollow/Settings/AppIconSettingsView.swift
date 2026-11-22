// LoopFollow
// AppIconSettingsView.swift

import SwiftUI
import UIKit

enum AppIconOption: String, CaseIterable, Identifiable {
    case classic = "Classic"
    case pink = "Pink"
    case lavender = "Lavender"
    case mint = "Mint"
    case midnight = "Midnight"
    case spring = "Spring"
    case summer = "Summer"
    case autumn = "Autumn"
    case winter = "Winter"

    var id: String {
        rawValue
    }

    var displayName: String {
        rawValue
    }

    /// Name of the alternate icon set in the asset catalog; `nil` for the primary icon.
    var alternateIconName: String? {
        self == .classic ? nil : "AppIcon-\(rawValue)"
    }

    var previewImageName: String {
        "AppIconPreview-\(rawValue)"
    }

    init(alternateIconName: String?) {
        self = Self.allCases.first { $0.alternateIconName == alternateIconName } ?? .classic
    }
}

final class AppIconManager: ObservableObject {
    static let shared = AppIconManager()

    @Published private(set) var current = AppIconOption(alternateIconName: UIApplication.shared.alternateIconName)

    var isSupported: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    func select(_ option: AppIconOption) {
        guard option != current else { return }
        let previous = current
        current = option
        UIApplication.shared.setAlternateIconName(option.alternateIconName) { error in
            guard let error else { return }
            LogManager.shared.log(category: .general, message: "Failed to change app icon: \(error.localizedDescription)")
            DispatchQueue.main.async { self.current = previous }
        }
    }
}

struct AppIconImage: View {
    let option: AppIconOption
    let size: CGFloat

    var body: some View {
        Image(option.previewImageName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
    }
}

struct AppIconSettingsView: View {
    @ObservedObject private var manager = AppIconManager.shared

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    AppIconImage(option: manager.current, size: 110)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    Text(manager.current.displayName)
                        .font(.headline)
                }
                .padding(.top, 12)

                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(AppIconOption.allCases) { option in
                        iconCell(option)
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("The icon on the Home Screen changes right away and iOS shows a short confirmation. The Apple Watch app keeps the classic icon.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
        .navigationBarTitle("App Icon", displayMode: .inline)
    }

    private func iconCell(_ option: AppIconOption) -> some View {
        let selected = option == manager.current
        return Button {
            manager.select(option)
        } label: {
            VStack(spacing: 8) {
                AppIconImage(option: option, size: 72)
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 3)
                    )
                    .overlay(alignment: .topTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.accentColor)
                                .offset(x: 6, y: -6)
                        }
                    }
                Text(option.displayName)
                    .font(.footnote)
                    .fontWeight(selected ? .semibold : .regular)
                    .foregroundStyle(selected ? Color.primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.displayName)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
