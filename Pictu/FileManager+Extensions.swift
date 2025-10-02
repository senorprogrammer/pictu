import Foundation
import AppKit

// MARK: - FileManager Extensions for Pictu
extension FileManager {
    
    /// Returns the Pictu application support directory URL
    static var pictuAppSupportURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("❌ Failed to get application support directory")
            return nil
        }
        return appSupport.appendingPathComponent("Pictu")
    }
    
    /// Returns the URL for a specific image file in the Pictu directory
    /// - Parameter fileName: The name of the image file
    /// - Returns: The full URL to the image file, or nil if invalid
    static func pictuImageURL(for fileName: String) -> URL? {
        guard !fileName.isEmpty, !fileName.contains("..") else {
            print("❌ Invalid file name: \(fileName)")
            return nil
        }
        guard let pictuURL = pictuAppSupportURL else { return nil }
        return pictuURL.appendingPathComponent(fileName)
    }
    
    /// Ensures the Pictu application support directory exists
    /// - Returns: The URL of the directory, or nil if creation failed
    static func ensurePictuDirectoryExists() -> URL? {
        guard let pictuURL = pictuAppSupportURL else {
            print("❌ Failed to get Pictu directory URL")
            return nil
        }
        
        do {
            try FileManager.default.createDirectory(at: pictuURL, withIntermediateDirectories: true, attributes: nil)
            return pictuURL
        } catch {
            ErrorManager.shared.logError(error, context: "creating Pictu directory")
            return nil
        }
    }
    
    /// Checks if an image file exists in the Pictu directory
    /// - Parameter fileName: The name of the image file
    /// - Returns: True if the file exists, false otherwise
    static func pictuImageExists(fileName: String) -> Bool {
        guard let imageURL = pictuImageURL(for: fileName) else { return false }
        return FileManager.default.fileExists(atPath: imageURL.path)
    }
    
    /// Safely deletes an image file from the Pictu directory
    /// - Parameter fileName: The name of the image file to delete
    /// - Returns: True if deletion was successful, false otherwise
    static func deletePictuImage(fileName: String) -> Bool {
        guard let imageURL = pictuImageURL(for: fileName) else { return false }
        
        do {
            try FileManager.default.removeItem(at: imageURL)
            return true
        } catch {
            ErrorManager.shared.logError(error, context: "deleting image \(fileName)")
            return false
        }
    }
    
    /// Safely saves an image to the Pictu directory
    /// - Parameters:
    ///   - image: The NSImage to save
    ///   - fileName: The name for the saved file
    /// - Returns: True if save was successful, false otherwise
    static func savePictuImage(_ image: NSImage, fileName: String) -> Bool {
        guard let imageURL = pictuImageURL(for: fileName) else { return false }
        guard let _ = ensurePictuDirectoryExists() else { return false }
        
        // Try to get PNG representation directly if possible
        if let pngData = image.pngData {
            do {
                try pngData.write(to: imageURL)
                return true
            } catch {
                ErrorManager.shared.logError(error, context: "saving image \(fileName)")
                return false
            }
        }
        
        // Fallback to TIFF conversion
        guard let imageData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: imageData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("❌ Failed to convert image to PNG data")
            return false
        }
        
        do {
            try pngData.write(to: imageURL)
            return true
        } catch {
            ErrorManager.shared.logError(error, context: "saving image \(fileName)")
            return false
        }
    }
}

// MARK: - NSImage Extensions
extension NSImage {
    /// Returns PNG data representation of the image
    var pngData: Data? {
        guard let imageData = self.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: imageData) else {
            return nil
        }
        return bitmapRep.representation(using: .png, properties: [:])
    }
}
