import SwiftUI
import AVFoundation

struct QRCodeScannerView: UIViewControllerRepresentable {
    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: QRCodeScannerView
        
        init(parent: QRCodeScannerView) {
            self.parent = parent
        }
        
        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first {
                guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
                guard let stringValue = readableObject.stringValue else { return }
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                parent.didFindCode(stringValue)
            }
        }
    }
    
    var didFindCode: (String) -> Void
    var isScanningEnabled: Bool
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        
        let captureSession = AVCaptureSession()
        
        // Set up the camera input
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return viewController }
        let videoDeviceInput: AVCaptureDeviceInput
        
        do {
            videoDeviceInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return viewController
        }
        
        if (captureSession.canAddInput(videoDeviceInput)) {
            captureSession.addInput(videoDeviceInput)
        } else {
            return viewController
        }
        
        // Set up metadata output (QR code)
        let metadataOutput = AVCaptureMetadataOutput()
        
        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)
            
            // Set the delegate to handle QR code scanning
            metadataOutput.setMetadataObjectsDelegate(context.coordinator, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            return viewController
        }
        
        // Create a preview layer for the camera
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = viewController.view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        viewController.view.layer.addSublayer(previewLayer)
        
        // Store the session for later control
        context.coordinator.captureSession = captureSession
        
        // Start running the session on a background thread
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Enable/disable scanning based on the `isScanningEnabled` flag
        if !isScanningEnabled {
            // Stop scanning
            DispatchQueue.global(qos: .userInitiated).async {
                context.coordinator.captureSession?.stopRunning()
            }
        } else {
            // Restart scanning
            if !(context.coordinator.captureSession?.isRunning ?? false) {
                DispatchQueue.global(qos: .userInitiated).async {
                    context.coordinator.captureSession?.startRunning()
                }
            }
        }
    }
}

extension QRCodeScannerView.Coordinator {
    var captureSession: AVCaptureSession? {
        get {
            return objc_getAssociatedObject(self, &captureSessionKey) as? AVCaptureSession
        }
        set {
            objc_setAssociatedObject(self, &captureSessionKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

private var captureSessionKey: UInt8 = 0
