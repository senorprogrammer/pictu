import SwiftUI
import UniformTypeIdentifiers

// MARK: - Image Drop Handler
struct ImageDropHandler {
    static func handleDrop(providers: [NSItemProvider], appState: AppState) -> Bool {
        guard let provider = providers.first else { return false }
        
        // Try to load as data first to get actual pixel dimensions
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, error in
                DispatchQueue.main.async {
                    if let error = error {
                        appState.presentError("Failed to load image: \(error.localizedDescription)")
                        return
                    }
                    
                    // Handle URL-based image files
                    if let url = item as? URL {
                        if let nsImage = NSImage(contentsOf: url) {
                            appState.saveImageFromData(nsImage, originalFileURL: url)
                        } else {
                            appState.presentError("Unsupported image file format.")
                        }
                        return
                    }
                    
                    // Handle data-based images (paste, drag from other apps)
                    if let data = item as? Data {
                        if let nsImage = NSImage(data: data) {
                            appState.saveImageFromData(nsImage)
                        } else {
                            appState.presentError("Unsupported image data format.")
                        }
                        return
                    }
                    
                    // Fallback to NSImage object loading
                    appState.presentError("Unsupported item. Please drop a valid image file.")
                }
            }
            return true
        }
        
        // Fallback to the old method for compatibility
        if provider.canLoadObject(ofClass: NSImage.self) {
            provider.loadObject(ofClass: NSImage.self) { image, error in
                DispatchQueue.main.async {
                    if let error = error {
                        appState.presentError("Failed to load image: \(error.localizedDescription)")
                        return
                    }
                    
                    if let nsImage = image as? NSImage {
                        appState.saveImageFromData(nsImage)
                    } else {
                        appState.presentError("Unsupported item. Please drop a valid image.")
                    }
                }
            }
            return true
        }
        
        appState.presentError("Unsupported item. Please drop an image file.")
        return false
    }
}
