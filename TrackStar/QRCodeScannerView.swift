import SwiftUI
import AVFoundation

struct QRCodeScannerView: UIViewControllerRepresentable {
    
    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: QRCodeScannerView
        var isScanInProgress = false // Track whether a scan is already in progress
        
        init(parent: QRCodeScannerView) {
            self.parent = parent
        }
        
        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard let metadataObject = metadataObjects.first else { return }
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            // Prevent multiple scans from happening if scan is in progress
            if !isScanInProgress {
                isScanInProgress = true
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                print("FOUND QRCODE")
                self.parent.didFindCode(stringValue)
                
                // Debounce the scan (reset after a short delay)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.isScanInProgress = false
                }
            }
        }
    }
    
    var didFindCode: (String) -> Void
    @Binding var isScanningEnabled: Bool
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        
        let captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            return viewController
        }
        
        let videoDeviceInput: AVCaptureDeviceInput
        do {
            videoDeviceInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return viewController
        }
        
        if captureSession.canAddInput(videoDeviceInput) {
            captureSession.addInput(videoDeviceInput)
        } else {
            return viewController
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(context.coordinator, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            return viewController
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = viewController.view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        viewController.view.layer.addSublayer(previewLayer)
        
        // Start running the session on a background thread for performance
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }
        
        // Watch the isScanningEnabled flag and stop the session if scanning is disabled
        context.coordinator.isScanInProgress = !isScanningEnabled
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let previewLayer = uiViewController.view.layer.sublayers?.first as? AVCaptureVideoPreviewLayer else {
            return
        }
        
        if isScanningEnabled {
            // Start the session if it's not running
            if previewLayer.session?.isRunning == false {
                DispatchQueue.global(qos: .userInitiated).async {
                    previewLayer.session?.startRunning()
                }
            }
        } else {
            // Stop the session when scanning is disabled
            if previewLayer.session?.isRunning == true {
                DispatchQueue.global(qos: .userInitiated).async {
                    previewLayer.session?.stopRunning()
                }
            }
        }
    }
}
