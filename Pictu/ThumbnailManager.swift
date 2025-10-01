import Foundation
import AppKit
import Combine

// MARK: - Thumbnail Manager
class ThumbnailManager: ObservableObject {
    @Published var images: [(fileName: String, isActive: Bool, createdAt: Date)] = []
    
    private var appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    // MARK: - Public Methods
    
    func updateAppState(_ newAppState: AppState) {
        self.appState = newAppState
    }
    
    func loadImages() {
        // Load images from Core Data (already sorted by creation date, newest first)
        images = appState.getAllImages()
    }
    
    // MARK: - Computed Properties
    
    /// Returns the current selected index by finding the active image
    var selectedIndex: Int? {
        return images.firstIndex(where: { $0.isActive })
    }
    
    func selectImage(_ index: Int) {
        guard index < images.count else { return }
        let fileName = images[index].fileName
        appState.setActiveImage(fileName: fileName)
    }
    
    func deleteImage(_ fileName: String) {
        // Delete the image - AppState now handles replacement selection
        appState.deleteImage(fileName: fileName)
        
        // Reload the images list to reflect the changes
        loadImages()
    }
    
    func navigateLeft() {
        guard !images.isEmpty else { return }
        
        let currentIndexOpt = selectedIndex
        var expectedIndex: Int
        if let currentIndex = currentIndexOpt {
            expectedIndex = currentIndex > 0 ? currentIndex - 1 : images.count - 1
        } else {
            expectedIndex = images.count - 1
        }

        // Perform selection
        selectImage(expectedIndex)
    }
    
    func navigateRight() {
        guard !images.isEmpty else { return }
        
        let currentIndexOpt = selectedIndex
        var expectedIndex: Int
        if let currentIndex = currentIndexOpt {
            expectedIndex = currentIndex < images.count - 1 ? currentIndex + 1 : 0
        } else {
            expectedIndex = 0
        }

        // Perform selection
        selectImage(expectedIndex)
    }
    
}
