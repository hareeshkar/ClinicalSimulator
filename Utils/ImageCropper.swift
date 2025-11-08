//
//  ImageCropper.swift
//  ClinicalSimulator
//
//  Created by Hareeshkar Ravi on 11/7/25.
//

import SwiftUI
import Mantis

struct ImageCropper: UIViewControllerRepresentable {
    @Binding var image: UIImage? // ✅ This now receives tempImageForCropping binding
    @Environment(\.dismiss) var dismiss
    
    // ✅ NEW: Callback for when cropping is complete
    var onCropComplete: ((UIImage) -> Void)?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        var config = Mantis.Config()
        config.cropShapeType = .circle() // Force a circular crop for profile pictures
        let cropViewController = Mantis.cropViewController(image: image ?? UIImage(), config: config)
        cropViewController.delegate = context.coordinator
        return cropViewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    class Coordinator: NSObject, CropViewControllerDelegate {
        var parent: ImageCropper
        
        init(_ parent: ImageCropper) {
            self.parent = parent
        }
        
        func cropViewControllerDidCrop(_ cropViewController: CropViewController, cropped: UIImage, transformation: Transformation, cropInfo: CropInfo) {
            // ✅ FIX: Use the callback if provided, otherwise fallback
            if let onComplete = parent.onCropComplete {
                onComplete(cropped)
            } else {
                parent.image = cropped
            }
            parent.dismiss()
        }
        
        func cropViewControllerDidCancel(_ cropViewController: CropViewController, original: UIImage) {
            parent.dismiss()
        }
        
        func cropViewControllerDidFailToCrop(_ cropViewController: CropViewController, original: UIImage) {
            parent.dismiss()
        }
        
        func cropViewControllerDidBeginResize(_ cropViewController: CropViewController) {
            // Optional method - no action needed
        }
        
        func cropViewControllerDidEndResize(_ cropViewController: CropViewController, original: UIImage, cropInfo: CropInfo) {
            // Optional method - no action needed
        }
    }
}
