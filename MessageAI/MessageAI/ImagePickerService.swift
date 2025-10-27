//
//  ImagePickerService.swift
//  MessageAI
//
//  Image picker service using PHPickerViewController and UIImagePickerController
//

import SwiftUI
import PhotosUI
import UIKit

class ImagePickerService: NSObject, ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var isPresented = false
    @Published var pickerType: PickerType = .photoLibrary
    
    enum PickerType {
        case photoLibrary
        case camera
    }
    
    private var completion: ((UIImage?) -> Void)?
    
    func presentPicker(type: PickerType, completion: @escaping (UIImage?) -> Void) {
        self.pickerType = type
        self.completion = completion
        self.isPresented = true
    }
    
    func dismissPicker() {
        isPresented = false
        completion?(selectedImage)
        selectedImage = nil
        completion = nil
    }
}

// MARK: - PHPickerViewController Delegate
extension ImagePickerService: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let result = results.first else {
            dismissPicker()
            return
        }
        
        // Load the selected image
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            DispatchQueue.main.async {
                if let image = object as? UIImage {
                    self?.selectedImage = image
                }
                self?.dismissPicker()
            }
        }
    }
}

// MARK: - UIImagePickerController Delegate
extension ImagePickerService: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        if let image = info[.originalImage] as? UIImage {
            selectedImage = image
        }
        
        dismissPicker()
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        dismissPicker()
    }
}

// MARK: - SwiftUI View Modifier
struct ImagePickerModifier: ViewModifier {
    @Binding var isPresented: Bool
    let pickerType: ImagePickerService.PickerType
    let onImageSelected: (UIImage?) -> Void
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                ImagePickerView(
                    pickerType: pickerType,
                    onImageSelected: onImageSelected
                )
            }
    }
}

// MARK: - Image Picker View
struct ImagePickerView: UIViewControllerRepresentable {
    let pickerType: ImagePickerService.PickerType
    let onImageSelected: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        switch pickerType {
        case .photoLibrary:
            var config = PHPickerConfiguration()
            config.filter = .images
            config.selectionLimit = 1
            
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = context.coordinator
            return picker
            
        case .camera:
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                // Fallback to photo library if camera is not available
                var config = PHPickerConfiguration()
                config.filter = .images
                config.selectionLimit = 1
                
                let picker = PHPickerViewController(configuration: config)
                picker.delegate = context.coordinator
                return picker
            }
            
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = context.coordinator
            return picker
        }
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        // PHPickerViewController Delegate
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let result = results.first else {
                parent.onImageSelected(nil)
                return
            }
            
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                DispatchQueue.main.async {
                    if let image = object as? UIImage {
                        self?.parent.onImageSelected(image)
                    } else {
                        self?.parent.onImageSelected(nil)
                    }
                }
            }
        }
        
        // UIImagePickerController Delegate
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true)
            
            if let image = info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            } else {
                parent.onImageSelected(nil)
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            parent.onImageSelected(nil)
        }
    }
}

// MARK: - View Extension
extension View {
    func imagePicker(
        isPresented: Binding<Bool>,
        pickerType: ImagePickerService.PickerType,
        onImageSelected: @escaping (UIImage?) -> Void
    ) -> some View {
        self.modifier(
            ImagePickerModifier(
                isPresented: isPresented,
                pickerType: pickerType,
                onImageSelected: onImageSelected
            )
        )
    }
}
