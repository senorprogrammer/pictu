import AppKit

// MARK: - Image Sizing Utility
struct ImageSizing {
    static let maxImageDimension: CGFloat = 320
    
    /// Calculates the display size for an image, maintaining aspect ratio while fitting within max dimension
    /// - Parameter image: The image to calculate size for
    /// - Returns: The calculated display size
    static func displaySize(for image: NSImage) -> NSSize {
        let imageSize = image.size
        let maxDimension = maxImageDimension
        
        // If image is smaller than max dimension, use original size
        if imageSize.width <= maxDimension && imageSize.height <= maxDimension {
            return imageSize
        }
        
        // Calculate scale factor to fit within max dimension while maintaining aspect ratio
        let scaleX = maxDimension / imageSize.width
        let scaleY = maxDimension / imageSize.height
        let scale = min(scaleX, scaleY)
        
        return NSSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
    }
    
    /// Scales an image down if it exceeds the maximum dimension while maintaining aspect ratio
    /// - Parameter image: The image to scale
    /// - Returns: The scaled image, or original if no scaling needed
    static func scaledImage(for image: NSImage) -> NSImage {
        let targetSize = displaySize(for: image)
        let originalSize = image.size
        
        // If no resizing needed, return original
        if targetSize.width >= originalSize.width && targetSize.height >= originalSize.height {
            return image
        }
        
        // Create a new image with the target size
        let scaledImage = NSImage(size: targetSize)
        
        scaledImage.lockFocus()
        defer { scaledImage.unlockFocus() }
        
        // Set high quality interpolation
        NSGraphicsContext.current?.imageInterpolation = .high
        
        // Draw the original image scaled to the target size
        image.draw(in: NSRect(origin: .zero, size: targetSize))
        
        return scaledImage
    }
}
