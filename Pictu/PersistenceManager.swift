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
    
    /// Loads the app's pinned state and window frame from persistent storage
    /// - Returns: A tuple containing the pinned state and window frame (nil if not set)
    func loadAppSettings() -> (isPinned: Bool, windowFrame: NSRect?) {
        guard let settings = loadAppSettings() else {
            return (false, nil)
        }
        
        let frame = settings.windowFrame != nil ? NSRectFromString(settings.windowFrame!) : nil
        return (settings.isPinned, frame)
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
    /// - Returns: The saved maximum window size, defaults to 320 if not set
    func loadMaxWindowSize() -> Int32 {
        guard let settings = loadAppSettings(),
              settings.maxWindowSize > 0 else {
            return 320 // Default fallback
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
    
    /// Saves an image to persistent storage with pixel-based resizing and JPEG conversion
    /// - Parameter image: The image to save
    /// - Returns: The filename of the saved image, or nil if saving failed
    func saveImageFromData(_ image: NSImage) -> String? {
        let maxDimension = CGFloat(loadMaxWindowSize())
        let scaledImage = image.size.width > 0 && image.size.height > 0
            ? ImageSizing.scaledImage(for: image, maxDimension: maxDimension)
            : image
        
        // Get bitmap representation for conversion
        guard let imageData = scaledImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: imageData) else {
            ErrorManager.shared.logError(NSError(domain: "ImageProcessing", code: 1), context: "creating bitmap representation")
            return nil
        }
        
        // Convert to JPEG with good quality (0.85 = 85% quality)
        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [
            .compressionFactor: NSNumber(value: 0.85)
        ]) else {
            ErrorManager.shared.logError(NSError(domain: "ImageProcessing", code: 2), context: "creating JPEG representation")
            return nil
        }
        
        let fileName = "\(UUID().uuidString).jpg"
        // Ensure directory exists before writing
        guard let imagesDir = FileManager.ensurePictuDirectoryExists() else {
            return nil
        }
        let fileURL = imagesDir.appendingPathComponent(fileName)
        
        do {
            try jpegData.write(to: fileURL)
        } catch {
            ErrorManager.shared.logError(error, context: "saving JPEG data to disk")
            return nil
        }
        
        var resultFileName: String?
        backgroundContext.performAndWait {
            let imageEntity = Image(context: backgroundContext)
            imageEntity.id = UUID()
            imageEntity.fileName = fileName
            imageEntity.createdAt = Date()
            imageEntity.sortOrder = self.leadingSortOrder(in: self.backgroundContext)
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
                ErrorManager.shared.logError(error, context: "saving context (saveImageFromData)")
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
    
    /// Retrieves all images, ordered by `sortOrder` ascending, then `createdAt` descending.
    /// - Returns: An array of tuples containing filename, active state, and creation date
    func getAllImages() -> [(fileName: String, isActive: Bool)] {
        let request: NSFetchRequest<Image> = Image.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "sortOrder", ascending: true),
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]
        
        do {
            let images = try context.fetch(request)
            return images.compactMap { image in
                guard let fileName = image.fileName else { return nil }
                return (fileName: fileName, isActive: image.isActive)
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
    
    /// Deletes an image and returns the image that should be shown next.
    /// - Parameter fileName: The filename of the image to delete
    /// - Returns: The replacement image and its filename, or nil if none remain
    func deleteImageAndGetReplacement(fileName: String) -> (image: NSImage, fileName: String)? {
        let allImages = getAllImages()
        guard let deletedIndex = allImages.firstIndex(where: { $0.fileName == fileName }) else {
            return nil
        }
        
        let wasActive = allImages[deletedIndex].isActive
        let previousActiveFileName = allImages.first(where: { $0.isActive })?.fileName
        deleteImage(fileName: fileName)
        
        let remainingImages = getAllImages()
        guard !remainingImages.isEmpty else { return nil }
        
        let replacementFileName: String
        if wasActive {
            let replacementIndex = deletedIndex < remainingImages.count ? deletedIndex : remainingImages.count - 1
            replacementFileName = remainingImages[replacementIndex].fileName
            setActiveImage(fileName: replacementFileName)
        } else if let previousActiveFileName {
            replacementFileName = previousActiveFileName
        } else {
            return nil
        }
        
        guard let image = loadActiveImage() else { return nil }
        return (image, replacementFileName)
    }
    
    /// Places `moving` before or after `target` in `fileNames`.
    /// - Returns: The reordered names, or nil when either name is missing or they are the same.
    static func movedFileNames(
        _ fileNames: [String],
        moving source: String,
        relativeTo target: String,
        insertAfter: Bool
    ) -> [String]? {
        guard source != target,
              fileNames.contains(source),
              fileNames.contains(target) else { return nil }

        var result = fileNames
        result.removeAll { $0 == source }
        guard let targetIndex = result.firstIndex(of: target) else { return nil }
        let insertIndex = insertAfter ? targetIndex + 1 : targetIndex
        result.insert(source, at: insertIndex)
        return result
    }

    /// Persists display order. Index 0 is the leftmost thumbnail.
    func reorderImages(orderedFileNames: [String]) {
        context.performAndWait {
            let request: NSFetchRequest<Image> = Image.fetchRequest()
            do {
                let images = try self.context.fetch(request)
                var imagesByFileName: [String: Image] = [:]
                for image in images {
                    if let fileName = image.fileName {
                        imagesByFileName[fileName] = image
                    }
                }
                for (index, fileName) in orderedFileNames.enumerated() {
                    imagesByFileName[fileName]?.sortOrder = Int32(index)
                }
                if self.context.hasChanges {
                    try self.context.save()
                }
            } catch {
                ErrorManager.shared.logError(error, context: "reordering images")
            }
        }
    }

    // MARK: - Helper Methods

    /// Sort order for a newly added image so it appears at the start of the strip.
    private func leadingSortOrder(in context: NSManagedObjectContext) -> Int32 {
        let request: NSFetchRequest<Image> = Image.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
        request.fetchLimit = 1
        do {
            guard let minimum = try context.fetch(request).first else { return 0 }
            if minimum.sortOrder == Int32.min { return Int32.min }
            return minimum.sortOrder - 1
        } catch {
            ErrorManager.shared.logError(error, context: "fetching leading sort order")
            return 0
        }
    }

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
