// LoopFollow
// SimpleQRCodeScannerView.swift
// Created by codebymini.

import AVFoundation
import SwiftUI

struct SimpleQRCodeScannerView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    var completion: (Result<String, Error>) -> Void

    // MARK: - Coordinator

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: SimpleQRCodeScannerView
        var session: AVCaptureSession?

        init(parent: SimpleQRCodeScannerView) {
            self.parent = parent
        }

        func metadataOutput(_: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from _: AVCaptureConnection) {
            if let session, session.isRunning {
                if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                   metadataObject.type == .qr,
                   let stringValue = metadataObject.stringValue
                {
                    DispatchQueue.global(qos: .userInitiated).async {
                        session.stopRunning()
                    }
                    parent.completion(.success(stringValue))
                }
            }
        }
    }

    // MARK: - UIViewControllerRepresentable Methods

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        let session = AVCaptureSession()
        context.coordinator.session = session // Assign session to coordinator

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              session.canAddInput(videoInput)
        else {
            let error = NSError(domain: "QRCodeScannerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to set up camera input."])
            completion(.failure(error))
            return controller
        }

        session.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(context.coordinator, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            let error = NSError(domain: "QRCodeScannerError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to set up metadata output."])
            completion(.failure(error))
            return controller
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = controller.view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        controller.view.layer.addSublayer(previewLayer)

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        return controller
    }

    func updateUIViewController(_: UIViewController, context _: Context) {}

    func dismantleUIViewController(_: UIViewController, coordinator: Coordinator) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let session = coordinator.session, session.isRunning {
                session.stopRunning()
            }
        }
    }
}
