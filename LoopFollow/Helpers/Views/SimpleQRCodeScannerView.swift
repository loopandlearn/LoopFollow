// LoopFollow
// SimpleQRCodeScannerView.swift
// Created by codebymini

import AVFoundation
import SwiftUI

struct SimpleQRCodeScannerView: UIViewControllerRepresentable {
    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: SimpleQRCodeScannerView

        init(parent: SimpleQRCodeScannerView) {
            self.parent = parent
        }

        func metadataOutput(_: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from _: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
               metadataObject.type == .qr,
               let stringValue = metadataObject.stringValue
            {
                parent.completion(.success(stringValue))
                parent.presentationMode.wrappedValue.dismiss()
            }
        }
    }

    @Environment(\.presentationMode) var presentationMode
    var completion: (Result<String, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        let session = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return controller }
        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else { return controller }
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        }

        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(context.coordinator, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = controller.view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        controller.view.layer.addSublayer(previewLayer)

        session.startRunning()
        return controller
    }

    func updateUIViewController(_: UIViewController, context _: Context) {}
}
