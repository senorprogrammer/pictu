import Foundation

// MARK: - FileManager Extensions for Pictu
extension FileManager {
    
    /// Returns the Pictu application support directory URL
    static var pictuAppSupportURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            ErrorManager.shared.logError(NSError(domain: "FileManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get application support directory"]), context: "getting application support directory")
            return nil
        }
        return appSupport.appendingPathComponent("Pictu")
    }
    
    /// Returns the URL for a specific image file in the Pictu directory
    /// - Parameter fileName: The name of the image file
    /// - Returns: The full URL to the image file, or nil if invalid
    static func pictuImageURL(for fileName: String) -> URL? {
        guard !fileName.isEmpty, !fileName.contains("..") else {
            ErrorManager.shared.logError(NSError(domain: "FileManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid file name: \(fileName)"]), context: "validating file name")
            return nil
        }
        guard let pictuURL = pictuAppSupportURL else { return nil }
        return pictuURL.appendingPathComponent(fileName)
    }
    
    /// Ensures the Pictu application support directory exists
    /// - Returns: The URL of the directory, or nil if creation failed
    static func ensurePictuDirectoryExists() -> URL? {
        guard let pictuURL = pictuAppSupportURL else {
            ErrorManager.shared.logError(NSError(domain: "FileManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to get Pictu directory URL"]), context: "getting Pictu directory URL")
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
}
