//
//  ContentView.swift
//  SwiftScan
//
//  Created by Ethan Villalobos on 10/27/23.
//

import SwiftUI
import AVFoundation
import PDFKit
import FirebaseStorage

struct ContentView: View {
    @StateObject var camera = CameraModel()
    @State private var showSidebar: Bool = false
    @State private var selectedPDF: URL?
    @EnvironmentObject var pdfListModel: PDFListModel

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    if showSidebar {
                        List {
                            ForEach(pdfListModel.pdfFiles, id: \.self) { pdf in
                                Text(pdf.lastPathComponent)
                                    .onTapGesture {
                                        self.selectedPDF = pdf
                                    }
                                    .listRowBackground(pdf == selectedPDF ? Color.blue : Color(UIColor.systemGray6))
                            }
                        }
                        .navigationBarItems(leading: EditButton())
                        .navigationBarTitle("PDF Files")
                    } else {
                        ZStack {
                            CameraView(camera: camera)
                            if let barcode = camera.detectedBarcode, let pdf = selectedPDF, let pdfText = extractTextFromPDF(pdf) {
                                if pdfText.contains(barcode) {
                                    Text("Barcode found in the PDF!")
                                        .background(Color.green)
                                        .foregroundColor(.white)
                                        .padding()
                                } else {
                                    Text("Barcode not found in the PDF.")
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .padding()
                                }
                            }
                        }
                    }
                }
                .background(Color.black)
            }
            .navigationBarItems(leading: Button(action: {
                withAnimation {
                    self.showSidebar.toggle()
                }
            }) { Image(systemName: "list.dash") })
        }
    }

    func extractTextFromPDF(_ pdfURL: URL) -> String? {
        if let pdfDocument = PDFDocument(url: pdfURL) {
            return pdfDocument.string
        }
        return nil
    }
}

struct CameraView: View {
    @ObservedObject var camera: CameraModel
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CameraPreview(camera: camera)
                    .ignoresSafeArea(.all, edges: .all)
                
                // Define the fixed box size
                let boxWidth: CGFloat = geometry.size.width * 0.6
                let boxHeight: CGFloat = geometry.size.height * 0.3
                let centeredBox = CGRect(
                    x: geometry.frame(in: .local).midX - boxWidth / 2,
                    y: geometry.frame(in: .local).midY - boxHeight / 2,
                    width: boxWidth,
                    height: boxHeight
                )
                
                BoundingBoxCorners(boundingBox: centeredBox)
                            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
            }
        }
        .onAppear(perform: {
            camera.Check()
        })
    }
}

struct BoundingBoxCorners: View {
    var boundingBox: CGRect
    var cornerLength: CGFloat = 20.0
    var lineWidth: CGFloat = 2.0

    var body: some View {
        ZStack {
            // Top-left corner
            Path { path in
                path.move(to: CGPoint(x: boundingBox.minX, y: boundingBox.minY))
                path.addLine(to: CGPoint(x: boundingBox.minX + cornerLength, y: boundingBox.minY))
                path.move(to: CGPoint(x: boundingBox.minX, y: boundingBox.minY))
                path.addLine(to: CGPoint(x: boundingBox.minX, y: boundingBox.minY + cornerLength))
            }
            .stroke(Color.yellow, lineWidth: lineWidth)

            // Top-right corner
            Path { path in
                path.move(to: CGPoint(x: boundingBox.maxX, y: boundingBox.minY))
                path.addLine(to: CGPoint(x: boundingBox.maxX - cornerLength, y: boundingBox.minY))
                path.move(to: CGPoint(x: boundingBox.maxX, y: boundingBox.minY))
                path.addLine(to: CGPoint(x: boundingBox.maxX, y: boundingBox.minY + cornerLength))
            }
            .stroke(Color.yellow, lineWidth: lineWidth)

            // Bottom-left corner
            Path { path in
                path.move(to: CGPoint(x: boundingBox.minX, y: boundingBox.maxY))
                path.addLine(to: CGPoint(x: boundingBox.minX + cornerLength, y: boundingBox.maxY))
                path.move(to: CGPoint(x: boundingBox.minX, y: boundingBox.maxY))
                path.addLine(to: CGPoint(x: boundingBox.minX, y: boundingBox.maxY - cornerLength))
            }
            .stroke(Color.yellow, lineWidth: lineWidth)

            // Bottom-right corner
            Path { path in
                path.move(to: CGPoint(x: boundingBox.maxX, y: boundingBox.maxY))
                path.addLine(to: CGPoint(x: boundingBox.maxX - cornerLength, y: boundingBox.maxY))
                path.move(to: CGPoint(x: boundingBox.maxX, y: boundingBox.maxY))
                path.addLine(to: CGPoint(x: boundingBox.maxX, y: boundingBox.maxY - cornerLength))
            }
            .stroke(Color.yellow, lineWidth: lineWidth)
        }
    }
}

class CameraModel: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published var session = AVCaptureSession()
    @Published var detectedBarcode: String?
    
    func Check() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setUp()
            return
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { (status) in
                if status {
                    self.setUp()
                }
            }
        case .denied:
            return
        default:
            return
        }
    }

    func setUp() {
        do {
            self.session.beginConfiguration()
            let device = AVCaptureDevice.default(for: .video)
            let input = try AVCaptureDeviceInput(device: device!)

            if (self.session.canAddInput(input)) {
                self.session.addInput(input)
            }

            let metadataOutput = AVCaptureMetadataOutput()
            if (self.session.canAddOutput(metadataOutput)) {
                self.session.addOutput(metadataOutput)

                metadataOutput.metadataObjectTypes = [
                    .qr,
                    .ean8,
                    .ean13,
                    .upce,
                    .code39,
                    .code128
                ]
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            }

            self.session.commitConfiguration()
        } catch {
            print(error.localizedDescription)
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject {
            print("Detected barcode: \(metadataObject.stringValue ?? "")")
            detectedBarcode = metadataObject.stringValue
            
            // Haptic feedback
            let feedbackGenerator = UINotificationFeedbackGenerator()
            feedbackGenerator.notificationOccurred(.success)
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera: CameraModel

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: camera.session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        camera.session.startRunning()
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
