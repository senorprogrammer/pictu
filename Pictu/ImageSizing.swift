import AppKit

// MARK: - Image Sizing Utility
struct ImageSizing {
    /// Returns the natural size of the image without any scaling
    /// - Parameter image: The image to get size for
    /// - Returns: The natural image size
    static func displaySize(for image: NSImage) -> NSSize {
        return image.size
    }
    
    /// Returns the original image without any scaling
    /// - Parameter image: The image to return
    /// - Returns: The original image
    static func scaledImage(for image: NSImage) -> NSImage {
        return image
    }
}
