//
//  PDFListModel.swift
//  SwiftScan
//
//  Created by Ethan Villalobos on 10/27/23.
//

import Foundation
import FirebaseStorage

class PDFListModel: ObservableObject {
    @Published var pdfFiles: [URL] = []
    private let storage = Storage.storage().reference()
    
    init() {
        fetchPDFs()
    }
    
    func fetchPDFs() {
        // Assuming you have a folder called 'pdfs' in Firebase Storage
        storage.child("pdfs").listAll { (result, error) in
            if let error = error {
                print("Error fetching PDFs: \(error)")
                return
            }
            
            guard let items = result?.items else {
                print("No items found in Firebase Storage.")
                return
            }

            for item in items {
                item.downloadURL { (url, error) in
                    if let error = error {
                        print("Error getting download URL: \(error)")
                        return
                    }
                    
                    if let url = url {
                        DispatchQueue.main.async {
                            self.pdfFiles.append(url)
                        }
                    }
                }
            }
        }
    }

}
