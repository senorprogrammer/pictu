import SwiftUI
import Combine
import AppKit

final class AppState: ObservableObject {
    @Published var isPinned: Bool = false
    @Published var droppedImage: NSImage?
    @Published var popoverSize: CGSize = CGSize(width: 260, height: 200)
    @Published var errorMessage: String?
    @Published var showError: Bool = false
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
        errorMessage = message
        showError = true
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
        // Find the index of the image being deleted before deletion
        let allImages = getAllImages()
        guard let deletedIndex = allImages.firstIndex(where: { $0.fileName == fileName }) else {
            return
        }
        
        // Check if we're deleting the active image
        let wasActiveImage = allImages[deletedIndex].isActive
        
        // Delete the image
        persistenceManager.deleteImage(fileName: fileName)
        
        // If we deleted the active image, select a replacement
        if wasActiveImage {
            let remainingImages = getAllImages()
            if !remainingImages.isEmpty {
                let newSelectedIndex: Int
                if deletedIndex < remainingImages.count {
                    // Image to the right (same index position)
                    newSelectedIndex = deletedIndex
                } else if deletedIndex > 0 {
                    // Image to the left (previous index)
                    newSelectedIndex = deletedIndex - 1
                } else {
                    // No images left, select first one
                    newSelectedIndex = 0
                }
                
                // Ensure the new index is valid and set as active
                if newSelectedIndex < remainingImages.count {
                    let newFileName = remainingImages[newSelectedIndex].fileName
                    setActiveImage(fileName: newFileName)
                }
            } else {
                // No images left, clear the active image
                droppedImage = nil
            }
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
    
    func navigateLeft() {
        print("🔍 [AppState] navigateLeft() called, current index: \(currentImageIndex)")
        navigateToPreviousImage()
        print("🔍 [AppState] navigateLeft() completed, new index: \(currentImageIndex)")
    }
    
    func navigateRight() {
        print("🔍 [AppState] navigateRight() called, current index: \(currentImageIndex)")
        navigateToNextImage()
        print("🔍 [AppState] navigateRight() completed, new index: \(currentImageIndex)")
    }
    
    private func setActiveImageWithPopoverHandling(fileName: String) {
        // Close popover first if it's open
        NSApp.sendAction(#selector(AppDelegate.closePopover), to: nil, from: nil)
        
        // Small delay to ensure popover is closed before updating image
        DispatchQueue.main.asyncAfter(deadline: .now() + ImageDropConstants.popoverCloseDelay) {
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
        
        // Load active image
        if let image = persistenceManager.loadActiveImage() {
            droppedImage = image
        } else {
            // Fallback: if no active image but images exist, select the most recent one
            let allImages = getAllImages()
            if let mostRecentImage = allImages.first {
                setActiveImage(fileName: mostRecentImage.fileName)
            }
        }
    }
}
