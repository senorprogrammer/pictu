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
                        ErrorManager.shared.presentError(message: "Failed to load image: \(error.localizedDescription)")
                        return
                    }
                    
                    if let url = item as? URL {
                        if let nsImage = NSImage(contentsOf: url) {
                            appState.saveImageFromData(nsImage)
                        } else {
                            ErrorManager.shared.presentError(message: "Unsupported image file format.")
                        }
                        return
                    }
                    
                    if let data = item as? Data {
                        if let nsImage = NSImage(data: data) {
                            appState.saveImageFromData(nsImage)
                        } else {
                            ErrorManager.shared.presentError(message: "Unsupported image data format.")
                        }
                        return
                    }
                    
                    ErrorManager.shared.presentError(message: "Unsupported item. Please drop a valid image file.")
                }
            }
            return true
        }
        
        // Fallback to the old method for compatibility
        if provider.canLoadObject(ofClass: NSImage.self) {
            provider.loadObject(ofClass: NSImage.self) { image, error in
                DispatchQueue.main.async {
                    if let error = error {
                        ErrorManager.shared.presentError(message: "Failed to load image: \(error.localizedDescription)")
                        return
                    }
                    
                    if let nsImage = image as? NSImage {
                        appState.saveImageFromData(nsImage)
                    } else {
                        ErrorManager.shared.presentError(message: "Unsupported item. Please drop a valid image.")
                    }
                }
            }
            return true
        }
        
        ErrorManager.shared.presentError(message: "Unsupported item. Please drop an image file.")
        return false
    }
}
