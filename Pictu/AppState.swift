import SwiftUI
import Combine
import AppKit

final class AppState: ObservableObject {
    @Published var isPinned: Bool = false
    @Published var droppedImage: NSImage?
    @Published var popoverSize: CGSize = CGSize(width: 260, height: 200)
    @Published var currentImageIndex: Int = 0  // Single source of truth for current image
    
    private let persistenceManager = PersistenceManager.shared
    
    init() {
        loadPersistedData()
    }
    
    // MARK: - Persistence Methods
    
    func savePinnedState(_ pinned: Bool) {
        isPinned = pinned
        // Window frame will be saved separately by AppDelegate
        persistenceManager.saveAppSettings(isPinned: pinned, windowFrame: .zero)
    }
    
    func savePopoverSize(_ size: CGSize) {
        // Constrain size to screen bounds
        let constrainedSize = constrainToScreen(size)
        popoverSize = constrainedSize
        persistenceManager.savePopoverSize(constrainedSize)
    }
    
    private func constrainToScreen(_ size: CGSize) -> CGSize {
        guard let screen = NSScreen.main else { return size }
        let screenSize = screen.visibleFrame.size
        
        var constrainedWidth = size.width
        var constrainedHeight = size.height
        
        // If width exceeds screen, reduce by screen width - 10
        if size.width > screenSize.width {
            constrainedWidth = screenSize.width - 10
        }
        
        // If height exceeds screen, reduce by screen height - 10
        if size.height > screenSize.height {
            constrainedHeight = screenSize.height - 10
        }
        
        return CGSize(width: constrainedWidth, height: constrainedHeight)
    }
    
    func saveImage(_ image: NSImage) {
        if persistenceManager.saveImage(image) != nil {
            droppedImage = image
        }
    }
    
    func clearImage() {
        persistenceManager.clearActiveImage()
        droppedImage = nil
    }

    // MARK: - Error Handling
    func presentError(_ message: String) {
        ErrorManager.shared.presentError(message: message)
    }
    
    func getAllImages() -> [(fileName: String, isActive: Bool, createdAt: Date)] {
        return persistenceManager.getAllImages()
    }
    
    func setActiveImage(fileName: String) {
        persistenceManager.setActiveImage(fileName: fileName)
        // Reload the active image
        if let image = persistenceManager.loadActiveImage() {
            droppedImage = image
        }
    }
    
    func deleteImage(fileName: String) {
        // Let PersistenceManager handle the deletion and return the new active image
        if let newActiveImage = persistenceManager.deleteImageAndGetReplacement(fileName: fileName) {
            // Update the current image
            droppedImage = newActiveImage
            // Update the index to match the new active image
            updateCurrentImageIndex()
        } else {
            // No images left
            droppedImage = nil
            currentImageIndex = 0
        }
    }
    
    /// Updates the currentImageIndex to match the active image
    private func updateCurrentImageIndex() {
        let allImages = getAllImages()
        if let activeIndex = allImages.firstIndex(where: { $0.isActive }) {
            currentImageIndex = activeIndex
        }
    }
    
    // MARK: - Navigation Methods
    
    func navigateToPreviousImage() {
        let allImages = getAllImages()
        guard !allImages.isEmpty else { return }
        
        // Decrement index with wrapping
        currentImageIndex = currentImageIndex > 0 ? currentImageIndex - 1 : allImages.count - 1
        
        // Load the image at the new index
        let fileName = allImages[currentImageIndex].fileName
        setActiveImageWithPopoverHandling(fileName: fileName)
    }
    
    func navigateToNextImage() {
        let allImages = getAllImages()
        guard !allImages.isEmpty else { return }
        
        // Increment index with wrapping
        currentImageIndex = currentImageIndex < allImages.count - 1 ? currentImageIndex + 1 : 0
        
        // Load the image at the new index
        let fileName = allImages[currentImageIndex].fileName
        setActiveImageWithPopoverHandling(fileName: fileName)
    }
    
    
    private func setActiveImageWithPopoverHandling(fileName: String) {
        // Close popover first if it's open
        NSApp.sendAction(#selector(AppDelegate.closePopover), to: nil, from: nil)
        
        // Small delay to ensure popover is closed before updating image
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Animation.popoverCloseDelay) {
            self.setActiveImage(fileName: fileName)
        }
    }
    
    private func loadPersistedData() {
        // Load pinned state
        let settings = persistenceManager.loadAppSettings()
        isPinned = settings.isPinned
        
        // Load popover size and constrain to screen
        if let savedSize = persistenceManager.loadPopoverSize() {
            popoverSize = constrainToScreen(savedSize)
        }
        
        // Load active image and set the current index
        let allImages = getAllImages()
        if let activeIndex = allImages.firstIndex(where: { $0.isActive }) {
            currentImageIndex = activeIndex
            if let image = persistenceManager.loadActiveImage() {
                droppedImage = image
            }
        } else {
            // Fallback: if no active image but images exist, select the most recent one
            if let mostRecentImage = allImages.first {
                currentImageIndex = 0
                setActiveImage(fileName: mostRecentImage.fileName)
            }
        }
    }
}
