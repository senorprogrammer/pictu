import CoreData
import Foundation
import AppKit
import Combine

class PersistenceManager: ObservableObject {
    static let shared = PersistenceManager()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Pictu")
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // Silently ignore and continue as requested
                ErrorManager.shared.logError(error, context: "Core Data initialization")
            }
        }
        // Resolve merge conflicts in favor of in-memory (object) values for this context
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        // Automatically pull in changes saved by other contexts to reduce conflicts
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    // Background context for thread-safe writes
    private lazy var backgroundContext: NSManagedObjectContext = {
        let ctx = persistentContainer.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        ctx.automaticallyMergesChangesFromParent = true
        return ctx
    }()
    
    
    private init() {}
    
    // MARK: - App Settings
    
    private func getOrCreateAppSettings() -> AppSettings {
        let request: NSFetchRequest<AppSettings> = AppSettings.fetchRequest()
        do {
            return try context.fetch(request).first ?? AppSettings(context: context)
        } catch {
            ErrorManager.shared.logError(error, context: "fetching app settings")
            return AppSettings(context: context)
        }
    }
    
    private func loadAppSettings() -> AppSettings? {
        let request: NSFetchRequest<AppSettings> = AppSettings.fetchRequest()
        do {
            return try context.fetch(request).first
        } catch {
            ErrorManager.shared.logError(error, context: "loading app settings")
            return nil
        }
    }
    
    /// Saves the app's pinned state and window frame to persistent storage
    /// - Parameters:
    ///   - isPinned: Whether the app window is pinned
    ///   - windowFrame: The current window frame rectangle
    func saveAppSettings(isPinned: Bool, windowFrame: NSRect) {
        let settings = getOrCreateAppSettings()
        settings.isPinned = isPinned
        settings.windowFrame = NSStringFromRect(windowFrame)
        saveContext()
    }
    
    /// Saves the popover size to persistent storage
    /// - Parameter size: The popover size to save
    func savePopoverSize(_ size: CGSize) {
        let settings = getOrCreateAppSettings()
        settings.popoverSize = NSStringFromSize(NSSize(width: size.width, height: size.height))
        saveContext()
    }
    
    /// Loads the app's pinned state and window frame from persistent storage
    /// - Returns: A tuple containing the pinned state and window frame (nil if not set)
    func loadAppSettings() -> (isPinned: Bool, windowFrame: NSRect?) {
        guard let settings = loadAppSettings() else {
            return (false, nil)
        }
        
        let frame = settings.windowFrame != nil ? NSRectFromString(settings.windowFrame!) : nil
        return (settings.isPinned, frame)
    }
    
    /// Loads the popover size from persistent storage
    /// - Returns: The saved popover size, or nil if not set
    func loadPopoverSize() -> CGSize? {
        guard let settings = loadAppSettings(),
              let sizeString = settings.popoverSize else {
            return nil
        }
        
        let size = NSSizeFromString(sizeString)
        return CGSize(width: size.width, height: size.height)
    }
    
    /// Saves the selected preferences tab to persistent storage
    /// - Parameter tabName: The name of the selected tab
    func saveSelectedPreferencesTab(_ tabName: String) {
        let settings = getOrCreateAppSettings()
        settings.selectedPreferencesTab = tabName
        saveContext()
    }
    
    /// Loads the selected preferences tab from persistent storage
    /// - Returns: The name of the selected tab, or nil if not set
    func loadSelectedPreferencesTab() -> String? {
        return loadAppSettings()?.selectedPreferencesTab
    }
    
    /// Saves the maximum window size to persistent storage
    /// - Parameter maxSize: The maximum window size in points
    func saveMaxWindowSize(_ maxSize: Int32) {
        let settings = getOrCreateAppSettings()
        settings.maxWindowSize = maxSize
        saveContext()
    }
    
    /// Loads the maximum window size from persistent storage
    /// - Returns: The saved maximum window size, defaults to 1024 if not set
    func loadMaxWindowSize() -> Int32 {
        guard let settings = loadAppSettings(),
              settings.maxWindowSize > 0 else {
            return 1024 // Default fallback
        }
        return settings.maxWindowSize
    }
    
    // MARK: - Images
    
    private func deactivateAllImages(in ctx: NSManagedObjectContext) {
        let request: NSFetchRequest<Image> = Image.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        do {
            let activeImages = try ctx.fetch(request)
            if !activeImages.isEmpty {
                activeImages.forEach { $0.isActive = false }
                if ctx.hasChanges {
                    do { try ctx.save() } catch { ErrorManager.shared.logError(error, context: "saving after deactivation") }
                }
            }
        } catch {
            ErrorManager.shared.logError(error, context: "deactivating all images")
        }
    }
    
    /// Scales an image down if it exceeds the maximum dimension while maintaining aspect ratio
    private func scaleImageIfNeeded(_ image: NSImage) -> NSImage {
        // Guard against invalid image dimensions
        guard image.size.width > 0 && image.size.height > 0 else {
            return image // Return original if invalid size
        }
        
        return ImageSizing.scaledImage(for: image)
    }
    
    /// Saves an image to persistent storage and makes it the active image
    /// - Parameter image: The image to save
    /// - Returns: The filename of the saved image, or nil if saving failed
    func saveImage(_ image: NSImage) -> String? {
        // Scale the image if it exceeds the maximum dimension
        let scaledImage = scaleImageIfNeeded(image)
        
        guard let imageData = scaledImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: imageData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        let fileName = "\(UUID().uuidString).png"
        // Ensure directory exists before writing
        guard let imagesDir = FileManager.ensurePictuDirectoryExists() else {
            return nil
        }
        let fileURL = imagesDir.appendingPathComponent(fileName)
        
        do {
            try pngData.write(to: fileURL)
        } catch {
            ErrorManager.shared.logError(error, context: "saving image data to disk")
            return nil
        }
        
        var resultFileName: String?
        backgroundContext.performAndWait {
            let imageEntity = Image(context: backgroundContext)
            imageEntity.id = UUID()
            imageEntity.fileName = fileName
            imageEntity.createdAt = Date()
            imageEntity.isActive = true
            
            // Deactivate others in background context and save
            self.deactivateAllImages(in: self.backgroundContext)
            imageEntity.isActive = true
            
            do {
                if self.backgroundContext.hasChanges {
                    try self.backgroundContext.save()
                }
                resultFileName = fileName
            } catch {
                ErrorManager.shared.logError(error, context: "saving context (saveImage)")
                resultFileName = nil
            }
        }
        return resultFileName
    }
    
    /// Loads the currently active image from persistent storage
    /// - Returns: The active image, or nil if no active image exists
    func loadActiveImage() -> NSImage? {
        let request: NSFetchRequest<Image> = Image.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        
        do {
            if let imageEntity = try context.fetch(request).first,
               let fileName = imageEntity.fileName,
               let fileURL = FileManager.pictuImageURL(for: fileName) {
                return NSImage(contentsOf: fileURL)
            }
        } catch {
            ErrorManager.shared.logError(error, context: "loading active image")
        }
        
        return nil
    }
    
    /// Clears the active image by deactivating all images
    func clearActiveImage() {
        backgroundContext.performAndWait {
            self.deactivateAllImages(in: self.backgroundContext)
        }
    }
    
    /// Retrieves all images from persistent storage
    /// - Returns: An array of tuples containing filename, active state, and creation date
    func getAllImages() -> [(fileName: String, isActive: Bool, createdAt: Date)] {
        let request: NSFetchRequest<Image> = Image.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            let images = try context.fetch(request)
            return images.compactMap { image in
                guard let fileName = image.fileName,
                      let createdAt = image.createdAt else { return nil }
                return (fileName: fileName, isActive: image.isActive, createdAt: createdAt)
            }
        } catch {
            ErrorManager.shared.logError(error, context: "loading all images")
            return []
        }
    }
    
    /// Sets the specified image as the active image
    /// - Parameter fileName: The filename of the image to activate
    func setActiveImage(fileName: String) {
        backgroundContext.performAndWait {
            // First, deactivate all images (batch update)
            self.deactivateAllImages(in: self.backgroundContext)
            
            // Then activate the selected image
            let activateRequest: NSFetchRequest<Image> = Image.fetchRequest()
            activateRequest.predicate = NSPredicate(format: "fileName == %@", fileName)
            
            do {
                if let targetImage = try self.backgroundContext.fetch(activateRequest).first {
                    targetImage.isActive = true
                    if self.backgroundContext.hasChanges {
                        do {
                            try self.backgroundContext.save()
                        } catch {
                            ErrorManager.shared.logError(error, context: "saving context after setActiveImage")
                        }
                    }
                }
            } catch {
                ErrorManager.shared.logError(error, context: "setting active image")
            }
        }
    }
    
    /// Deletes an image from both persistent storage and the file system
    /// - Parameter fileName: The filename of the image to delete
    func deleteImage(fileName: String) {
        // Delete from Core Data (background)
        backgroundContext.performAndWait {
            let request: NSFetchRequest<Image> = Image.fetchRequest()
            request.predicate = NSPredicate(format: "fileName == %@", fileName)
            
            do {
                if let imageEntity = try self.backgroundContext.fetch(request).first {
                    self.backgroundContext.delete(imageEntity)
                    if self.backgroundContext.hasChanges {
                        try self.backgroundContext.save()
                    }
                }
            } catch {
                ErrorManager.shared.logError(error, context: "deleting image entity")
            }
        }
        
        // Delete from file system
        if let fileURL = FileManager.pictuImageURL(for: fileName) {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                do { try FileManager.default.removeItem(at: fileURL) } catch { ErrorManager.shared.logError(error, context: "deleting file") }
            }
        }
    }
    
    /// Deletes an image and returns a replacement image to display
    /// - Parameter fileName: The filename of the image to delete
    /// - Returns: The new active image to display, or nil if no images remain
    func deleteImageAndGetReplacement(fileName: String) -> NSImage? {
        // Get all images before deletion
        let allImages = getAllImages()
        guard let deletedIndex = allImages.firstIndex(where: { $0.fileName == fileName }) else {
            return nil
        }
        
        // Check if we're deleting the currently active image
        let wasActive = allImages[deletedIndex].isActive
        
        // Delete the image
        deleteImage(fileName: fileName)
        
        // Get remaining images after deletion
        let remainingImages = getAllImages()
        
        if remainingImages.isEmpty {
            // No images left
            return nil
        }
        
        if wasActive {
            // We deleted the active image, need to select a replacement
            let replacementIndex: Int
            if deletedIndex < remainingImages.count {
                // Use the same index (now points to the next image)
                replacementIndex = deletedIndex
            } else {
                // Index is out of bounds, select the last image
                replacementIndex = remainingImages.count - 1
            }
            
            // Set the replacement as active
            let replacementFileName = remainingImages[replacementIndex].fileName
            setActiveImage(fileName: replacementFileName)
            
            // Return the new active image
            return loadActiveImage()
        } else {
            // We deleted a non-active image, return the current active image
            return loadActiveImage()
        }
    }
    
    // MARK: - Helper Methods
    
    
    
    private func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                ErrorManager.shared.logError(error, context: "saving context")
            }
        }
    }
}
