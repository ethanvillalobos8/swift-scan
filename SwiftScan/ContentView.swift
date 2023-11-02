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

struct BarcodeStatusView: View {
    let message: String
    let backgroundColor: Color

    var body: some View {
        Text(message)
            .font(.headline)
            .padding()
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(10)
            .shadow(radius: 5)
    }
}

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
                        .navigationBarTitle("PDF Files")
                    } else {
                        ZStack {
                            CameraView(camera: camera)
                            
                            VStack {
                                if let barcode = camera.detectedBarcode, let pdf = selectedPDF, let pdfText = extractTextFromPDF(pdf) {
                                    if pdfText.contains(barcode) {
                                        BarcodeStatusView(message: "Barcode found in the PDF!", backgroundColor: .green)
                                    } else {
                                        BarcodeStatusView(message: "Barcode not found in the PDF.", backgroundColor: .red)
                                    }
                                }
                                else if let barcode = camera.detectedBarcode, selectedPDF == nil {
                                    BarcodeStatusView(message: "Select a PDF", backgroundColor: .clear)
                                }
                                Spacer()
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
                
                let boxWidth: CGFloat = geometry.size.width * 0.6
                let boxHeight: CGFloat = geometry.size.height * 0.3
                
                InvertedMaskView(width: boxWidth, height: boxHeight)
                    .fill(Color.black.opacity(0.4), style: FillStyle(eoFill: true))
                    .ignoresSafeArea()
            }
        }
        .onAppear(perform: {
            camera.Check()
        })
    }
}

struct InvertedMaskView: Shape {
    var width: CGFloat
    var height: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Rectangle().path(in: rect)
        path.addPath(RoundedRectangle(cornerRadius: 20).path(in: CGRect(x: (rect.width - width) / 2, y: (rect.height - height) / 2, width: width, height: height)))
        return path
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
