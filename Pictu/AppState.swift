import SwiftUI
import Combine
import AppKit

final class AppState: ObservableObject {
    @Published var isPinned: Bool = false
    @Published var droppedImage: NSImage?
    /// Filename of the image currently shown. Thumbnail selection is derived from this.
    @Published private(set) var activeFileName: String?
    @Published var maxWindowSize: Int32 = 1024
    /// Bumps when the image list changes without changing the active image.
    @Published private(set) var imagesRevision = UUID()
    
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
    
    func saveMaxWindowSize(_ maxSize: Int32) {
        maxWindowSize = maxSize
        persistenceManager.saveMaxWindowSize(maxSize)
    }
    
    func saveImageFromData(_ image: NSImage) {
        guard let fileName = persistenceManager.saveImageFromData(image) else { return }
        activeFileName = fileName
        droppedImage = image
        imagesRevision = UUID()
    }
    
    func clearImage() {
        persistenceManager.clearActiveImage()
        droppedImage = nil
        activeFileName = nil
    }
    
    func getAllImages() -> [(fileName: String, isActive: Bool)] {
        return persistenceManager.getAllImages()
    }
    
    func setActiveImage(fileName: String) {
        activeFileName = fileName
        persistenceManager.setActiveImage(fileName: fileName)
        if let image = persistenceManager.loadActiveImage() {
            droppedImage = image
        }
    }
    
    /// Moves `sourceFileName` before or after `targetFileName` and keeps selection on the active image.
    func reorderImage(moving sourceFileName: String, relativeTo targetFileName: String, insertAfter: Bool) {
        let fileNames = getAllImages().map(\.fileName)
        guard let ordered = PersistenceManager.movedFileNames(
            fileNames,
            moving: sourceFileName,
            relativeTo: targetFileName,
            insertAfter: insertAfter
        ), ordered != fileNames else { return }

        persistenceManager.reorderImages(orderedFileNames: ordered)
        imagesRevision = UUID()
    }

    func deleteImage(fileName: String) {
        if let replacement = persistenceManager.deleteImageAndGetReplacement(fileName: fileName) {
            droppedImage = replacement.image
            activeFileName = replacement.fileName
        } else {
            droppedImage = nil
            activeFileName = nil
        }
        imagesRevision = UUID()
    }
    
    // MARK: - Navigation Methods
    
    func navigateToPreviousImage() {
        navigate(offset: -1)
    }
    
    func navigateToNextImage() {
        navigate(offset: 1)
    }
    
    private func navigate(offset: Int) {
        let allImages = getAllImages()
        guard !allImages.isEmpty else { return }
        let current = allImages.firstIndex(where: { $0.fileName == activeFileName }) ?? 0
        let next = (current + offset + allImages.count) % allImages.count
        setActiveImageWithPopoverHandling(fileName: allImages[next].fileName)
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
        
        maxWindowSize = persistenceManager.loadMaxWindowSize()
        
        let allImages = getAllImages()
        if let active = allImages.first(where: { $0.isActive }) {
            activeFileName = active.fileName
            droppedImage = persistenceManager.loadActiveImage()
        } else if let mostRecentImage = allImages.first {
            setActiveImage(fileName: mostRecentImage.fileName)
        }
    }
}
