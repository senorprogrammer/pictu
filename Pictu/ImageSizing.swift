import AppKit

// MARK: - Image Sizing Utility
struct ImageSizing {
    
    /// Calculates the display size for an image, scaling down if longest side exceeds maxDimension
    /// - Parameters:
    ///   - imageSize: The pixel dimensions of the image
    ///   - maxDimension: The maximum dimension allowed (from preferences or default)
    /// - Returns: The calculated display size
    static func displaySize(for imageSize: NSSize, maxDimension: CGFloat) -> NSSize {
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
    
    /// Scales an image down if longest side exceeds maxDimension while maintaining aspect ratio
    /// Works with actual pixel dimensions from NSBitmapImageRep
    /// - Parameters:
    ///   - bitmapRep: The bitmap representation to scale
    ///   - maxDimension: The maximum dimension allowed
    /// - Returns: The scaled bitmap representation, or original if no scaling needed
    static func scaledBitmapRep(_ bitmapRep: NSBitmapImageRep, maxDimension: CGFloat) -> NSBitmapImageRep {
        let pixelSize = NSSize(width: bitmapRep.pixelsWide, height: bitmapRep.pixelsHigh)
        let targetSize = displaySize(for: pixelSize, maxDimension: maxDimension)
        
        // If no resizing needed, return original
        if targetSize.width >= pixelSize.width && targetSize.height >= pixelSize.height {
            return bitmapRep
        }
        
        // Create a new bitmap with smaller dimensions
        guard let scaledBitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(targetSize.width),
            pixelsHigh: Int(targetSize.height),
            bitsPerSample: bitmapRep.bitsPerSample,
            samplesPerPixel: bitmapRep.samplesPerPixel,
            hasAlpha: bitmapRep.hasAlpha,
            isPlanar: bitmapRep.isPlanar,
            colorSpaceName: bitmapRep.colorSpaceName,
            bytesPerRow: 0,
            bitsPerPixel: bitmapRep.bitsPerPixel
        ) else {
            return bitmapRep // Return original if scaling fails
        }
        
        // Draw the original bitmap scaled to the new size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: scaledBitmap)
        NSGraphicsContext.current?.imageInterpolation = .high
        
        bitmapRep.draw(in: NSRect(origin: .zero, size: targetSize))
        
        NSGraphicsContext.restoreGraphicsState()
        
        return scaledBitmap
    }
    
    /// Legacy method for NSImage scaling (kept for compatibility)
    /// - Parameters:
    ///   - image: The image to scale
    ///   - maxDimension: The maximum dimension allowed
    /// - Returns: The scaled image, or original if no scaling needed
    static func scaledImage(for image: NSImage, maxDimension: CGFloat) -> NSImage {
        // First try to get pixel dimensions from the image's representations
        if let bitmapRep = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first {
            let scaledBitmap = scaledBitmapRep(bitmapRep, maxDimension: maxDimension)
            let scaledImage = NSImage(size: scaledBitmap.size)
            scaledImage.addRepresentation(scaledBitmap)
            return scaledImage
        }
        
        // Fallback to the old method if no bitmap representation found
        let targetSize = displaySize(for: image.size, maxDimension: maxDimension)
        
        if targetSize.width >= image.size.width && targetSize.height >= image.size.height {
            return image
        }
        
        let scaledImage = NSImage(size: targetSize)
        scaledImage.lockFocus()
        defer { scaledImage.unlockFocus() }
        
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: targetSize))
        
        return scaledImage
    }
}
