//
//  ImageCompressionService.swift
//  MessageAI
//
//  Image compression utility for reducing file sizes before upload
//

import UIKit
import ImageIO

class ImageCompressionService {
    static let shared = ImageCompressionService()
    
    private init() {}
    
    /// Compress image to reduce file size while maintaining quality
    /// - Parameters:
    ///   - image: Original image to compress
    ///   - maxSize: Maximum width or height (default: 1920)
    ///   - quality: JPEG compression quality (0.0 to 1.0, default: 0.7)
    /// - Returns: Compressed image data and dimensions
    func compressImage(_ image: UIImage, maxSize: CGFloat = 1920, quality: CGFloat = 0.7) -> (data: Data?, width: Double, height: Double) {
        // Get original dimensions
        let originalWidth = image.size.width
        let originalHeight = image.size.height
        
        // Calculate new dimensions maintaining aspect ratio
        let (newWidth, newHeight) = calculateNewDimensions(
            originalWidth: originalWidth,
            originalHeight: originalHeight,
            maxSize: maxSize
        )
        
        // Resize image if needed
        let resizedImage: UIImage
        if newWidth != originalWidth || newHeight != originalHeight {
            resizedImage = resizeImage(image, to: CGSize(width: newWidth, height: newHeight))
        } else {
            resizedImage = image
        }
        
        // Compress to JPEG data
        guard let imageData = resizedImage.jpegData(compressionQuality: quality) else {
            print("❌ Failed to compress image to JPEG")
            return (nil, Double(newWidth), Double(newHeight))
        }
        
        print("📸 Image compressed: \(originalWidth)x\(originalHeight) → \(newWidth)x\(newHeight), \(imageData.count) bytes")
        
        return (imageData, Double(newWidth), Double(newHeight))
    }
    
    /// Generate thumbnail for chat list preview
    /// - Parameters:
    ///   - image: Original image
    ///   - maxSize: Maximum size for thumbnail (default: 200)
    /// - Returns: Thumbnail image data
    func generateThumbnail(_ image: UIImage, maxSize: CGFloat = 200) -> Data? {
        let (thumbnailData, _, _) = compressImage(image, maxSize: maxSize, quality: 0.6)
        return thumbnailData
    }
    
    // MARK: - Private Methods
    
    private func calculateNewDimensions(originalWidth: CGFloat, originalHeight: CGFloat, maxSize: CGFloat) -> (width: CGFloat, height: CGFloat) {
        // If image is already smaller than max size, return original dimensions
        if originalWidth <= maxSize && originalHeight <= maxSize {
            return (originalWidth, originalHeight)
        }
        
        // Calculate scale factor to fit within max size while maintaining aspect ratio
        let widthScale = maxSize / originalWidth
        let heightScale = maxSize / originalHeight
        let scale = min(widthScale, heightScale)
        
        let newWidth = originalWidth * scale
        let newHeight = originalHeight * scale
        
        return (newWidth, newHeight)
    }
    
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Image Processing Extensions
extension UIImage {
    /// Get image orientation corrected version
    var orientationCorrected: UIImage {
        if imageOrientation == .up {
            return self
        }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let correctedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return correctedImage ?? self
    }
    
    /// Get image file size estimate
    var estimatedFileSize: Int {
        guard let data = jpegData(compressionQuality: 0.8) else { return 0 }
        return data.count
    }
}
