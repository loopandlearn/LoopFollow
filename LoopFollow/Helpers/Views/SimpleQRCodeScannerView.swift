// LoopFollow
// SimpleQRCodeScannerView.swift

import AVFoundation
import SwiftUI
import UIKit

struct SimpleQRCodeScannerView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    var completion: (Result<String, Error>) -> Void

    func makeUIViewController(context _: Context) -> UINavigationController {
        let scannerVC = SimpleQRCodeScannerViewController { result in
            completion(result)
        }

        let navController = UINavigationController(rootViewController: scannerVC)

        // Apply appearance mode
        let style = Storage.shared.appearanceMode.value.userInterfaceStyle
        scannerVC.overrideUserInterfaceStyle = style
        navController.overrideUserInterfaceStyle = style

        return navController
    }

    func updateUIViewController(_: UINavigationController, context _: Context) {}
}

class SimpleQRCodeScannerViewController: UIViewController {
    private var session: AVCaptureSession?
    private var completion: (Result<String, Error>) -> Void

    init(completion: @escaping (Result<String, Error>) -> Void) {
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Add cancel button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationItem.title = "Scan QR Code"

        setupCamera()
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        self.session = session

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              session.canAddInput(videoInput)
        else {
            let error = NSError(domain: "QRCodeScannerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to set up camera input."])
            completion(.failure(error))
            return
        }

        session.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            let error = NSError(domain: "QRCodeScannerError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to set up metadata output."])
            completion(.failure(error))
            return
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    @objc private func cancelTapped() {
        DispatchQueue.global(qos: .userInitiated).async {
            if let session = self.session, session.isRunning {
                session.stopRunning()
            }
        }
        let error = NSError(domain: "QRCodeScannerError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Scanning cancelled by user."])
        completion(.failure(error))
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let previewLayer = view.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = view.layer.bounds
        }
    }
}

extension SimpleQRCodeScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from _: AVCaptureConnection) {
        if let session, session.isRunning {
            if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
               metadataObject.type == .qr,
               let stringValue = metadataObject.stringValue
            {
                DispatchQueue.global(qos: .userInitiated).async {
                    session.stopRunning()
                }
                completion(.success(stringValue))
            }
        }
    }
}
