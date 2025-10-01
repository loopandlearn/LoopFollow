// LoopFollow
// QRCodeGenerator.swift

import CoreImage
import UIKit

enum QRCodeGenerator {
    /// Generates a QR code image from a string
    /// - Parameters:
    ///   - string: The string to encode in the QR code
    ///   - size: The size of the generated image (default: 200x200)
    ///   - correctionLevel: The error correction level (default: .M)
    /// - Returns: A UIImage containing the QR code, or nil if generation fails
    static func generateQRCode(
        from string: String,
        size: CGSize = CGSize(width: 200, height: 200),
        correctionLevel: String = "M"
    ) -> UIImage? {
        // Create a CIFilter for QR code generation
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }

        // Set the input data (the string to encode)
        let data = string.data(using: .utf8)
        filter.setValue(data, forKey: "inputMessage")

        // Set the error correction level
        filter.setValue(correctionLevel, forKey: "inputCorrectionLevel")

        // Get the output image
        guard let outputImage = filter.outputImage else {
            return nil
        }

        // Scale the image to the desired size
        let scaleX = size.width / outputImage.extent.size.width
        let scaleY = size.height / outputImage.extent.size.height
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        // Convert CIImage to UIImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    /// Generates a QR code image with custom colors
    /// - Parameters:
    ///   - string: The string to encode in the QR code
    ///   - size: The size of the generated image (default: 200x200)
    ///   - foregroundColor: The color of the QR code (default: black)
    ///   - backgroundColor: The background color (default: white)
    ///   - correctionLevel: The error correction level (default: .M)
    /// - Returns: A UIImage containing the QR code, or nil if generation fails
    static func generateQRCode(
        from string: String,
        size: CGSize = CGSize(width: 200, height: 200),
        foregroundColor: UIColor = .black,
        backgroundColor: UIColor = .white,
        correctionLevel: String = "M"
    ) -> UIImage? {
        // First generate the basic QR code
        guard let qrCodeImage = generateQRCode(from: string, size: size, correctionLevel: correctionLevel) else {
            return nil
        }

        // Create a new image context with the desired size
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }

        // Fill the background
        backgroundColor.setFill()
        context.fill(CGRect(origin: .zero, size: size))

        // Draw the QR code with the foreground color
        context.setFillColor(foregroundColor.cgColor)
        context.setBlendMode(.sourceIn)

        // Create a mask from the original QR code
        if let cgImage = qrCodeImage.cgImage {
            let maskImage = UIImage(cgImage: cgImage)
            maskImage.draw(in: CGRect(origin: .zero, size: size))
        }

        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
