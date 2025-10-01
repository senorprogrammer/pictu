import SwiftUI
import UniformTypeIdentifiers

// MARK: - Constants
enum ImageDropConstants {
    // Thumbnail sizing
    static let thumbnailSize: CGFloat = 60
    static let thumbnailCornerRadius: CGFloat = 8
    static let selectionBorderWidth: CGFloat = 3
    
    // Drop target styling
    static let dropTargetIconSize: CGFloat = 40
    static let dropTargetCornerRadius: CGFloat = 12
    static let dropTargetPadding: CGFloat = 8
    
    // Animation timing
    static let focusDelay: TimeInterval = 0.1
    static let deletionDelay: TimeInterval = 0.1
    static let popoverCloseDelay: TimeInterval = 0.05
    static let popoverReopenDelay: TimeInterval = 0.1
    
    // Layout spacing
    static let thumbnailStripHeight: CGFloat = 72
    static let thumbnailSpacing: CGFloat = 8
    static let thumbnailPadding: CGFloat = 6
}

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
