import Foundation
import AppKit
import Combine

// MARK: - Thumbnail Manager
class ThumbnailManager: ObservableObject {
    @Published private var refreshTrigger = UUID()
    private var appState: AppState
    private var cancellables = Set<AnyCancellable>()
    
    init(appState: AppState) {
        self.appState = appState
        setupReactiveUpdates()
    }
    
    // MARK: - Public Methods
    
    func updateAppState(_ newAppState: AppState) {
        self.appState = newAppState
        setupReactiveUpdates()
    }
    
    // MARK: - Computed Properties
    
    /// Returns all images directly from Core Data (single source of truth)
    var images: [(fileName: String, isActive: Bool, createdAt: Date)] {
        _ = refreshTrigger // Access to trigger SwiftUI updates
        return appState.getAllImages()
    }
    
    /// Returns the current selected index by finding the active image in Core Data
    var selectedIndex: Int? {
        _ = refreshTrigger // Access to trigger SwiftUI updates
        let allImages = appState.getAllImages()
        return allImages.firstIndex(where: { $0.isActive })
    }
    
    // MARK: - Private Methods
    
    private func setupReactiveUpdates() {
        // Listen for changes to the dropped image (indicates active image changed)
        appState.$droppedImage
            .sink { [weak self] _ in
                // Trigger UI update when active image changes
                self?.refreshTrigger = UUID()
            }
            .store(in: &cancellables)
    }
    
    func selectImage(_ index: Int) {
        guard index < images.count else { 
            print("🔍 [ThumbnailNavigation] selectImage: Index \(index) out of bounds (count: \(images.count))")
            return 
        }
        let fileName = images[index].fileName
        print("🔍 [ThumbnailNavigation] selectImage: Setting active image to index \(index) (\(fileName))")
        appState.setActiveImage(fileName: fileName)
        
        // Log the actual selected index after the state change
        DispatchQueue.main.async {
            let actualIndex = self.selectedIndex
            print("🔍 [ThumbnailNavigation] Actual next thumbnail index: \(actualIndex?.description ?? "nil")")
        }
    }
    
    func deleteImage(_ fileName: String) {
        // Delete the image - AppState now handles replacement selection
        appState.deleteImage(fileName: fileName)
    }
    
    func navigateLeft() {
        print("🔍 [ThumbnailNavigation] navigateLeft() called")
        
        guard !images.isEmpty else { 
            print("🔍 [ThumbnailNavigation] LEFT ARROW: No images available")
            return 
        }
        
        let currentIndexOpt = selectedIndex
        var expectedIndex: Int
        if let currentIndex = currentIndexOpt {
            expectedIndex = currentIndex > 0 ? currentIndex - 1 : images.count - 1
        } else {
            expectedIndex = images.count - 1
        }

        print("🔍 [ThumbnailNavigation] LEFT ARROW:")
        print("  • Key press: LEFT ARROW")
        print("  • Current thumbnail index: \(currentIndexOpt?.description ?? "nil")")
        print("  • Expected next thumbnail index: \(expectedIndex)")
        print("  • Total number of thumbnails: \(images.count)")

        // Perform selection
        print("🔍 [ThumbnailNavigation] Calling selectImage(\(expectedIndex))")
        selectImage(expectedIndex)
        print("🔍 [ThumbnailNavigation] selectImage(\(expectedIndex)) completed")
    }
    
    func navigateRight() {
        print("🔍 [ThumbnailNavigation] navigateRight() called")
        
        guard !images.isEmpty else { 
            print("🔍 [ThumbnailNavigation] RIGHT ARROW: No images available")
            return 
        }
        
        let currentIndexOpt = selectedIndex
        var expectedIndex: Int
        if let currentIndex = currentIndexOpt {
            expectedIndex = currentIndex < images.count - 1 ? currentIndex + 1 : 0
        } else {
            expectedIndex = 0
        }

        print("🔍 [ThumbnailNavigation] RIGHT ARROW:")
        print("  • Key press: RIGHT ARROW")
        print("  • Current thumbnail index: \(currentIndexOpt?.description ?? "nil")")
        print("  • Expected next thumbnail index: \(expectedIndex)")
        print("  • Total number of thumbnails: \(images.count)")

        // Perform selection
        print("🔍 [ThumbnailNavigation] Calling selectImage(\(expectedIndex))")
        selectImage(expectedIndex)
        print("🔍 [ThumbnailNavigation] selectImage(\(expectedIndex)) completed")
    }
    
}
