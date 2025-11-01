// LoopFollow
// QRCodeDisplayView.swift

import SwiftUI
import UIKit

struct QRCodeDisplayView: View {
    let qrCodeString: String
    let size: CGSize
    let foregroundColor: UIColor
    let backgroundColor: UIColor

    @State private var qrCodeImage: UIImage?

    init(
        qrCodeString: String,
        size: CGSize = CGSize(width: 250, height: 250),
        foregroundColor: UIColor = .black,
        backgroundColor: UIColor = .white
    ) {
        self.qrCodeString = qrCodeString
        self.size = size
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        VStack(spacing: 16) {
            if let qrCodeImage = qrCodeImage {
                Image(uiImage: qrCodeImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
                    .cornerRadius(12)
                    .shadow(radius: 4)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: size.width, height: size.height)
                    .overlay(
                        ProgressView()
                            .scaleEffect(1.5)
                    )
            }
        }
        .onAppear {
            generateQRCode()
        }
    }

    private func generateQRCode() {
        DispatchQueue.global(qos: .userInitiated).async {
            let image = QRCodeGenerator.generateQRCode(
                from: qrCodeString,
                size: size,
                foregroundColor: foregroundColor,
                backgroundColor: backgroundColor
            )

            DispatchQueue.main.async {
                self.qrCodeImage = image
            }
        }
    }
}

#Preview {
    QRCodeDisplayView(qrCodeString: "https://example.com/test")
        .padding()
}
