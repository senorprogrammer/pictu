import SwiftUI
import UniformTypeIdentifiers


// MARK: - Image Drop Handler
struct ImageDropHandler {
    static func handleDrop(providers: [NSItemProvider], appState: AppState) -> Bool {
        guard let provider = providers.first else { return false }
        
        if provider.canLoadObject(ofClass: NSImage.self) {
            provider.loadObject(ofClass: NSImage.self) { image, error in
                DispatchQueue.main.async {
                    if let error = error {
                        appState.presentError("Failed to load image: \(error.localizedDescription)")
                        return
                    }
                    
                    if let nsImage = image as? NSImage {
                        appState.saveImage(nsImage)
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
